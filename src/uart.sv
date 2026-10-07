module uart #(
    parameter CLOCK_FREQ = 125_000_000,
    parameter BAUD_RATE = 115_200
) (
    input wire logic clk,
    input wire logic reset,

    input wire logic [7:0] data_in,
    input wire logic data_in_valid,
    output logic data_in_ready,

    output logic [7:0] data_out,
    output logic data_out_valid,
    input wire logic data_out_ready,

    input wire logic serial_in,
    output logic serial_out
);
    logic serial_in_reg, serial_out_reg;
    logic serial_out_tx;
    assign serial_out = serial_out_reg;
    always @ (posedge clk) begin
        serial_out_reg <= reset ? 1'b1 : serial_out_tx;
        serial_in_reg <= reset ? 1'b1 : serial_in;
    end

    uart_transmitter #(
        .CLOCK_FREQ(CLOCK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) uatransmit (
        .clk(clk),
        .reset(reset),
        .data_in(data_in),
        .data_in_valid(data_in_valid),
        .data_in_ready(data_in_ready),
        .serial_out(serial_out_tx)
    );

    uart_receiver #(
        .CLOCK_FREQ(CLOCK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) uareceive (
        .clk(clk),
        .reset(reset),
        .data_out(data_out),
        .data_out_valid(data_out_valid),
        .data_out_ready(data_out_ready),
        .serial_in(serial_in_reg)
    );
endmodule
