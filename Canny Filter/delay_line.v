`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: delay_line
// Status: Timing-clean (single-register pipeline stage).
// Used in image_processing_top to align NMS output before double-threshold.
// Logic unchanged.
//////////////////////////////////////////////////////////////////////////////////

module delay_line #(
    parameter integer WIDTH = 8
)(
    input  wire             clk,
    input  wire             rst_n,
    input  wire             ce,

    input  wire [WIDTH-1:0] data_in,
    input  wire             valid_in,

    output reg  [WIDTH-1:0] data_out,
    output reg              valid_out
);

    always @(posedge clk) begin
        if (!rst_n) begin
            data_out  <= 0;
            valid_out <= 1'b0;
        end
        else if (ce) begin
            data_out  <= data_in;
            valid_out <= valid_in;
        end
    end

endmodule
