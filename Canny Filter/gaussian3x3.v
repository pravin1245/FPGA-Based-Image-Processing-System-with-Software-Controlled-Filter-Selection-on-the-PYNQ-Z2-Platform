`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: gaussian3x3
// Fix: Two-stage pipeline for the 9-input adder tree.
//      Original single-cycle sum of 9 terms exceeded timing at 100 MHz.
//      Stage A: partial sums of rows.
//      Stage B: combine row sums + divide by 16.
//      This adds ONE cycle of latency (fully absorbed by the streaming pipeline).
//
// Kernel:
//   1 2 1
//   2 4 2
//   1 2 1   / 16
//////////////////////////////////////////////////////////////////////////////////

module gaussian3x3 #(
    parameter integer DATA_WIDTH = 8,
    parameter integer C     = 24,  // corner tap   (|dx|=1,|dy|=1)
    parameter integer E     = 30,  // edge tap     (|dx|=1,|dy|=0 or |dx|=0,|dy|=1)
    parameter integer M     = 40,  // centre tap   (dx=0,dy=0)
    parameter integer SHIFT = 8    // C*4 + E*4 + M == (1 << SHIFT)
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  ce,
 
    input  wire [DATA_WIDTH-1:0] p00, p01, p02,
    input  wire [DATA_WIDTH-1:0] p10, p11, p12,
    input  wire [DATA_WIDTH-1:0] p20, p21, p22,
 
    input  wire                  window_valid,
 
    output reg  [DATA_WIDTH-1:0] gauss_out,
    output reg                   gauss_valid
);
 
    // ------------------------------------------------------------------
    // Stage A: Three-row partial sums (registered), weights per row:
    //   row0 (top)    : C E C
    //   row1 (middle) : E M E
    //   row2 (bottom) : C E C
    // Width: DATA_WIDTH + SHIFT + 2 guard bits (generous, avoids overflow
    // for any reasonable coefficient set).
    // ------------------------------------------------------------------
    localparam integer ROW_W = DATA_WIDTH + SHIFT + 2;
    localparam integer SUM_W = ROW_W + 2;
 
    reg [ROW_W-1:0] row0_sum;   // C*p00 + E*p01 + C*p02
    reg [ROW_W-1:0] row1_sum;   // E*p10 + M*p11 + E*p12
    reg [ROW_W-1:0] row2_sum;   // C*p20 + E*p21 + C*p22
    reg             valid_a;
 
    always @(posedge clk) begin
        if (!rst_n) begin
            row0_sum <= 0;
            row1_sum <= 0;
            row2_sum <= 0;
            valid_a  <= 1'b0;
        end
        else if (ce) begin
            valid_a  <= window_valid;
            row0_sum <= C*p00 + E*p01 + C*p02;
            row1_sum <= E*p10 + M*p11 + E*p12;
            row2_sum <= C*p20 + E*p21 + C*p22;
        end
    end
 
    // ------------------------------------------------------------------
    // Stage B: Combine rows, divide by 2^SHIFT
    // ------------------------------------------------------------------
    wire [SUM_W-1:0] gaussian_sum = row0_sum + row1_sum + row2_sum;
    wire [SUM_W-1:0] gauss_shifted = gaussian_sum >> SHIFT;
 
    always @(posedge clk) begin
        if (!rst_n) begin
            gauss_out   <= 0;
            gauss_valid <= 1'b0;
        end
        else if (ce) begin
            gauss_valid <= valid_a;
            if (valid_a)
                gauss_out <= (gauss_shifted > {DATA_WIDTH{1'b1}})
                             ? {DATA_WIDTH{1'b1}}
                             : gauss_shifted[DATA_WIDTH-1:0];
        end
    end
 
endmodule
 
 