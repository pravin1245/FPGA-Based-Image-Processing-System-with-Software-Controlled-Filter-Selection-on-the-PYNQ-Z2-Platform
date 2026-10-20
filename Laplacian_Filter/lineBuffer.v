`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06.08.2026 23:28:59
// Design Name: 
// Module Name: lineBuffer
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





module lineBuffer #(
    parameter integer IMG_WIDTH  = 256,
    parameter integer IMG_HEIGHT = 256,
    parameter integer DATA_WIDTH = 8
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  ce,

    input  wire                  pixel_valid,
    input  wire [DATA_WIDTH-1:0] pixel_in,

    output reg [DATA_WIDTH-1:0] p00,
    output reg [DATA_WIDTH-1:0] p01,
    output reg [DATA_WIDTH-1:0] p02,

    output reg [DATA_WIDTH-1:0] p10,
    output reg [DATA_WIDTH-1:0] p11,
    output reg [DATA_WIDTH-1:0] p12,

    output reg [DATA_WIDTH-1:0] p20,
    output reg [DATA_WIDTH-1:0] p21,
    output reg [DATA_WIDTH-1:0] p22,

    output reg window_valid
);

    localparam integer COL_W =
        (IMG_WIDTH <= 1) ?
        1 : $clog2(IMG_WIDTH);

    localparam integer ROW_W =
        (IMG_HEIGHT <= 1) ?
        1 : $clog2(IMG_HEIGHT);


    // ============================================================
    // Two previous image rows
    // ============================================================

    reg [DATA_WIDTH-1:0]
        line0 [0:IMG_WIDTH-1];

    reg [DATA_WIDTH-1:0]
        line1 [0:IMG_WIDTH-1];


    reg [COL_W-1:0] col_cnt;
    reg [ROW_W-1:0] row_cnt;

    integer i;


    // ============================================================
    // LINE BUFFER
    // ============================================================

    always @(posedge clk) begin

        if (!rst_n) begin

            col_cnt <= 0;
            row_cnt <= 0;

            window_valid <= 1'b0;

            p00 <= 0;
            p01 <= 0;
            p02 <= 0;

            p10 <= 0;
            p11 <= 0;
            p12 <= 0;

            p20 <= 0;
            p21 <= 0;
            p22 <= 0;


            for (
                i = 0;
                i < IMG_WIDTH;
                i = i + 1
            ) begin

                line0[i] <= 0;
                line1[i] <= 0;

            end

        end

        else if (ce) begin

            if (pixel_valid) begin

                // =================================================
                // Row memories
                //
                // line0 = previous row
                // line1 = row before previous
                // =================================================

                line1[col_cnt] <=
                    line0[col_cnt];

                line0[col_cnt] <=
                    pixel_in;


                // =================================================
                // First column
                // =================================================

                if (col_cnt == 0) begin

                    p00 <= 0;
                    p01 <= 0;

                    if (row_cnt >= 2)
                        p02 <= line1[col_cnt];
                    else
                        p02 <= 0;


                    p10 <= 0;
                    p11 <= 0;

                    if (row_cnt >= 1)
                        p12 <= line0[col_cnt];
                    else
                        p12 <= 0;


                    p20 <= 0;
                    p21 <= 0;
                    p22 <= pixel_in;

                end


                // =================================================
                // Second column
                // =================================================

                else if (col_cnt == 1) begin

                    p00 <= 0;
                    p01 <= p02;

                    if (row_cnt >= 2)
                        p02 <= line1[col_cnt];
                    else
                        p02 <= 0;


                    p10 <= 0;
                    p11 <= p12;

                    if (row_cnt >= 1)
                        p12 <= line0[col_cnt];
                    else
                        p12 <= 0;


                    p20 <= 0;
                    p21 <= p22;
                    p22 <= pixel_in;

                end


                // =================================================
                // Normal columns
                // =================================================

                else begin

                    p00 <= p01;
                    p01 <= p02;

                    if (row_cnt >= 2)
                        p02 <= line1[col_cnt];
                    else
                        p02 <= 0;


                    p10 <= p11;
                    p11 <= p12;

                    if (row_cnt >= 1)
                        p12 <= line0[col_cnt];
                    else
                        p12 <= 0;


                    p20 <= p21;
                    p21 <= p22;
                    p22 <= pixel_in;

                end


                // =================================================
                // Every accepted input pixel produces one window.
                //
                // Missing border samples are zero padded.
                // =================================================

                window_valid <=
                    1'b1;


                // =================================================
                // Coordinates
                // =================================================

                if (col_cnt == IMG_WIDTH-1) begin

                    col_cnt <= 0;

                    if (row_cnt == IMG_HEIGHT-1)
                        row_cnt <= 0;
                    else
                        row_cnt <=
                            row_cnt + 1'b1;

                end

                else begin

                    col_cnt <=
                        col_cnt + 1'b1;

                end

            end

            else begin

                window_valid <=
                    1'b0;

            end

        end

    end

endmodule