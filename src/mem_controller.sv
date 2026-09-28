module mem_controller #(
  parameter FIFO_WIDTH = 8
) (
  input logic clk,
  input logic rst,
  input logic rx_fifo_empty,
  input logic tx_fifo_full,
  input logic [FIFO_WIDTH-1:0] din,

  output logic rx_fifo_rd_en,
  output logic tx_fifo_wr_en,
  output logic [FIFO_WIDTH-1:0] dout,
  output logic [5:0] state_leds
);

  localparam MEM_WIDTH = 8; // Width of each mem entry (word)
  localparam MEM_DEPTH = 256; // Number of entries
  localparam NUM_BYTES_PER_WORD = MEM_WIDTH/8;
  localparam MEM_ADDR_WIDTH = $clog2(MEM_DEPTH); 

  logic [NUM_BYTES_PER_WORD-1:0] mem_we = 0;
  logic [MEM_ADDR_WIDTH-1:0] mem_addr;
  logic [MEM_WIDTH-1:0] mem_din;
  logic [MEM_WIDTH-1:0] mem_dout;

  memory #(
    .MEM_WIDTH(MEM_WIDTH),
    .DEPTH(MEM_DEPTH)
  ) mem(
    .clk(clk),
    .en(1'b1),
    .we(mem_we),
    .addr(mem_addr),
    .din(mem_din),
    .dout(mem_dout)
  );

  localparam 
    IDLE = 3'd0,
    READ_CMD = 3'd1,
    READ_ADDR = 3'd2,
    READ_DATA = 3'd3,
    READ_MEM_VAL = 3'd4,
    ECHO_VAL = 3'd5,
    WRITE_MEM_VAL = 3'd6;

  logic [2:0] curr_state;
  logic [2:0] next_state;

  always_ff @(posedge clk) begin

    // State logic update

  end

  logic [MEM_WIDTH-1:0] cmd;
  logic [MEM_WIDTH-1:0] addr;
  logic [MEM_WIDTH-1:0] data;


  always_comb begin
    
    // Initial values to avoid latch synthesis

    case (curr_state)

      // Next state logic

    endcase

  end

  always_comb begin
    
    // Initial values to avoid latch synthesis
    
    case (curr_state)

      // output logic and mem signal logic
      
    endcase

  end

  // TODO: MODIFY THIS
  assign state_leds = 'd0;

  // TODO: MODIFY/REMOVE THIS
  assign rx_fifo_rd_en = 'd0;
  assign tx_fifo_wr_en = 'd0;
  assign dout = 'd0;

endmodule
