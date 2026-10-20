`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: canny_nms  (Non-Maximum Suppression)
// Status: No timing changes needed — combinational logic is compact.
// The keep signal is a simple 2-comparator expression that synthesises
// comfortably within the 10 ns budget.
// Logic preserved exactly; only comments updated.
//////////////////////////////////////////////////////////////////////////////////

module canny_nms (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       ce,

    input  wire [7:0] p00, p01, p02,
    input  wire [7:0] p10, p11, p12,
    input  wire [7:0] p20, p21, p22,

    input  wire [1:0] dir_in,
    input  wire       window_valid,

    output reg  [7:0] nms_out,
    output reg        nms_valid
);

    reg keep;

    always @(*) begin
        keep = 1'b0;
        case (dir_in)
            2'd0: keep = (p11 > p10) && (p11 >= p12);   // horizontal
            2'd1: keep = (p11 > p00) && (p11 >= p22);   // 45°
            2'd2: keep = (p11 > p01) && (p11 >= p21);   // vertical
            2'd3: keep = (p11 > p02) && (p11 >= p20);   // 135°
            default: keep = 1'b0;
        endcase
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            nms_out   <= 8'd0;
            nms_valid <= 1'b0;
        end
        else if (ce) begin
            nms_valid <= window_valid;
            nms_out   <= (window_valid && keep) ? p11 : 8'd0;
        end
    end

endmodule
