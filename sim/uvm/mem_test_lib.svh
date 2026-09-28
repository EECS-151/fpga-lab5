//=========================================================================
// Tests: run one with +UVM_TESTNAME=<class name>
//-------------------------------------------------------------------------
// All test classes are compiled together; +UVM_TESTNAME selects which runs.
//

// Builds the env, runs the sequence returned by make_seq(), waits for
// every read to be echoed, and prints a pass/fail line.
class mem_base_test extends uvm_test;
  `uvm_component_utils(mem_base_test)

  mem_env     env;
  mem_env_cfg cfg;
  mem_vif     vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // Override in a derived test to change test-wide knobs, for example
  //   cfg.tx_delay_max = 20;
  virtual function void configure(mem_env_cfg cfg);
  endfunction

  // Override in each derived test to choose its stimulus.
  virtual function uvm_sequence #(mem_txn) make_seq();
    `uvm_fatal("TEST", "mem_base_test has no stimulus; run a derived test")
    return null;
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    cfg = mem_env_cfg::type_id::create("cfg");
    configure(cfg);
    if (cfg.tx_delay_min > cfg.tx_delay_max)
      `uvm_fatal("CFG", "tx_delay_min is larger than tx_delay_max")
    uvm_config_db#(mem_env_cfg)::set(this, "*", "cfg", cfg);
    if (!uvm_config_db#(mem_vif)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "mem_base_test: no virtual interface set for 'vif'")
    env = mem_env::type_id::create("env", this);
    // A test that never finishes (e.g. a memory controller stuck waiting
    // for a byte) is killed here with a UVM_FATAL instead of running
    // forever. Override on the command line with +UVM_TIMEOUT=<time>.
    uvm_root::get().set_timeout(2ms, 1);
    // Stop after 20 errors: the first few messages are the useful ones.
    uvm_report_server::get_server().set_max_quit_count(20);
  endfunction

  virtual function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_root::get().print_topology();
  endfunction

  virtual task run_phase(uvm_phase phase);
    uvm_sequence #(mem_txn) seq;

    phase.raise_objection(this);
    seq = make_seq();
    seq.start(env.agent.sqr);
    env.sb.wait_for_drain();
    // Give the design time to finish the last packet and to echo anything
    // it should not have (the scoreboard flags extra echoes).
    repeat (50) @(posedge vif.clk);
    phase.drop_objection(this);
  endtask

  // UVM_ERRORs do not change the simulator's exit status. Print an explicit
  // verdict to look for instead.
  virtual function void report_phase(uvm_phase phase);
    uvm_report_server svr = uvm_report_server::get_server();
    int unsigned      n_bad;
    super.report_phase(phase);
    n_bad = svr.get_severity_count(UVM_ERROR) + svr.get_severity_count(UVM_FATAL);
    if (n_bad != 0)
      $display("[ FAILED ] %s: %0d UVM_ERROR/UVM_FATAL message(s)", get_type_name(), n_bad);
    else
      $display("[ passed ] %s", get_type_name());
  endfunction

  // A UVM_FATAL (including the timeout above) ends the simulation without
  // reaching report_phase; UVM calls pre_abort() on every component first.
  virtual function void pre_abort();
    $display("[ FAILED ] %s: aborted (UVM_FATAL or too many UVM_ERRORs)", get_type_name());
  endfunction

endclass

// Baseline: ten random packets using every default constraint.
class mem_smoke_test extends mem_base_test;
  `uvm_component_utils(mem_smoke_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function uvm_sequence #(mem_txn) make_seq();
    mem_rand_seq seq = mem_rand_seq::type_id::create("seq");
    seq.num_items = 10;
    return seq;
  endfunction

endclass
