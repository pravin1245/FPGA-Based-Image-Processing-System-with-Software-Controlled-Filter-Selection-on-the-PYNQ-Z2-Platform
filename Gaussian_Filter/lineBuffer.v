`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 14.07.2026 23:55:43
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

    output reg  [DATA_WIDTH-1:0] p00,
    output reg  [DATA_WIDTH-1:0] p01,
    output reg  [DATA_WIDTH-1:0] p02,

    output reg  [DATA_WIDTH-1:0] p10,
    output reg  [DATA_WIDTH-1:0] p11,
    output reg  [DATA_WIDTH-1:0] p12,

    output reg  [DATA_WIDTH-1:0] p20,
    output reg  [DATA_WIDTH-1:0] p21,
    output reg  [DATA_WIDTH-1:0] p22,

    output reg                   window_valid
);

    localparam integer ADDR_W =
        (IMG_WIDTH <= 2) ? 1 : $clog2(IMG_WIDTH);

    reg [DATA_WIDTH-1:0] line0 [0:IMG_WIDTH-1];
    reg [DATA_WIDTH-1:0] line1 [0:IMG_WIDTH-1];

    reg [ADDR_W-1:0] col_cnt;
    reg [31:0]       row_cnt;

    wire [DATA_WIDTH-1:0] previous_row_2;
    wire [DATA_WIDTH-1:0] previous_row_1;

    integer i;

    assign previous_row_2 = line1[col_cnt];
    assign previous_row_1 = line0[col_cnt];

    always @(posedge clk) begin
        if (!rst_n) begin
            col_cnt      <= {ADDR_W{1'b0}};
            row_cnt      <= 32'd0;
            window_valid <= 1'b0;

            p00 <= {DATA_WIDTH{1'b0}};
            p01 <= {DATA_WIDTH{1'b0}};
            p02 <= {DATA_WIDTH{1'b0}};

            p10 <= {DATA_WIDTH{1'b0}};
            p11 <= {DATA_WIDTH{1'b0}};
            p12 <= {DATA_WIDTH{1'b0}};

            p20 <= {DATA_WIDTH{1'b0}};
            p21 <= {DATA_WIDTH{1'b0}};
            p22 <= {DATA_WIDTH{1'b0}};

            for (i = 0; i < IMG_WIDTH; i = i + 1) begin
                line0[i] <= {DATA_WIDTH{1'b0}};
                line1[i] <= {DATA_WIDTH{1'b0}};
            end
        end else if (ce) begin
            /*
             * Valid also advances only when the pipeline advances.
             */
            window_valid <= pixel_valid;

            if (pixel_valid) begin
                line1[col_cnt] <= line0[col_cnt];
                line0[col_cnt] <= pixel_in;

                /*
                 * Clear horizontal history at the first column so
                 * pixels from the previous row cannot enter the
                 * current row's convolution window.
                 */
                if (col_cnt == 0) begin
                    p00 <= {DATA_WIDTH{1'b0}};
                    p01 <= {DATA_WIDTH{1'b0}};
                    p02 <= previous_row_2;

                    p10 <= {DATA_WIDTH{1'b0}};
                    p11 <= {DATA_WIDTH{1'b0}};
                    p12 <= previous_row_1;

                    p20 <= {DATA_WIDTH{1'b0}};
                    p21 <= {DATA_WIDTH{1'b0}};
                    p22 <= pixel_in;
                end else begin
                    p00 <= p01;
                    p01 <= p02;
                    p02 <= previous_row_2;

                    p10 <= p11;
                    p11 <= p12;
                    p12 <= previous_row_1;

                    p20 <= p21;
                    p21 <= p22;
                    p22 <= pixel_in;
                end

                if (col_cnt == IMG_WIDTH - 1) begin
                    col_cnt <= {ADDR_W{1'b0}};

                    if (row_cnt == IMG_HEIGHT - 1)
                        row_cnt <= 32'd0;
                    else
                        row_cnt <= row_cnt + 32'd1;
                end else begin
                    col_cnt <= col_cnt + 1'b1;
                end
            end
        end
        /*
         * When ce = 0, counters, memory, window data and valid
         * all remain unchanged.
         */
    end

endmodule