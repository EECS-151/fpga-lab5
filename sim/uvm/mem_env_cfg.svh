//=========================================================================
// mem_env_cfg: test-wide knobs that are not part of any one packet
//-------------------------------------------------------------------------
// mem_base_test creates one of these, lets the test change it in
// configure(), and publishes it with uvm_config_db before building the env.
//

class mem_env_cfg extends uvm_object;
  `uvm_object_utils(mem_env_cfg)

  // Before popping each echoed byte from tx_fifo, the driver waits a random
  // number of cycles in [tx_delay_min : tx_delay_max]. Larger delays let
  // tx_fifo fill up, which applies backpressure to your memory controller.
  // The default, 0, pops every byte as soon as it appears.
  int unsigned tx_delay_min = 0;
  int unsigned tx_delay_max = 0;

  function new(string name = "mem_env_cfg");
    super.new(name);
  endfunction

endclass
