//=========================================================================
// mem_agent: sequencer, driver and monitor for the FIFO interfaces
//-------------------------------------------------------------------------
// The GCD testbench in the ASIC lab needs two agents because the GCD has
// two independent ready/valid interfaces. Here one driver handles both
// FIFOs, so there is one agent.
//

class mem_agent extends uvm_agent;
  `uvm_component_utils(mem_agent)

  uvm_sequencer #(mem_txn) sqr;
  mem_driver               drv;
  mem_monitor              mon;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    sqr = uvm_sequencer#(mem_txn)::type_id::create("sqr", this);
    drv = mem_driver             ::type_id::create("drv", this);
    mon = mem_monitor            ::type_id::create("mon", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction

endclass
