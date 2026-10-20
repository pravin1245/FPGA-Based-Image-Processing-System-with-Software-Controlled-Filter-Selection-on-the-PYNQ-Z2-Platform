`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10.08.2026 23:05:36
// Design Name: 
// Module Name: axis_output_gate
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


module axis_output_gate #
(
    parameter DATA_WIDTH = 8
)
(
    input  wire                  aclk,
    input  wire                  aresetn,
    input  wire                  enable,

    input  wire [DATA_WIDTH-1:0] s_axis_tdata,
    input  wire                  s_axis_tvalid,
    output wire                  s_axis_tready,
    input  wire                  s_axis_tlast,

    output wire [DATA_WIDTH-1:0] m_axis_tdata,
    output wire                  m_axis_tvalid,
    input  wire                  m_axis_tready,
    output wire                  m_axis_tlast
);

assign m_axis_tdata = s_axis_tdata;
assign m_axis_tlast = s_axis_tlast;

assign m_axis_tvalid =
       enable ? s_axis_tvalid : 1'b0;

assign s_axis_tready =
       enable ? m_axis_tready : 1'b1;

endmodule
