//=========================================================================
// mem_txn: one read or write packet and (for a read) the echoed byte
//-------------------------------------------------------------------------
// The same class is used everywhere:
//   * sequences randomize the stimulus fields and send it to the driver
//   * the monitor builds one from the bytes it sees enter rx_fifo, and
//     fills in the timing it observed
//   * for a read, the monitor also reports the byte that left tx_fifo
//   * the scoreboard checks it and passes it to the coverage subscriber
//
//   WRITE packet: 8'd49, addr, data     (3 bytes)
//   READ  packet: 8'd48, addr           (2 bytes, then 1 byte echoed back)
//

class mem_txn extends uvm_sequence_item;
  `uvm_object_utils(mem_txn)

  //-----------------------------------------------------------------------
  // Stimulus (randomized by sequences)
  //-----------------------------------------------------------------------
  rand mem_cmd_e    cmd;
  rand bit [7:0]    addr;
  rand bit [7:0]    data;         // ignored for reads

  // Cycles the driver waits, with rx_wr_en low, before each byte:
  //   idle_cycles  before the command byte (0: right after the last packet)
  //   gap_addr     between the command byte and the address byte
  //   gap_data     between the address byte and the data byte (writes only)
  rand int unsigned idle_cycles;
  rand int unsigned gap_addr;
  rand int unsigned gap_data;

  // Inline constraints add to these defaults. Disable a conflicting default
  // before randomizing, for example:
  //   t.c_small_addr.constraint_mode(0);
  //   if (!t.randomize() with { addr == 255; }) `uvm_error(...)

  // Only 10 of the 256 addresses.
  constraint c_small_addr {
    addr inside {[10:19]};
  }

  // Every packet's bytes arrive back-to-back.
  constraint c_no_gaps {
    gap_addr == 0;
    gap_data == 0;
  }

  // Packets are spaced out by 1-4 idle cycles (never back-to-back).
  constraint c_idle {
    idle_cycles inside {[1:4]};
  }

  // Keep solver ranges sane even with the defaults switched off.
  constraint c_limits {
    idle_cycles <= 64;
    gap_addr    <= 64;
    gap_data    <= 64;
  }

  //-----------------------------------------------------------------------
  // Observed (filled in by the monitor / scoreboard, never randomized)
  //-----------------------------------------------------------------------
  logic [7:0]  rdata;          // READ: the byte echoed through tx_fifo (X if the DUT echoed X)
  bit          back_to_back;   // command byte entered rx_fifo the cycle
                               // after the previous packet's last byte
  bit          saw_tx_full;    // READ: tx_fifo was full at some point while
                               // this read was waiting for its echo
  bit          has_prev;       // there was a packet before this one ...
  mem_cmd_e    prev_cmd;       // ... and this was its command
  bit [7:0]    prev_addr;      // ... and its address

  function new(string name = "mem_txn");
    super.new(name);
  endfunction

  virtual function void do_copy(uvm_object rhs);
    mem_txn rhs_;
    if (!$cast(rhs_, rhs)) `uvm_fatal("MEM_TXN", "do_copy: rhs is not a mem_txn")
    super.do_copy(rhs);
    cmd          = rhs_.cmd;
    addr         = rhs_.addr;
    data         = rhs_.data;
    idle_cycles  = rhs_.idle_cycles;
    gap_addr     = rhs_.gap_addr;
    gap_data     = rhs_.gap_data;
    rdata        = rhs_.rdata;
    back_to_back = rhs_.back_to_back;
    saw_tx_full  = rhs_.saw_tx_full;
    has_prev     = rhs_.has_prev;
    prev_cmd     = rhs_.prev_cmd;
    prev_addr    = rhs_.prev_addr;
  endfunction

  virtual function string convert2string();
    if (cmd == MEM_WRITE)
      return $sformatf("WRITE addr=%0d data=%0d (idle=%0d gaps=%0d,%0d b2b=%0b)",
                       addr, data, idle_cycles, gap_addr, gap_data, back_to_back);
    return $sformatf("READ addr=%0d rdata=%0d (idle=%0d gap=%0d b2b=%0b tx_full=%0b)",
                     addr, rdata, idle_cycles, gap_addr, back_to_back, saw_tx_full);
  endfunction

endclass
