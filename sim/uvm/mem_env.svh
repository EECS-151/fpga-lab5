//=========================================================================
// mem_env: builds and connects every component of the testbench
//-------------------------------------------------------------------------
//
//   agent.mon.req_ap ----> sb.req_export
//   agent.mon.rsp_ap ----> sb.rsp_export
//   sb.checked_ap    ----> cov.analysis_export
//

class mem_env extends uvm_env;
  `uvm_component_utils(mem_env)

  mem_agent      agent;
  mem_scoreboard sb;
  mem_coverage   cov;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = mem_agent     ::type_id::create("agent", this);
    sb    = mem_scoreboard::type_id::create("sb",    this);
    cov   = mem_coverage  ::type_id::create("cov",   this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    agent.mon.req_ap.connect(sb.req_export);
    agent.mon.rsp_ap.connect(sb.rsp_export);
    sb.checked_ap.connect(cov.analysis_export);
  endfunction

endclass
