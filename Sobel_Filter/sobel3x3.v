`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 14.07.2026 23:57:18
// Design Name: 
// Module Name: sobel3x3
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



module sobel3x3 #(
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

    output reg  [DATA_WIDTH-1:0] sobel_out,
    output reg                   sobel_valid
);

    localparam integer GXY_W = DATA_WIDTH + 4;
    localparam integer MAG_W = GXY_W + 1;

    wire signed [GXY_W-1:0] p00_ext;
    wire signed [GXY_W-1:0] p01_ext;
    wire signed [GXY_W-1:0] p02_ext;

    wire signed [GXY_W-1:0] p10_ext;
    wire signed [GXY_W-1:0] p12_ext;

    wire signed [GXY_W-1:0] p20_ext;
    wire signed [GXY_W-1:0] p21_ext;
    wire signed [GXY_W-1:0] p22_ext;

    wire signed [GXY_W-1:0] gx;
    wire signed [GXY_W-1:0] gy;

    wire [GXY_W-1:0] gx_absolute;
    wire [GXY_W-1:0] gy_absolute;

    reg  [GXY_W-1:0] gx_abs_reg;
    reg  [GXY_W-1:0] gy_abs_reg;
    reg              valid_stage1;

    wire [MAG_W-1:0] magnitude;

    assign p00_ext =
        $signed({{(GXY_W-DATA_WIDTH){1'b0}}, p00});

    assign p01_ext =
        $signed({{(GXY_W-DATA_WIDTH){1'b0}}, p01});

    assign p02_ext =
        $signed({{(GXY_W-DATA_WIDTH){1'b0}}, p02});

    assign p10_ext =
        $signed({{(GXY_W-DATA_WIDTH){1'b0}}, p10});

    assign p12_ext =
        $signed({{(GXY_W-DATA_WIDTH){1'b0}}, p12});

    assign p20_ext =
        $signed({{(GXY_W-DATA_WIDTH){1'b0}}, p20});

    assign p21_ext =
        $signed({{(GXY_W-DATA_WIDTH){1'b0}}, p21});

    assign p22_ext =
        $signed({{(GXY_W-DATA_WIDTH){1'b0}}, p22});

    assign gx =
          p02_ext
        + (p12_ext <<< 1)
        + p22_ext
        - p00_ext
        - (p10_ext <<< 1)
        - p20_ext;

    assign gy =
          p20_ext
        + (p21_ext <<< 1)
        + p22_ext
        - p00_ext
        - (p01_ext <<< 1)
        - p02_ext;

    assign gx_absolute =
        (gx < 0) ? $unsigned(-gx) : $unsigned(gx);

    assign gy_absolute =
        (gy < 0) ? $unsigned(-gy) : $unsigned(gy);

    always @(posedge clk) begin
        if (!rst_n) begin
            gx_abs_reg   <= {GXY_W{1'b0}};
            gy_abs_reg   <= {GXY_W{1'b0}};
            valid_stage1 <= 1'b0;
        end else if (ce) begin
            valid_stage1 <= window_valid;

            if (window_valid) begin
                gx_abs_reg <= gx_absolute;
                gy_abs_reg <= gy_absolute;
            end
        end
    end

    assign magnitude =
        {1'b0, gx_abs_reg} +
        {1'b0, gy_abs_reg};

    always @(posedge clk) begin
        if (!rst_n) begin
            sobel_out   <= {DATA_WIDTH{1'b0}};
            sobel_valid <= 1'b0;
        end else if (ce) begin
            sobel_valid <= valid_stage1;

            if (valid_stage1) begin
                if (|magnitude[MAG_W-1:DATA_WIDTH])
                    sobel_out <= {DATA_WIDTH{1'b1}};
                else
                    sobel_out <= magnitude[DATA_WIDTH-1:0];
            end
        end
    end

endmodule