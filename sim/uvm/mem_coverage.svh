//=========================================================================
// mem_coverage: functional coverage of checked packets
//-------------------------------------------------------------------------
// A uvm_subscriber has exactly one input, analysis_export, and one method
// you implement, write(). It is connected to the scoreboard's checked_ap,
// so every read sampled here has already been verified correct.
//
// This covergroup is the coverage target of the lab. Do not edit it: raise
// its score by writing better stimulus, not by changing what is measured.
//

class mem_coverage extends uvm_subscriber #(mem_txn);
  `uvm_component_utils(mem_coverage)

  // For a read: what came right before it?
  typedef enum {
    PREV_NONE,         // it was the first packet
    PREV_WRITE_SAME,   // a write to the same address (read-after-write)
    PREV_WRITE_OTHER,  // a write to a different address
    PREV_READ          // another read
  } prev_e;

  mem_txn t;
  prev_e  prev;

  covergroup cg;
    option.per_instance = 1;
    option.name         = "mem_txn_cg";

    cp_cmd : coverpoint t.cmd;

    // The first and last address are where off-by-one bugs live.
    cp_addr : coverpoint t.addr {
      bins addr_0    = {0};
      bins addr_low  = {[1   : 84]};
      bins addr_mid  = {[85  : 169]};
      bins addr_high = {[170 : 254]};
      bins addr_255  = {255};
    }

    // Both commands at every address range.
    x_cmd_addr : cross cp_cmd, cp_addr;

    // "Bytes might not be sent back-to-back, so your FSM has to wait":
    // idle cycles before the address byte, and before a write's data byte.
    cp_gap_addr : coverpoint t.gap_addr {
      bins gap_none  = {0};
      bins gap_short = {[1:3]};
      bins gap_long  = {[4:$]};
    }
    cp_gap_data : coverpoint t.gap_data iff (t.cmd == MEM_WRITE) {
      bins gap_none  = {0};
      bins gap_short = {[1:3]};
      bins gap_long  = {[4:$]};
    }

    // Did this packet start the cycle after the previous one ended?
    cp_b2b : coverpoint t.back_to_back {
      bins spaced       = {0};
      bins back_to_back = {1};
    }

    // Reads right after a write to the same address, a write elsewhere, or
    // another read.
    cp_prev : coverpoint prev iff (t.cmd == MEM_READ) {
      bins after_write_same  = {PREV_WRITE_SAME};
      bins after_write_other = {PREV_WRITE_OTHER};
      bins after_read        = {PREV_READ};
    }

    // Was tx_fifo full while this read waited? Then your memory controller
    // had to hold its echo until there was room.
    cp_tx_full : coverpoint t.saw_tx_full iff (t.cmd == MEM_READ) {
      bins no_backpressure = {0};
      bins backpressure    = {1};
    }
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    cg = new();
  endfunction

  virtual function void write(mem_txn t);
    this.t = t;

    if (!t.has_prev)                  prev = PREV_NONE;
    else if (t.prev_cmd == MEM_READ)  prev = PREV_READ;
    else if (t.prev_addr == t.addr)   prev = PREV_WRITE_SAME;
    else                              prev = PREV_WRITE_OTHER;

    cg.sample();
  endfunction

  virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("COVERAGE", $sformatf("mem_txn_cg coverage: %0.2f%%", cg.get_inst_coverage()), UVM_NONE)
  endfunction

endclass
