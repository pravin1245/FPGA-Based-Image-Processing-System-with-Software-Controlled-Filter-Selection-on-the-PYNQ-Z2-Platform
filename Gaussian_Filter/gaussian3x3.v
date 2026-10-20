`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 14.07.2026 23:56:35
// Design Name: 
// Module Name: gaussian3x3
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



module gaussian3x3 #(
    parameter integer DATA_WIDTH = 8
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  ce,

    input  wire [DATA_WIDTH-1:0] p00,
    input  wire [DATA_WIDTH-1:0] p01,
    input  wire [DATA_WIDTH-1:0] p02,

    input  wire [DATA_WIDTH-1:0] p10,
    input  wire [DATA_WIDTH-1:0] p11,
    input  wire [DATA_WIDTH-1:0] p12,

    input  wire [DATA_WIDTH-1:0] p20,
    input  wire [DATA_WIDTH-1:0] p21,
    input  wire [DATA_WIDTH-1:0] p22,

    input  wire                  window_valid,

    output reg  [DATA_WIDTH-1:0] gauss_out,
    output reg                   gauss_valid
);

    localparam integer SUM_W = DATA_WIDTH + 2;
    localparam integer ACC_W = DATA_WIDTH + 4;

    wire [SUM_W-1:0] corner_sum;
    wire [SUM_W-1:0] edge_sum;

    wire [ACC_W-1:0] weighted_sum;

    reg  [ACC_W-1:0] accumulator;
    reg              valid_stage1;

    /*
     * Gaussian kernel:
     *
     * 1 2 1
     * 2 4 2   / 16
     * 1 2 1
     */

    assign corner_sum =
          {{2{1'b0}}, p00}
        + {{2{1'b0}}, p02}
        + {{2{1'b0}}, p20}
        + {{2{1'b0}}, p22};

    assign edge_sum =
          {{2{1'b0}}, p01}
        + {{2{1'b0}}, p10}
        + {{2{1'b0}}, p12}
        + {{2{1'b0}}, p21};

    assign weighted_sum =
          {{(ACC_W-SUM_W){1'b0}}, corner_sum}
        + ({{(ACC_W-SUM_W){1'b0}}, edge_sum} << 1)
        + ({{(ACC_W-DATA_WIDTH){1'b0}}, p11} << 2);

    always @(posedge clk) begin
        if (!rst_n) begin
            accumulator <= {ACC_W{1'b0}};
            valid_stage1 <= 1'b0;
        end else if (ce) begin
            valid_stage1 <= window_valid;

            if (window_valid)
                accumulator <= weighted_sum;
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            gauss_out   <= {DATA_WIDTH{1'b0}};
            gauss_valid <= 1'b0;
        end else if (ce) begin
            gauss_valid <= valid_stage1;

            if (valid_stage1)
                gauss_out <= accumulator[DATA_WIDTH+3:4];
        end
    end

endmodule