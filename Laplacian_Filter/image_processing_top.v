`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06.08.2026 23:14:14
// Design Name: 
// Module Name: image_processing_top
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
/////////////////////////////////////////////////////////////////////////////////


`timescale 1ns / 1ps

module image_processing_top #(
    parameter integer IMG_WIDTH  = 256,
    parameter integer IMG_HEIGHT = 256,
    parameter integer DATA_WIDTH = 8
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  ce,

    input  wire [DATA_WIDTH-1:0] pixel_in,
    input  wire                  pixel_valid,

    output reg  [DATA_WIDTH-1:0] laplacian_out,
    output reg                   laplacian_out_valid
);

    // ============================================================
    // Gaussian window
    // ============================================================

    wire [DATA_WIDTH-1:0] g_p00;
    wire [DATA_WIDTH-1:0] g_p01;
    wire [DATA_WIDTH-1:0] g_p02;

    wire [DATA_WIDTH-1:0] g_p10;
    wire [DATA_WIDTH-1:0] g_p11;
    wire [DATA_WIDTH-1:0] g_p12;

    wire [DATA_WIDTH-1:0] g_p20;
    wire [DATA_WIDTH-1:0] g_p21;
    wire [DATA_WIDTH-1:0] g_p22;

    wire g_window_valid;


    // ============================================================
    // Gaussian result
    // ============================================================

    wire [DATA_WIDTH-1:0] gauss_out;
    wire                  gauss_valid;


    // ============================================================
    // Laplacian window
    // ============================================================

    wire [DATA_WIDTH-1:0] l_p00;
    wire [DATA_WIDTH-1:0] l_p01;
    wire [DATA_WIDTH-1:0] l_p02;

    wire [DATA_WIDTH-1:0] l_p10;
    wire [DATA_WIDTH-1:0] l_p11;
    wire [DATA_WIDTH-1:0] l_p12;

    wire [DATA_WIDTH-1:0] l_p20;
    wire [DATA_WIDTH-1:0] l_p21;
    wire [DATA_WIDTH-1:0] l_p22;

    wire l_window_valid;


    // ============================================================
    // Laplacian result
    // ============================================================

    wire [DATA_WIDTH-1:0] lap_raw;
    wire                  lap_raw_valid;


    // ============================================================
    // STAGE 1
    // Input -> Gaussian line buffer
    // ============================================================

    lineBuffer #(
        .IMG_WIDTH  (IMG_WIDTH),
        .IMG_HEIGHT (IMG_HEIGHT),
        .DATA_WIDTH (DATA_WIDTH)
    )
    u_lineBuffer_G (
        .clk          (clk),
        .rst_n        (rst_n),
        .ce           (ce),

        .pixel_valid  (pixel_valid),
        .pixel_in     (pixel_in),

        .p00          (g_p00),
        .p01          (g_p01),
        .p02          (g_p02),

        .p10          (g_p10),
        .p11          (g_p11),
        .p12          (g_p12),

        .p20          (g_p20),
        .p21          (g_p21),
        .p22          (g_p22),

        .window_valid (g_window_valid)
    );


    // ============================================================
    // STAGE 2
    // Gaussian filter
    // ============================================================

    gaussian3x3 #(
        .DATA_WIDTH(DATA_WIDTH)
    )
    u_gaussian (
        .clk          (clk),
        .rst_n        (rst_n),
        .ce           (ce),

        .p00          (g_p00),
        .p01          (g_p01),
        .p02          (g_p02),

        .p10          (g_p10),
        .p11          (g_p11),
        .p12          (g_p12),

        .p20          (g_p20),
        .p21          (g_p21),
        .p22          (g_p22),

        .window_valid (g_window_valid),

        .gauss_out    (gauss_out),
        .gauss_valid  (gauss_valid)
    );


    // ============================================================
    // STAGE 3
    // Gaussian -> Laplacian line buffer
    // ============================================================

    lineBuffer #(
        .IMG_WIDTH  (IMG_WIDTH),
        .IMG_HEIGHT (IMG_HEIGHT),
        .DATA_WIDTH (DATA_WIDTH)
    )
    u_lineBuffer_L (
        .clk          (clk),
        .rst_n        (rst_n),
        .ce           (ce),

        .pixel_valid  (gauss_valid),
        .pixel_in     (gauss_out),

        .p00          (l_p00),
        .p01          (l_p01),
        .p02          (l_p02),

        .p10          (l_p10),
        .p11          (l_p11),
        .p12          (l_p12),

        .p20          (l_p20),
        .p21          (l_p21),
        .p22          (l_p22),

        .window_valid (l_window_valid)
    );


    // ============================================================
    // STAGE 4
    // Pipelined Laplacian
    // ============================================================

    laplacian3x3 #(
        .DATA_WIDTH(DATA_WIDTH)
    )
    u_laplacian (
        .clk             (clk),
        .rst_n           (rst_n),
        .ce              (ce),

        .p00             (l_p00),
        .p01             (l_p01),
        .p02             (l_p02),

        .p10             (l_p10),
        .p11             (l_p11),
        .p12             (l_p12),

        .p20             (l_p20),
        .p21             (l_p21),
        .p22             (l_p22),

        .window_valid    (l_window_valid),

        .laplacian_out   (lap_raw),
        .laplacian_valid (lap_raw_valid)
    );


    // ============================================================
    // Output coordinate counter
    // ============================================================

    localparam integer COL_W =
        (IMG_WIDTH <= 2) ?
        1 : $clog2(IMG_WIDTH);

    localparam integer ROW_W =
        (IMG_HEIGHT <= 2) ?
        1 : $clog2(IMG_HEIGHT);

    reg [COL_W-1:0] out_col;
    reg [ROW_W-1:0] out_row;


    // ============================================================
    // Output
    //
    // Gaussian + Laplacian gives an effective 5x5 processing
    // region, therefore two pixels around the outside are treated
    // as border.
    //
    // Laplacian zero response = 128.
    // ============================================================

    always @(posedge clk) begin

        if (!rst_n) begin

            out_col <= 0;
            out_row <= 0;

            laplacian_out <=
                {1'b1, {(DATA_WIDTH-1){1'b0}}};

            laplacian_out_valid <=
                1'b0;

        end

        else if (ce) begin

            laplacian_out_valid <=
                lap_raw_valid;


            if (lap_raw_valid) begin

                // =================================================
                // Border suppression
                // =================================================

                if (
                    (out_row < 2) ||
                    (out_row >= IMG_HEIGHT-2) ||
                    (out_col < 2) ||
                    (out_col >= IMG_WIDTH-2)
                ) begin

                    // Zero Laplacian = mid-gray
                    laplacian_out <=
                        {1'b1, {(DATA_WIDTH-1){1'b0}}};

                end

                else begin

                    laplacian_out <=
                        lap_raw;

                end


                // =================================================
                // Output coordinate update
                // =================================================

                if (out_col == IMG_WIDTH-1) begin

                    out_col <= 0;

                    if (out_row == IMG_HEIGHT-1)
                        out_row <= 0;
                    else
                        out_row <=
                            out_row + 1'b1;

                end

                else begin

                    out_col <=
                        out_col + 1'b1;

                end

            end

        end

    end

endmodule