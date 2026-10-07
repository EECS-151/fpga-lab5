SHELL                   := $(shell which bash) -o pipefail
ABS_TOP                 := $(subst /cygdrive/c/,C:/, $(shell pwd))
SCRIPTS                 := $(ABS_TOP)/scripts
FPGA_LEASE              := bash $(SCRIPTS)/fpga_lease.sh
VIVADO                  ?= vivado # this should be sourced by default 
VIVADO_OPTS             ?= -nolog -nojournal -mode batch
FPGA_PART               ?= xczu3eg-sfvc784-2-e
RTL                     += $(subst /cygdrive/c/,C:/, $(shell find $(ABS_TOP)/src -type f \( -name "*.v" -o -name "*.sv" \)))
CONSTRAINTS             += $(subst /cygdrive/c/,C:/, $(shell find $(ABS_TOP)/src -type f -name "*.xdc"))
TOP                     ?= zu3top
VCS                     := $(VCS_HOME)/bin/vcs -full64
VCS_OPTS     			:= -notice -line +lint=all,noVCDE,noNS,noSVA-UA -sverilog -kdb -timescale=1ns/10ps -debug_access+all -ignore initializer_driver_checks
SIM_RTL                 := $(subst /cygdrive/c/,C:/, $(shell find $(ABS_TOP)/sim -type f \( -name "*.v" -o -name "*.sv" \)))
VVP                     := vvp
VERDI                   ?= $(VERDI_HOME)/bin/verdi

sim/%.tb: sim/%.sv $(RTL)
	cd sim && $(VCS) $(VCS_OPTS) -o $*.tb \
	    -y $(ABS_TOP)/src +libext+.sv+.v \
	    $*.sv -top $*

sim/%.fsdb: sim/%.tb
	cd sim && ./$*.tb +verbose=1 +fsdbfile+$*.fsdb
	

# Open Verdi with FSDB and VCS dbdir. Usage: make verdi [TB=led_controller_tb]
verdi: sim/$(TB).fsdb
	$(VERDI) -dbdir sim/$(TB).tb.daidir -ssf sim/$(TB).fsdb &

