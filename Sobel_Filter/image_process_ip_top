`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 14.07.2026 23:53:57
// Design Name: 
// Module Name: image_process_ip_top
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



module image_process_ip_top #(
    parameter integer IMG_WIDTH  = 256,
    parameter integer IMG_HEIGHT = 256,
    parameter integer DATA_WIDTH = 8
)(
    input  wire                  aclk,
    input  wire                  aresetn,

    // ---------------------------------------------------------
    // Filter selection
    // 0 = Gaussian
    // 1 = Sobel
    // Keep constant for the complete frame
    // ---------------------------------------------------------
    input  wire                  filter_select,

    // ---------------------------------------------------------
    // AXI4-Stream input
    // ---------------------------------------------------------
    input  wire [DATA_WIDTH-1:0] s_axis_tdata,
    input  wire                  s_axis_tvalid,
    output wire                  s_axis_tready,
    input  wire                  s_axis_tlast,

    // ---------------------------------------------------------
    // Single AXI4-Stream output
    // ---------------------------------------------------------
    output wire [DATA_WIDTH-1:0] m_axis_tdata,
    output wire                  m_axis_tvalid,
    input  wire                  m_axis_tready,
    output wire                  m_axis_tlast,

    output reg                   done_interrupt
);

    localparam integer TOTAL_PIXELS =
        IMG_WIDTH * IMG_HEIGHT;

    localparam integer COUNT_WIDTH =
        (TOTAL_PIXELS <= 2) ?
        1 : $clog2(TOTAL_PIXELS);


    // =========================================================
    // Processing pipeline signals
    // =========================================================

    wire [DATA_WIDTH-1:0] gaussian_pixel;
    wire                  gaussian_valid;

    wire [DATA_WIDTH-1:0] sobel_pixel;
    wire                  sobel_valid;


    // =========================================================
    // AXI output holding register
    // =========================================================

    reg [DATA_WIDTH-1:0] hold_data;
    reg                  hold_valid;


    // =========================================================
    // AXI backpressure
    // =========================================================

    wire slot_ready;

    assign slot_ready =
        !hold_valid ||
        m_axis_tready;


    // Entire processing pipeline advances only when output
    // register can accept another pixel.

    wire pipeline_ce;

    assign pipeline_ce = slot_ready;


    // Input ready

    assign s_axis_tready = pipeline_ce;


    wire input_transfer;

    assign input_transfer =
        s_axis_tvalid &&
        s_axis_tready;


    // =========================================================
    // Image processing
    // =========================================================

    image_processing_top #(
        .IMG_WIDTH  (IMG_WIDTH),
        .IMG_HEIGHT (IMG_HEIGHT),
        .DATA_WIDTH (DATA_WIDTH)
    )
    u_image_processing_top
    (
        .clk                 (aclk),
        .rst_n               (aresetn),
        .ce                  (pipeline_ce),

        .filter_select       (filter_select),

        .pixel_in            (s_axis_tdata),
        .pixel_valid         (input_transfer),

        .gaussian_out        (gaussian_pixel),
        .gaussian_out_valid  (gaussian_valid),

        .sobel_out           (sobel_pixel),
        .sobel_out_valid     (sobel_valid)
    );


    // =========================================================
    // Select Gaussian or Sobel
    // =========================================================

    wire [DATA_WIDTH-1:0] selected_data;
    wire                  selected_valid;

    assign selected_data =
        (filter_select == 1'b0) ?
        gaussian_pixel :
        sobel_pixel;

    assign selected_valid =
        (filter_select == 1'b0) ?
        gaussian_valid :
        sobel_valid;


    // =========================================================
    // AXI output holding register
    // =========================================================

    always @(posedge aclk) begin

        if (!aresetn) begin

            hold_data  <= {DATA_WIDTH{1'b0}};
            hold_valid <= 1'b0;

        end
        else if (slot_ready) begin

            hold_valid <= selected_valid;

            if (selected_valid)
                hold_data <= selected_data;

        end

    end


    // =========================================================
    // AXI output
    // =========================================================

    assign m_axis_tdata  = hold_data;
    assign m_axis_tvalid = hold_valid;


    wire output_transfer;

    assign output_transfer =
        m_axis_tvalid &&
        m_axis_tready;


    // =========================================================
    // Output pixel counter
    // =========================================================

    reg [COUNT_WIDTH-1:0] output_count;


    // =========================================================
    // TLAST
    // =========================================================

    assign m_axis_tlast =
        m_axis_tvalid &&
        (output_count == TOTAL_PIXELS - 1);


    // =========================================================
    // Counter + interrupt
    // =========================================================

    always @(posedge aclk) begin

        if (!aresetn) begin

            output_count   <= {COUNT_WIDTH{1'b0}};
            done_interrupt <= 1'b0;

        end
        else begin

            done_interrupt <= 1'b0;

            if (output_transfer) begin

                if (output_count == TOTAL_PIXELS - 1) begin

                    output_count <=
                        {COUNT_WIDTH{1'b0}};

                    done_interrupt <= 1'b1;

                end
                else begin

                    output_count <=
                        output_count + 1'b1;

                end

            end

        end

    end


    // s_axis_tlast is accepted but frame length is determined
    // from IMG_WIDTH * IMG_HEIGHT.

endmodule
