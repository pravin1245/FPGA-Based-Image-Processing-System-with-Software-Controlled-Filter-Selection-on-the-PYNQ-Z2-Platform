`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: canny_gradient_direction
// Fix: Break long combinational path in Sobel calculation into two pipeline stages.
//
// Stage A (registered): Compute gx_pos, gx_neg, gy_pos, gy_neg partial sums.
// Stage B (registered): Compute gx, gy, abs_gx, abs_gy, mag_sum, dir_out.
//
// This adds ONE extra register stage compared to the original (which was already
// 1-cycle registered).  Total added latency = +1 cycle over the original.
// Downstream pipeline is unchanged since valid propagates through the same delay.
//////////////////////////////////////////////////////////////////////////////////

module canny_gradient_direction (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       ce,

    input  wire [7:0] p00, p01, p02,
    input  wire [7:0] p10, p11, p12,
    input  wire [7:0] p20, p21, p22,

    input  wire       window_valid,

    output reg  [7:0] mag_out,
    output reg  [1:0] dir_out,
    output reg        grad_valid
);

    // ------------------------------------------------------------------
    // Stage A: Partial sums for Gx and Gy  (break long add-tree)
    // Width 11 bits: max unsigned partial = 255 + 510 + 255 = 1020 < 2^10
    // Use 12 signed bits for safety.
    // ------------------------------------------------------------------
    reg signed [11:0] gx_pos_r, gx_neg_r;
    reg signed [11:0] gy_pos_r, gy_neg_r;
    reg               valid_a;

    always @(posedge clk) begin
        if (!rst_n) begin
            gx_pos_r <= 0;  gx_neg_r <= 0;
            gy_pos_r <= 0;  gy_neg_r <= 0;
            valid_a  <= 1'b0;
        end
        else if (ce) begin
            valid_a  <= window_valid;
            // Gx positive column (right column)
            gx_pos_r <= $signed({4'b0000, p02})
                      + $signed({3'b000, p12, 1'b0})
                      + $signed({4'b0000, p22});
            // Gx negative column (left column)
            gx_neg_r <= $signed({4'b0000, p00})
                      + $signed({3'b000, p10, 1'b0})
                      + $signed({4'b0000, p20});
            // Gy positive row (bottom row)
            gy_pos_r <= $signed({4'b0000, p20})
                      + $signed({3'b000, p21, 1'b0})
                      + $signed({4'b0000, p22});
            // Gy negative row (top row)
            gy_neg_r <= $signed({4'b0000, p00})
                      + $signed({3'b000, p01, 1'b0})
                      + $signed({4'b0000, p02});
        end
    end

    // ------------------------------------------------------------------
    // Stage B: Compute gradients, magnitude, direction  (short paths)
    // ------------------------------------------------------------------
    wire signed [11:0] gx_w = gx_pos_r - gx_neg_r;
    wire signed [11:0] gy_w = gy_pos_r - gy_neg_r;

    wire [11:0] abs_gx_w = gx_w[11] ? (~gx_w + 1'b1) : gx_w;
    wire [11:0] abs_gy_w = gy_w[11] ? (~gy_w + 1'b1) : gy_w;

    wire [12:0] mag_sum_w = abs_gx_w + abs_gy_w;

    always @(posedge clk) begin
        if (!rst_n) begin
            mag_out    <= 8'd0;
            dir_out    <= 2'd0;
            grad_valid <= 1'b0;
        end
        else if (ce) begin
            grad_valid <= valid_a;

            if (valid_a) begin
                // Saturating magnitude
                mag_out <= (mag_sum_w > 13'd255) ? 8'd255 : mag_sum_w[7:0];

                // Direction encoding
                if (abs_gx_w > (abs_gy_w << 1))
                    dir_out <= 2'd0;          // horizontal
                else if (abs_gy_w > (abs_gx_w << 1))
                    dir_out <= 2'd2;          // vertical
                else if (gx_w[11] == gy_w[11])
                    dir_out <= 2'd1;          // 45°
                else
                    dir_out <= 2'd3;          // 135°
            end
            else begin
                mag_out <= 8'd0;
                dir_out <= 2'd0;
            end
        end
    end

endmodule
