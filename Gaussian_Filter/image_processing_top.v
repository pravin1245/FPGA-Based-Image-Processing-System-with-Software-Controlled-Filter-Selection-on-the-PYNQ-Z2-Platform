`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 14.07.2026 23:54:50
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
//////////////////////////////////////////////////////////////////////////////////



module image_processing_top #(
    parameter integer IMG_WIDTH  = 256,
    parameter integer IMG_HEIGHT = 256,
    parameter integer DATA_WIDTH = 8
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  ce,

    // =========================================================
    // Filter selection
    // 0 = Gaussian
    // 1 = Sobel
    // =========================================================
    input  wire                  filter_select,

    // Input pixel stream
    input  wire [DATA_WIDTH-1:0] pixel_in,
    input  wire                  pixel_valid,

    // Gaussian output
    output wire [DATA_WIDTH-1:0] gaussian_out,
    output wire                  gaussian_out_valid,

    // Sobel output
    output wire [DATA_WIDTH-1:0] sobel_out,
    output wire                  sobel_out_valid
);


    // =========================================================
    // GAUSSIAN STAGE
    // =========================================================

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

    wire [DATA_WIDTH-1:0] gaussian_pixel;
    wire                  gaussian_valid;


    // =========================================================
    // Gaussian Line Buffer
    // =========================================================

    lineBuffer #(
        .IMG_WIDTH  (IMG_WIDTH),
        .IMG_HEIGHT (IMG_HEIGHT),
        .DATA_WIDTH (DATA_WIDTH)
    )
    u_gaussian_line_buffer
    (
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


    // =========================================================
    // Gaussian Filter
    // =========================================================

    gaussian3x3 #(
        .DATA_WIDTH(DATA_WIDTH)
    )
    u_gaussian
    (
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

        .gauss_out    (gaussian_pixel),
        .gauss_valid  (gaussian_valid)
    );


    // =========================================================
    // Gaussian Output
    // =========================================================

    assign gaussian_out =
        gaussian_pixel;

    assign gaussian_out_valid =
        gaussian_valid;


    // =========================================================
    // SOBEL STAGE
    //
    // Sobel receives the Gaussian output.
    //
    // filter_select = 0:
    //      Gaussian only
    //
    // filter_select = 1:
    //      Gaussian -> Sobel
    // =========================================================

    wire [DATA_WIDTH-1:0] s_p00;
    wire [DATA_WIDTH-1:0] s_p01;
    wire [DATA_WIDTH-1:0] s_p02;

    wire [DATA_WIDTH-1:0] s_p10;
    wire [DATA_WIDTH-1:0] s_p11;
    wire [DATA_WIDTH-1:0] s_p12;

    wire [DATA_WIDTH-1:0] s_p20;
    wire [DATA_WIDTH-1:0] s_p21;
    wire [DATA_WIDTH-1:0] s_p22;

    wire s_window_valid;

    wire [DATA_WIDTH-1:0] sobel_pixel;
    wire                  sobel_valid;


    // =========================================================
    // Sobel enable
    // =========================================================

    wire sobel_input_valid;

    assign sobel_input_valid =
        gaussian_valid &&
        filter_select;


    // =========================================================
    // Sobel Line Buffer
    // =========================================================

    lineBuffer #(
        .IMG_WIDTH  (IMG_WIDTH),
        .IMG_HEIGHT (IMG_HEIGHT),
        .DATA_WIDTH (DATA_WIDTH)
    )
    u_sobel_line_buffer
    (
        .clk          (clk),
        .rst_n        (rst_n),
        .ce           (ce),

        .pixel_valid  (sobel_input_valid),
        .pixel_in     (gaussian_pixel),

        .p00          (s_p00),
        .p01          (s_p01),
        .p02          (s_p02),

        .p10          (s_p10),
        .p11          (s_p11),
        .p12          (s_p12),

        .p20          (s_p20),
        .p21          (s_p21),
        .p22          (s_p22),

        .window_valid (s_window_valid)
    );


    // =========================================================
    // Sobel Filter
    // =========================================================

    sobel3x3 #(
        .DATA_WIDTH(DATA_WIDTH)
    )
    u_sobel
    (
        .clk          (clk),
        .rst_n        (rst_n),
        .ce           (ce),

        .p00          (s_p00),
        .p01          (s_p01),
        .p02          (s_p02),

        .p10          (s_p10),
        .p11          (s_p11),
        .p12          (s_p12),

        .p20          (s_p20),
        .p21          (s_p21),
        .p22          (s_p22),

        .window_valid (s_window_valid),

        .sobel_out    (sobel_pixel),
        .sobel_valid  (sobel_valid)
    );


    // =========================================================
    // Sobel Output
    // =========================================================

    assign sobel_out =
        sobel_pixel;

    assign sobel_out_valid =
        sobel_valid;


endmodule