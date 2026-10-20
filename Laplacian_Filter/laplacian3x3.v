`timescale 1ns / 1ps

module laplacian3x3 #(
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

    output reg [DATA_WIDTH-1:0]  laplacian_out,
    output reg                   laplacian_valid
);

    // ============================================================
    // Kernel:
    //
    //       0  -1   0
    //      -1   4  -1
    //       0  -1   0
    //
    // L =
    // 4*p11 - p01 - p10 - p12 - p21
    //
    // Signed result range for 8-bit input:
    //
    // -1020 ... +1020
    //
    // For display:
    //
    // output = L + 128
    //
    // then saturate to:
    //
    // 0 ... 255
    //
    // Therefore:
    //
    // flat region = 128
    // positive edge > 128
    // negative edge < 128
    // ============================================================


    // ============================================================
    // Stage 1
    // ============================================================

    reg [DATA_WIDTH:0] vertical_sum;
    reg [DATA_WIDTH:0] horizontal_sum;

    reg [DATA_WIDTH+1:0] center_x4;

    reg valid_d1;


    // ============================================================
    // Stage 2
    // ============================================================

    reg [DATA_WIDTH+1:0] neighbour_sum;

    reg [DATA_WIDTH+1:0] center_x4_d2;

    reg valid_d2;


    // ============================================================
    // Stage 3
    // ============================================================

    reg signed [DATA_WIDTH+2:0]
        lap_signed;

    reg valid_d3;


    // ============================================================
    // Stage 4
    // ============================================================

    reg signed [DATA_WIDTH+3:0]
        lap_shifted;

    reg valid_d4;


    // ============================================================
    // PIPELINE
    // ============================================================

    always @(posedge clk) begin

        if (!rst_n) begin

            vertical_sum <= 0;
            horizontal_sum <= 0;

            center_x4 <= 0;

            neighbour_sum <= 0;
            center_x4_d2 <= 0;

            lap_signed <= 0;

            lap_shifted <=
                128;

            valid_d1 <= 0;
            valid_d2 <= 0;
            valid_d3 <= 0;
            valid_d4 <= 0;

            laplacian_out <=
                {1'b1,{(DATA_WIDTH-1){1'b0}}};

            laplacian_valid <=
                1'b0;

        end

        else if (ce) begin

            // ====================================================
            // STAGE 1
            //
            // p01 + p21
            // p10 + p12
            // 4*p11
            // ====================================================

            vertical_sum <=
                {1'b0,p01} +
                {1'b0,p21};

            horizontal_sum <=
                {1'b0,p10} +
                {1'b0,p12};


            center_x4 <=
                ({2'b00,p11} << 2);


            valid_d1 <=
                window_valid;


            // ====================================================
            // STAGE 2
            //
            // p01+p10+p12+p21
            // ====================================================

            neighbour_sum <=
                {1'b0,vertical_sum} +
                {1'b0,horizontal_sum};

            center_x4_d2 <=
                center_x4;

            valid_d2 <=
                valid_d1;


            // ====================================================
            // STAGE 3
            //
            // 4*p11 -
            // (p01+p10+p12+p21)
            // ====================================================

            lap_signed <=
                $signed({
                    1'b0,
                    center_x4_d2
                })
                -
                $signed({
                    1'b0,
                    neighbour_sum
                });


            valid_d3 <=
                valid_d2;


            // ====================================================
            // STAGE 4
            //
            // Move zero response to gray = 128.
            // ====================================================

            lap_shifted <=
                $signed(lap_signed)
                +
                128;

            valid_d4 <=
                valid_d3;


            // ====================================================
            // STAGE 5
            //
            // Saturation
            // ====================================================

            if (valid_d4) begin

                if (lap_shifted < 0) begin

                    laplacian_out <=
                        {DATA_WIDTH{1'b0}};

                end

                else if (
                    lap_shifted > 255
                ) begin

                    laplacian_out <=
                        {DATA_WIDTH{1'b1}};

                end

                else begin

                    laplacian_out <=
                        lap_shifted[
                            DATA_WIDTH-1:0
                        ];

                end

            end

            else begin

                laplacian_out <=
                    {1'b1,
                    {(DATA_WIDTH-1){1'b0}}};

            end


            laplacian_valid <=
                valid_d4;

        end

    end

endmodule