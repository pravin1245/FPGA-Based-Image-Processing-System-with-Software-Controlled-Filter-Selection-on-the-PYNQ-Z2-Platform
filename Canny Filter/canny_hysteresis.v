`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: canny_hysteresis
// Fix: Register the neighbor_strong OR-reduction one stage earlier (inside
//      the clocked block) to prevent a wide OR tree from contributing to
//      the output register setup time.
//      Logic: an 8-input OR of 8-bit comparisons is small, but keeping it
//      purely combinational and then comparing p11 in the same cycle creates
//      a two-level path that risks meeting setup on older speed-grades.
//      Registered here for robustness.
//
// One cycle of added latency — absorbed by streaming pipeline.
//////////////////////////////////////////////////////////////////////////////////

module canny_hysteresis (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       ce,

    input  wire [7:0] p00, p01, p02,
    input  wire [7:0] p10, p11, p12,
    input  wire [7:0] p20, p21, p22,

    input  wire       window_valid,

    output reg  [7:0] edge_out,
    output reg        edge_valid
);

    // Stage A: register the neighbor strong check and center pixel
    reg        neighbor_strong_r;
    reg [7:0]  center_r;
    reg        valid_a;

    always @(posedge clk) begin
        if (!rst_n) begin
            neighbor_strong_r <= 1'b0;
            center_r          <= 8'd0;
            valid_a           <= 1'b0;
        end
        else if (ce) begin
            valid_a           <= window_valid;
            center_r          <= p11;
            neighbor_strong_r <=
                   (p00 == 8'hFF) || (p01 == 8'hFF) || (p02 == 8'hFF)
                || (p10 == 8'hFF)                   || (p12 == 8'hFF)
                || (p20 == 8'hFF) || (p21 == 8'hFF) || (p22 == 8'hFF);
        end
    end

    // Stage B: decision
    always @(posedge clk) begin
        if (!rst_n) begin
            edge_out   <= 8'd0;
            edge_valid <= 1'b0;
        end
        else if (ce) begin
            edge_valid <= valid_a;

            if (valid_a) begin
                if (center_r == 8'hFF)
                    edge_out <= 8'hFF;
                else if ((center_r == 8'h80) && neighbor_strong_r)
                    edge_out <= 8'hFF;
                else
                    edge_out <= 8'h00;
            end
            else begin
                edge_out <= 8'h00;
            end
        end
    end

endmodule
