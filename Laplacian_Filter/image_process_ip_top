`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06.08.2026 23:14:55
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




`timescale 1ns / 1ps

module image_process_ip_top #(
    parameter integer IMG_WIDTH  = 256,
    parameter integer IMG_HEIGHT = 256,
    parameter integer DATA_WIDTH = 8
)(
    input  wire                  aclk,
    input  wire                  aresetn,

    input  wire [DATA_WIDTH-1:0] s_axis_tdata,
    input  wire                  s_axis_tvalid,
    output wire                  s_axis_tready,
    input  wire                  s_axis_tlast,

    output wire [DATA_WIDTH-1:0] m_axis_tdata,
    output wire                  m_axis_tvalid,
    input  wire                  m_axis_tready,
    output wire                  m_axis_tlast,

    output reg                   done_interrupt
);

    localparam integer TOTAL_PIXELS = IMG_WIDTH * IMG_HEIGHT;

    localparam integer COUNT_WIDTH =
        (TOTAL_PIXELS <= 2) ? 1 : $clog2(TOTAL_PIXELS);

    wire [DATA_WIDTH-1:0] lap_pixel;
    wire                  lap_valid;

    reg [DATA_WIDTH-1:0] hold_data;
    reg                  hold_valid;

    wire slot_ready;

    assign slot_ready =
        !hold_valid || m_axis_tready;

    assign s_axis_tready = slot_ready;

    wire input_transfer;

    assign input_transfer =
        s_axis_tvalid && s_axis_tready;

    image_processing_top #(
        .IMG_WIDTH  (IMG_WIDTH),
        .IMG_HEIGHT (IMG_HEIGHT),
        .DATA_WIDTH (DATA_WIDTH)
    ) u_image_processing_top (
        .clk                 (aclk),
        .rst_n               (aresetn),
        .ce                  (slot_ready),

        .pixel_in            (s_axis_tdata),
        .pixel_valid         (input_transfer),

        .laplacian_out       (lap_pixel),
        .laplacian_out_valid (lap_valid)
    );

    always @(posedge aclk) begin
        if (!aresetn) begin
            hold_data  <= 0;
            hold_valid <= 1'b0;
        end
        else if (slot_ready) begin
            hold_valid <= lap_valid;

            if (lap_valid)
                hold_data <= lap_pixel;
        end
    end

    assign m_axis_tdata  = hold_data;
    assign m_axis_tvalid = hold_valid;

    wire output_transfer;

    assign output_transfer =
        m_axis_tvalid && m_axis_tready;

    reg [COUNT_WIDTH-1:0] output_count;

    assign m_axis_tlast =
        m_axis_tvalid &&
        (output_count == TOTAL_PIXELS - 1);

    always @(posedge aclk) begin
        if (!aresetn) begin
            output_count   <= 0;
            done_interrupt <= 1'b0;
        end
        else begin
            done_interrupt <= 1'b0;

            if (output_transfer) begin
                if (output_count == TOTAL_PIXELS - 1) begin
                    output_count   <= 0;
                    done_interrupt <= 1'b1;
                end
                else begin
                    output_count <= output_count + 1'b1;
                end
            end
        end
    end

endmodule