# UVM testbench for the memory controller (sim/uvm). Usage:
#   make sim-uvm [UVM_TEST=mem_smoke_test]   build if needed, run one test
#                [UVM_ARGS=+UVM_VERBOSITY=UVM_HIGH]   extra simulator arguments
#   make uvm-report                          merge the coverage of every test run so far
#   make uvm-clean                           delete the coverage of every test run so far
#   make uvm-verdi [UVM_TEST=...]            open that test's waveform
UVM_TEST                ?= mem_smoke_test
UVM_DIR                 := $(strip $(ABS_TOP))/sim/uvm
UVM_BUILD               := build/uvm
UVM_SRCS                := $(wildcard $(UVM_DIR)/*.sv $(UVM_DIR)/*.svh)
URG                     ?= $(VCS_HOME)/bin/urg
# Plain "-ntb_opts uvm" selects UVM 1.1; name the IEEE 1800.2-2020 library explicitly.
UVM_VCS_OPTS            := -notice -sverilog -kdb -timescale=1ns/10ps -debug_access+all \
                           -ntb_opts uvm-ieee-2020-3.1 +incdir+$(UVM_DIR)

# mem_if.sv must come before mem_uvm_pkg.sv, which must come before mem_tb_top.sv.
$(UVM_BUILD)/simv: $(RTL) $(UVM_SRCS)
	mkdir -p $(UVM_BUILD)
	cd $(UVM_BUILD) && $(VCS) $(UVM_VCS_OPTS) -o simv -cm_dir mem_uvm.vdb \
	    -y $(ABS_TOP)/src +libext+.sv+.v \
	    $(UVM_DIR)/mem_if.sv $(UVM_DIR)/mem_uvm_pkg.sv $(UVM_DIR)/mem_tb_top.sv \
	    -top mem_tb_top |& tee compile.log

# Fails (non-zero exit) unless the log ends with "[ passed ]".
sim-uvm: $(UVM_BUILD)/simv
	cd $(UVM_BUILD) && ./simv +UVM_TESTNAME=$(UVM_TEST) -cm_name $(UVM_TEST) \
	    +fsdbfile+$(UVM_TEST).fsdb $(UVM_ARGS) |& tee $(UVM_TEST).log
	@grep -q '^\[ passed \]' $(UVM_BUILD)/$(UVM_TEST).log

uvm-report:
	cd $(UVM_BUILD) && $(URG) -full64 -dir mem_uvm.vdb -format both -report urgReport > urg.log 2>&1
	@echo "Tests merged:"; sed -n 's|^mem_uvm/|  |p' $(UVM_BUILD)/urgReport/tests.txt
	@echo "mem_txn_cg merged score: $$(grep -A1 '^SCORE' $(UVM_BUILD)/urgReport/groups.txt | awk 'NR==2 {print $$1}')%"
	@echo "Full report: $(UVM_BUILD)/urgReport/dashboard.html"

uvm-clean:
	rm -rf $(UVM_BUILD)/mem_uvm.vdb/snps/coverage/db/testdata $(UVM_BUILD)/urgReport

uvm-verdi:
	$(VERDI) -dbdir $(UVM_BUILD)/simv.daidir -ssf $(UVM_BUILD)/$(UVM_TEST).fsdb &

build/target.tcl: $(RTL) $(CONSTRAINTS)
	mkdir -p build
	truncate -s 0 $@
	echo "set ABS_TOP                        $(ABS_TOP)"    >> $@
	echo "set TOP                            $(TOP)"    >> $@
	echo "set FPGA_PART                      $(FPGA_PART)"  >> $@
	echo "set_param general.maxThreads       4"    >> $@
	echo "set_param general.maxBackupLogs    0"    >> $@
	echo -n "set RTL { " >> $@
	FLIST="$(RTL)"; for f in $$FLIST; do echo -n "$$f " ; done >> $@
	echo "}" >> $@
	echo -n "set CONSTRAINTS { " >> $@
	FLIST="$(CONSTRAINTS)"; for f in $$FLIST; do echo -n "$$f " ; done >> $@
	echo "}" >> $@

setup: build/target.tcl

elaborate: build/target.tcl $(SCRIPTS)/elaborate.tcl
	mkdir -p ./build
	cd ./build && $(VIVADO) $(VIVADO_OPTS) -source $(SCRIPTS)/elaborate.tcl |& tee elaborate.log

build/synth/$(TOP).dcp: build/target.tcl $(SCRIPTS)/synth.tcl
	mkdir -p ./build/synth/
	cd ./build/synth/ && $(VIVADO) $(VIVADO_OPTS) -source $(SCRIPTS)/synth.tcl |& tee synth.log

synth: build/synth/$(TOP).dcp

build/impl/$(TOP).bit: build/synth/$(TOP).dcp $(SCRIPTS)/impl.tcl
	mkdir -p ./build/impl/
	cd ./build/impl && $(VIVADO) $(VIVADO_OPTS) -source $(SCRIPTS)/impl.tcl |& tee impl.log

impl: build/impl/$(TOP).bit
all: build/impl/$(TOP).bit

program: build/impl/$(TOP).bit $(SCRIPTS)/program.tcl
	@rm -f $(SCRIPTS)/port.tmp $(SCRIPTS)/serial.tmp $(SCRIPTS)/assign_board_log.tmp $(SCRIPTS)/assign_board_test_log.tmp; \
	PORT=$$($(FPGA_LEASE) start) || exit 1; \
	cd build/impl && $(VIVADO) $(VIVADO_OPTS) -source $(SCRIPTS)/program.tcl -tclargs $$PORT \
		|| { echo "Programming failed (see the messages above).  Your board lease:"; $(FPGA_LEASE) status; echo "If the board was unplugged or replaced, run 'make program' again: it tells you what happened.  ('make release' only gives your board up and closes your UART program.)"; exit 1; }

program-force: $(SCRIPTS)/program.tcl
	@[ -f build/impl/$(TOP).bit ] || { echo "There is no bitstream yet: run 'make impl' first."; exit 1; }; \
	rm -f $(SCRIPTS)/port.tmp $(SCRIPTS)/serial.tmp $(SCRIPTS)/assign_board_log.tmp $(SCRIPTS)/assign_board_test_log.tmp; \
	PORT=$$($(FPGA_LEASE) start) || exit 1; \
	cd build/impl && $(VIVADO) $(VIVADO_OPTS) -source $(SCRIPTS)/program.tcl -tclargs $$PORT \
		|| { echo "Programming failed (see the messages above).  Your board lease:"; $(FPGA_LEASE) status; echo "If the board was unplugged or replaced, run 'make program' again: it tells you what happened.  ('make release' only gives your board up and closes your UART program.)"; exit 1; }

release:
	@$(FPGA_LEASE) stop

board-status:
	@$(FPGA_LEASE) status

vivado: build
	cd build && nohup $(VIVADO) </dev/null >/dev/null 2>&1 &

lint:
	verilator --lint-only --top-module $(TOP) $(RTL)

sim_build/compile_simlib/synopsys_sim.setup:
	mkdir -p sim_build/compile_simlib
	cd build/sim_build/compile_simlib && $(VIVADO) $(VIVADO_OPTS) -source $(SCRIPTS)/compile_simlib.tcl

compile_simlib: sim_build/compile_simlib/synopsys_sim.setup

clean:
	rm -rf ./build $(junk) *.daidir sim/output.txt \
	sim/*.tb sim/*.daidir sim/csrc \
	sim/ucli.key sim/*.vpd sim/*.vcd sim/*.fsdb \
	sim/*.tbi sim/*.fst sim/*.jou sim/*.log sim/*.out \
	novas.* \
	verdiLog 

.PHONY: setup synth impl program program-force release board-status vivado all clean verdi %.tb \
        sim-uvm uvm-report uvm-clean uvm-verdi
.PRECIOUS: sim/%.tb sim/%.tbi sim/%.fst sim/%.vpd
