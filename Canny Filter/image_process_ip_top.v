`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: image_process_ip_top  (AXI4-Stream wrapper)
// Status: No timing violations traced to this module.
//         The done_interrupt and output_count logic is purely registered.
// Logic unchanged from original.
//////////////////////////////////////////////////////////////////////////////////

module image_process_ip_top #(
    parameter integer IMG_WIDTH  = 256,
    parameter integer IMG_HEIGHT = 256,
    parameter integer DATA_WIDTH = 8
)(
    input  wire                  aclk,
    input  wire                  aresetn,

    // AXI4-Stream slave
    input  wire [DATA_WIDTH-1:0] s_axis_tdata,
    input  wire                  s_axis_tvalid,
    output wire                  s_axis_tready,
    input  wire                  s_axis_tlast,

    // AXI4-Stream master
    output wire [DATA_WIDTH-1:0] m_axis_tdata,
    output wire                  m_axis_tvalid,
    input  wire                  m_axis_tready,
    output wire                  m_axis_tlast,

    output reg                   done_interrupt
);

    localparam integer TOTAL_PIXELS = IMG_WIDTH * IMG_HEIGHT;
    localparam integer COUNT_WIDTH  =
        (TOTAL_PIXELS <= 2) ? 1 : $clog2(TOTAL_PIXELS);

    wire [DATA_WIDTH-1:0] canny_pixel;
    wire                  canny_valid;

    reg [DATA_WIDTH-1:0] canny_hold_data;
    reg                  canny_hold_valid;

    reg [COUNT_WIDTH-1:0] output_count;

    wire output_slot_ready = (~canny_hold_valid) | m_axis_tready;
    wire input_transfer    = s_axis_tvalid & s_axis_tready;
    wire output_transfer   = canny_hold_valid & m_axis_tready;

    assign s_axis_tready = output_slot_ready;

    image_processing_top #(
        .IMG_WIDTH  (IMG_WIDTH),
        .IMG_HEIGHT (IMG_HEIGHT),
        .DATA_WIDTH (DATA_WIDTH)
    ) u_image_processing_top (
        .clk             (aclk),
        .rst_n           (aresetn),
        .ce              (output_slot_ready),
        .pixel_in        (s_axis_tdata),
        .pixel_valid     (input_transfer),
        .canny_out       (canny_pixel),
        .canny_out_valid (canny_valid)
    );

    // Output holding register
    always @(posedge aclk) begin
        if (!aresetn) begin
            canny_hold_data  <= {DATA_WIDTH{1'b0}};
            canny_hold_valid <= 1'b0;
        end
        else if (output_slot_ready) begin
            canny_hold_valid <= canny_valid;
            if (canny_valid)
                canny_hold_data <= canny_pixel;
        end
    end

    assign m_axis_tdata  = canny_hold_data;
    assign m_axis_tvalid = canny_hold_valid;
    assign m_axis_tlast  = canny_hold_valid &&
                           (output_count == TOTAL_PIXELS - 1);

    // Output pixel counter and done interrupt
    always @(posedge aclk) begin
        if (!aresetn) begin
            output_count   <= {COUNT_WIDTH{1'b0}};
            done_interrupt <= 1'b0;
        end
        else begin
            done_interrupt <= 1'b0;
            if (output_transfer) begin
                if (output_count == TOTAL_PIXELS - 1) begin
                    output_count   <= {COUNT_WIDTH{1'b0}};
                    done_interrupt <= 1'b1;
                end
                else begin
                    output_count <= output_count + 1'b1;
                end
            end
        end
    end

endmodule
