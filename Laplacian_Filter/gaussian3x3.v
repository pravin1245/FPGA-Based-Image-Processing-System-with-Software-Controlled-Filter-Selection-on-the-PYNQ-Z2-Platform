`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06.08.2026 23:29:45
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

    output reg [DATA_WIDTH-1:0]  gauss_out,
    output reg                   gauss_valid
);

    // ============================================================
    // Gaussian kernel
    //
    //       1  2  1
    //       2  4  2
    //       1  2  1
    //
    // coefficient sum = 16
    // ============================================================

    localparam integer SUM_WIDTH =
        DATA_WIDTH + 4;


    // ============================================================
    // Pipeline stage 1
    // Pairwise sums
    // ============================================================

    reg [DATA_WIDTH:0] s_corner_0;
    reg [DATA_WIDTH:0] s_corner_1;

    reg [DATA_WIDTH:0] s_edge_0;
    reg [DATA_WIDTH:0] s_edge_1;

    reg [DATA_WIDTH+1:0] center_x4;

    reg valid_d1;


    // ============================================================
    // Pipeline stage 2
    // Weighted partial sums
    // ============================================================

    reg [SUM_WIDTH-1:0] corner_sum;
    reg [SUM_WIDTH-1:0] edge_x2_sum;
    reg [SUM_WIDTH-1:0] center_d2;

    reg valid_d2;


    // ============================================================
    // Pipeline stage 3
    // Final Gaussian sum
    // ============================================================

    reg [SUM_WIDTH:0] final_sum;

    reg valid_d3;


    // ============================================================
    // PIPELINE
    // ============================================================

    always @(posedge clk) begin

        if (!rst_n) begin

            s_corner_0 <= 0;
            s_corner_1 <= 0;

            s_edge_0 <= 0;
            s_edge_1 <= 0;

            center_x4 <= 0;

            corner_sum <= 0;
            edge_x2_sum <= 0;
            center_d2 <= 0;

            final_sum <= 0;

            gauss_out <= 0;

            valid_d1 <= 0;
            valid_d2 <= 0;
            valid_d3 <= 0;

            gauss_valid <= 0;

        end

        else if (ce) begin

            // ====================================================
            // Stage 1
            // ====================================================

            s_corner_0 <=
                {1'b0,p00} +
                {1'b0,p02};

            s_corner_1 <=
                {1'b0,p20} +
                {1'b0,p22};


            s_edge_0 <=
                {1'b0,p01} +
                {1'b0,p21};

            s_edge_1 <=
                {1'b0,p10} +
                {1'b0,p12};


            center_x4 <=
                {2'b00,p11} << 2;


            valid_d1 <=
                window_valid;


            // ====================================================
            // Stage 2
            // ====================================================

            corner_sum <=
                s_corner_0 +
                s_corner_1;

            edge_x2_sum <=
                (s_edge_0 +
                 s_edge_1) << 1;

            center_d2 <=
                center_x4;

            valid_d2 <=
                valid_d1;


            // ====================================================
            // Stage 3
            //
            // +8 implements rounding before /16.
            // ====================================================

            final_sum <=
                corner_sum +
                edge_x2_sum +
                center_d2 +
                8;

            valid_d3 <=
                valid_d2;


            // ====================================================
            // Stage 4
            //
            // divide by 16
            // ====================================================

            if (valid_d3)
                gauss_out <=
                    final_sum >> 4;
            else
                gauss_out <=
                    0;


            gauss_valid <=
                valid_d3;

        end

    end

endmodule