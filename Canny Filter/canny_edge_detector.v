`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06.08.2026 20:44:06
// Design Name: 
// Module Name: canny_edge_detector
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


`timescale 1ns / 1ps

module canny_edge_detector #(
    parameter integer IMG_WIDTH  = 256,
    parameter integer IMG_HEIGHT = 256,
    parameter integer DATA_WIDTH = 8,

    parameter [DATA_WIDTH-1:0] LOW_TH  = 8'd50,
    parameter [DATA_WIDTH-1:0] HIGH_TH = 8'd100
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  ce,

    // Gaussian-filtered input
    input  wire [DATA_WIDTH-1:0] pixel_in,
    input  wire                  pixel_valid,

    // Binary edge output
    output reg  [DATA_WIDTH-1:0] edge_out,
    output reg                   edge_valid
);

    // ============================================================
    // Stage 1: 3x3 window for Sobel
    // ============================================================

    wire [DATA_WIDTH-1:0] s_p00, s_p01, s_p02;
    wire [DATA_WIDTH-1:0] s_p10, s_p11, s_p12;
    wire [DATA_WIDTH-1:0] s_p20, s_p21, s_p22;

    wire sobel_window_valid;

    lineBuffer #(
        .IMG_WIDTH  (IMG_WIDTH),
        .IMG_HEIGHT (IMG_HEIGHT),
        .DATA_WIDTH (DATA_WIDTH)
    ) u_sobel_line_buffer (
        .clk          (clk),
        .rst_n        (rst_n),
        .ce           (ce),

        .pixel_valid  (pixel_valid),
        .pixel_in     (pixel_in),

        .p00          (s_p00),
        .p01          (s_p01),
        .p02          (s_p02),

        .p10          (s_p10),
        .p11          (s_p11),
        .p12          (s_p12),

        .p20          (s_p20),
        .p21          (s_p21),
        .p22          (s_p22),

        .window_valid (sobel_window_valid)
    );

    // ============================================================
    // Stage 2: Sobel Gx and Gy
    // ============================================================

    wire signed [DATA_WIDTH+3:0] gx;
    wire signed [DATA_WIDTH+3:0] gy;

    assign gx =
          $signed({1'b0, s_p02})
        + ($signed({1'b0, s_p12}) <<< 1)
        + $signed({1'b0, s_p22})
        - $signed({1'b0, s_p00})
        - ($signed({1'b0, s_p10}) <<< 1)
        - $signed({1'b0, s_p20});

    assign gy =
          $signed({1'b0, s_p20})
        + ($signed({1'b0, s_p21}) <<< 1)
        + $signed({1'b0, s_p22})
        - $signed({1'b0, s_p00})
        - ($signed({1'b0, s_p01}) <<< 1)
        - $signed({1'b0, s_p02});

    wire [DATA_WIDTH+3:0] abs_gx;
    wire [DATA_WIDTH+3:0] abs_gy;

    assign abs_gx = gx[DATA_WIDTH+3] ? -gx : gx;
    assign abs_gy = gy[DATA_WIDTH+3] ? -gy : gy;

    // Approximate magnitude = |Gx| + |Gy|
    wire [DATA_WIDTH+4:0] magnitude_full;

    assign magnitude_full = abs_gx + abs_gy;

    // Saturate magnitude to 8-bit
    wire [DATA_WIDTH-1:0] magnitude_comb;

    assign magnitude_comb =
        |magnitude_full[DATA_WIDTH+4:DATA_WIDTH]
        ? {DATA_WIDTH{1'b1}}
        : magnitude_full[DATA_WIDTH-1:0];

    // ============================================================
    // Gradient direction
    //
    // 00 = 0 degrees
    // 01 = 45 degrees
    // 10 = 90 degrees
    // 11 = 135 degrees
    // ============================================================

    reg [1:0] direction_comb;

    always @(*) begin
        if (abs_gx >= (abs_gy << 1)) begin
            direction_comb = 2'b00;
        end
        else if (abs_gy >= (abs_gx << 1)) begin
            direction_comb = 2'b10;
        end
        else if (gx[DATA_WIDTH+3] == gy[DATA_WIDTH+3]) begin
            direction_comb = 2'b01;
        end
        else begin
            direction_comb = 2'b11;
        end
    end

    // ============================================================
    // Register magnitude and direction
    // ============================================================

    reg [DATA_WIDTH-1:0] magnitude_reg;
    reg [1:0]            direction_reg;
    reg                  magnitude_valid;

    always @(posedge clk) begin
        if (!rst_n) begin
            magnitude_reg   <= {DATA_WIDTH{1'b0}};
            direction_reg   <= 2'b00;
            magnitude_valid <= 1'b0;
        end
        else if (ce) begin
            magnitude_valid <= sobel_window_valid;

            if (sobel_window_valid) begin
                magnitude_reg <= magnitude_comb;
                direction_reg <= direction_comb;
            end
            else begin
                magnitude_reg <= {DATA_WIDTH{1'b0}};
                direction_reg <= 2'b00;
            end
        end
    end

    // ============================================================
    // Stage 3: 3x3 magnitude window for NMS
    // ============================================================

    wire [DATA_WIDTH-1:0] m_p00, m_p01, m_p02;
    wire [DATA_WIDTH-1:0] m_p10, m_p11, m_p12;
    wire [DATA_WIDTH-1:0] m_p20, m_p21, m_p22;

    wire magnitude_window_valid;

    lineBuffer #(
        .IMG_WIDTH  (IMG_WIDTH),
        .IMG_HEIGHT (IMG_HEIGHT),
        .DATA_WIDTH (DATA_WIDTH)
    ) u_magnitude_line_buffer (
        .clk          (clk),
        .rst_n        (rst_n),
        .ce           (ce),

        .pixel_valid  (magnitude_valid),
        .pixel_in     (magnitude_reg),

        .p00          (m_p00),
        .p01          (m_p01),
        .p02          (m_p02),

        .p10          (m_p10),
        .p11          (m_p11),
        .p12          (m_p12),

        .p20          (m_p20),
        .p21          (m_p21),
        .p22          (m_p22),

        .window_valid (magnitude_window_valid)
    );

    // ============================================================
    // Stage 4: 3x3 direction window
    //
    // Only d_p11 is used. The direction window keeps the direction
    // aligned with the center magnitude m_p11.
    // ============================================================

    wire [1:0] d_p00, d_p01, d_p02;
    wire [1:0] d_p10, d_p11, d_p12;
    wire [1:0] d_p20, d_p21, d_p22;

    wire direction_window_valid;

    lineBuffer #(
        .IMG_WIDTH  (IMG_WIDTH),
        .IMG_HEIGHT (IMG_HEIGHT),
        .DATA_WIDTH (2)
    ) u_direction_line_buffer (
        .clk          (clk),
        .rst_n        (rst_n),
        .ce           (ce),

        .pixel_valid  (magnitude_valid),
        .pixel_in     (direction_reg),

        .p00          (d_p00),
        .p01          (d_p01),
        .p02          (d_p02),

        .p10          (d_p10),
        .p11          (d_p11),
        .p12          (d_p12),

        .p20          (d_p20),
        .p21          (d_p21),
        .p22          (d_p22),

        .window_valid (direction_window_valid)
    );

    // ============================================================
    // Stage 5: Non-maximum suppression
    // ============================================================

    reg [DATA_WIDTH-1:0] neighbor_1;
    reg [DATA_WIDTH-1:0] neighbor_2;

    always @(*) begin
        neighbor_1 = {DATA_WIDTH{1'b0}};
        neighbor_2 = {DATA_WIDTH{1'b0}};

        case (d_p11)

            // Gradient direction 0 degrees
            // Compare left and right
            2'b00: begin
                neighbor_1 = m_p10;
                neighbor_2 = m_p12;
            end

            // Gradient direction 45 degrees
            // Compare top-right and bottom-left
            2'b01: begin
                neighbor_1 = m_p02;
                neighbor_2 = m_p20;
            end

            // Gradient direction 90 degrees
            // Compare top and bottom
            2'b10: begin
                neighbor_1 = m_p01;
                neighbor_2 = m_p21;
            end

            // Gradient direction 135 degrees
            // Compare top-left and bottom-right
            default: begin
                neighbor_1 = m_p00;
                neighbor_2 = m_p22;
            end
        endcase
    end

    wire local_maximum;

    assign local_maximum =
        (m_p11 > neighbor_1) &&
        (m_p11 >= neighbor_2);

    // ============================================================
    // Stage 6: Threshold after NMS
    //
    // White = strong edge
    // Black = background
    //
    // Weak edges are suppressed because complete hysteresis tracing
    // requires neighborhood connectivity processing.
    // ============================================================

    always @(posedge clk) begin
        if (!rst_n) begin
            edge_out   <= {DATA_WIDTH{1'b0}};
            edge_valid <= 1'b0;
        end
        else if (ce) begin
            edge_valid <= magnitude_window_valid &&
                          direction_window_valid;

            if (magnitude_window_valid &&
                direction_window_valid) begin

                if (local_maximum && (m_p11 >= HIGH_TH))
                    edge_out <= {DATA_WIDTH{1'b1}};
                else
                    edge_out <= {DATA_WIDTH{1'b0}};
            end
            else begin
                edge_out <= {DATA_WIDTH{1'b0}};
            end
        end
    end

endmodule