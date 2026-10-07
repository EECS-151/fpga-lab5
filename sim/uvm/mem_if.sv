`default_nettype none

//=========================================================================
// mem_if: the testbench's view of the rx_fifo -> mem_controller -> tx_fifo
//-------------------------------------------------------------------------
// Classes cannot hold module ports, so the UVM components reach the design
// through a *virtual interface* handle to one instance of this interface.
// mem_tb_top creates the instance and publishes it with uvm_config_db.
//
// The testbench drives the write side of rx_fifo and the read side of
// tx_fifo, exactly like sim/mem_controller_tb.sv. The ctrl_* signals are
// the memory controller's own FIFO pins; the testbench only watches them.
//

`include "uvm_macros.svh"

interface mem_if (
  input wire logic clk
);
  import uvm_pkg::*;

  logic       rst = 1'b1;   // driven by mem_tb_top

  // write side of rx_fifo: the testbench sends packet bytes
  logic       rx_wr_en;
  logic [7:0] rx_din;
  logic       rx_full;

  // read side of tx_fifo: the testbench collects echoed bytes
  logic       tx_rd_en;
  logic [7:0] tx_dout;
  logic       tx_empty;

  // the memory controller's FIFO pins (observed, never driven)
  logic       ctrl_rx_empty;
  logic       ctrl_rx_rd_en;
  logic       ctrl_tx_full;
  logic       ctrl_tx_wr_en;

  //-----------------------------------------------------------------------
  // Protocol assertions
  //-----------------------------------------------------------------------
  // A failing assertion reports through `uvm_error, so it fails the test
  // exactly like a scoreboard mismatch.

  // Your FIFOs come out of reset with known full/empty flags.
  a_fifo_known : assert property (@(posedge clk) disable iff (rst)
      !$isunknown({ctrl_rx_empty, ctrl_tx_full, rx_full, tx_empty}))
    else `uvm_error("MEM_IF", "a FIFO full/empty flag is X/Z after reset")

  // Your memory controller drives known FIFO enables after reset. An X
  // here usually means the state register is never reset.
  a_ctrl_known : assert property (@(posedge clk) disable iff (rst)
      !$isunknown({ctrl_rx_rd_en, ctrl_tx_wr_en}))
    else `uvm_error("MEM_IF", "rx_fifo_rd_en or tx_fifo_wr_en is X/Z after reset")

  // A byte offered to a full rx_fifo stays offered, unchanged, until the
  // FIFO has room. This one checks the TESTBENCH driver, not your design.
  a_drv_hold : assert property (@(posedge clk) disable iff (rst)
      rx_wr_en && rx_full |=> rx_wr_en && $stable(rx_din))
    else `uvm_error("MEM_IF", "driver changed or dropped a byte while rx_fifo was full")

endinterface

`default_nettype wire
