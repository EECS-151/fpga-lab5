`default_nettype none
`timescale 1ns/10ps

//=========================================================================
// mem_tb_top: the only module in the UVM testbench
//-------------------------------------------------------------------------
// Creates the clock, the interface and the design (your two FIFOs around
// your memory controller, wired exactly as in sim/mem_controller_tb.sv),
// hands the interface to the UVM world through uvm_config_db, and calls
// run_test(). Everything else lives in classes in mem_uvm_pkg.
//

`include "uvm_macros.svh"

module mem_tb_top;
  import uvm_pkg::*;
  import mem_uvm_pkg::*;

  localparam int CLK_PERIOD = 8;
  localparam int FIFO_WIDTH = 8;
  localparam int FIFO_DEPTH = 8;

  logic clk = 1'b0;
  always #(CLK_PERIOD/2) clk = ~clk;

  mem_if mem_if_i (.clk(clk));

  // memory controller <-> FIFOs
  logic                  rx_empty, rx_rd_en;
  logic                  tx_full,  tx_wr_en;
  logic [FIFO_WIDTH-1:0] rx_dout,  tx_din;
  logic [5:0]            leds;

  fifo #(.WIDTH(FIFO_WIDTH), .DEPTH(FIFO_DEPTH)) rx_fifo (
    .clk  (clk),
    .rst  (mem_if_i.rst),
    .wr_en(mem_if_i.rx_wr_en),
    .din  (mem_if_i.rx_din),
    .full (mem_if_i.rx_full),
    .empty(rx_empty),
    .dout (rx_dout),
    .rd_en(rx_rd_en)
  );

  fifo #(.WIDTH(FIFO_WIDTH), .DEPTH(FIFO_DEPTH)) tx_fifo (
    .clk  (clk),
    .rst  (mem_if_i.rst),
    .wr_en(tx_wr_en),
    .din  (tx_din),
    .full (tx_full),
    .empty(mem_if_i.tx_empty),
    .dout (mem_if_i.tx_dout),
    .rd_en(mem_if_i.tx_rd_en)
  );

  mem_controller #(.FIFO_WIDTH(FIFO_WIDTH)) mem_ctrl (
    .clk          (clk),
    .rst          (mem_if_i.rst),
    .rx_fifo_empty(rx_empty),
    .tx_fifo_full (tx_full),
    .din          (rx_dout),
    .rx_fifo_rd_en(rx_rd_en),
    .tx_fifo_wr_en(tx_wr_en),
    .dout         (tx_din),
    .state_leds   (leds)
  );

  // Let the monitor and the assertions see the controller's FIFO pins.
  assign mem_if_i.ctrl_rx_empty = rx_empty;
  assign mem_if_i.ctrl_rx_rd_en = rx_rd_en;
  assign mem_if_i.ctrl_tx_full  = tx_full;
  assign mem_if_i.ctrl_tx_wr_en = tx_wr_en;

  // Reset for five cycles. The driver and monitor wait for it to drop.
  initial begin
    mem_if_i.rst = 1'b1;
    repeat (5) @(negedge clk);
    mem_if_i.rst = 1'b0;
  end

  initial begin
    string fsdb_file;
    if (!$value$plusargs("fsdbfile+%s", fsdb_file)) begin
      fsdb_file = "default.fsdb";
    end
    $fsdbDumpfile(fsdb_file);
    $fsdbDumpvars(0, mem_tb_top);
    // "uvm_test_top*" is the test and every component below it, so the
    // test, the driver and the monitor all get this interface.
    uvm_config_db#(mem_vif)::set(null, "uvm_test_top*", "vif", mem_if_i);
    run_test();
  end

endmodule

`default_nettype wire
