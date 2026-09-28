//=========================================================================
// mem_uvm_pkg: every UVM class of the memory controller testbench
//-------------------------------------------------------------------------
// Include base classes before the classes that use them. Compile with
// +incdir+sim/uvm so VCS can find these .svh files.
//

`include "uvm_macros.svh"

package mem_uvm_pkg;
  import uvm_pkg::*;

  typedef virtual mem_if mem_vif;

  // The two command bytes of the packet format ('0' and '1' in ASCII).
  typedef enum bit [7:0] {
    MEM_READ  = 8'd48,
    MEM_WRITE = 8'd49
  } mem_cmd_e;

  // configuration and transaction
  `include "mem_env_cfg.svh"
  `include "mem_txn.svh"

  // agent
  `include "mem_driver.svh"
  `include "mem_monitor.svh"
  `include "mem_agent.svh"

  // checking and coverage
  `include "mem_scoreboard.svh"
  `include "mem_coverage.svh"

  // environment
  `include "mem_env.svh"

  // stimulus
  `include "mem_seq_lib.svh"

  // tests
  `include "mem_test_lib.svh"
  `include "mem_student_tests.svh"

endpackage
