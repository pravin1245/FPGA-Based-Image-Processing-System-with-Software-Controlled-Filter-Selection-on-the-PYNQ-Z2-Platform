`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10.08.2026 23:06:47
// Design Name: 
// Module Name: tb_axis_output_gate
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

module tb_axis_output_gate;

parameter DATA_WIDTH = 8;

reg                   aclk;
reg                   aresetn;
reg                   enable;

reg  [DATA_WIDTH-1:0] s_axis_tdata;
reg                   s_axis_tvalid;
wire                  s_axis_tready;
reg                   s_axis_tlast;

wire [DATA_WIDTH-1:0] m_axis_tdata;
wire                  m_axis_tvalid;
reg                   m_axis_tready;
wire                  m_axis_tlast;

integer errors;


// ============================================================
// DUT
// ============================================================

axis_output_gate #(
    .DATA_WIDTH(DATA_WIDTH)
)
dut (
    .aclk(aclk),
    .aresetn(aresetn),
    .enable(enable),

    .s_axis_tdata(s_axis_tdata),
    .s_axis_tvalid(s_axis_tvalid),
    .s_axis_tready(s_axis_tready),
    .s_axis_tlast(s_axis_tlast),

    .m_axis_tdata(m_axis_tdata),
    .m_axis_tvalid(m_axis_tvalid),
    .m_axis_tready(m_axis_tready),
    .m_axis_tlast(m_axis_tlast)
);


// ============================================================
// TESTBENCH
// ============================================================

initial begin

    errors = 0;

    aclk = 0;
    aresetn = 1;

    enable = 0;

    s_axis_tdata  = 0;
    s_axis_tvalid = 0;
    s_axis_tlast  = 0;

    m_axis_tready = 0;


    // ========================================================
    // TEST CASE 1
    // Gate disabled
    // Expected:
    // s_axis_tready = 1
    // m_axis_tvalid = 0
    // ========================================================

    #1;

    enable = 0;

    s_axis_tdata  = 8'h11;
    s_axis_tvalid = 1;
    s_axis_tlast  = 0;

    m_axis_tready = 0;

    #1;

    if ((s_axis_tready == 1'b1) &&
        (m_axis_tvalid == 1'b0))

        $display("TEST CASE 1 PASS : Gate Disabled");

    else begin

        $display("TEST CASE 1 FAIL");

        errors = errors + 1;

    end


    // ========================================================
    // TEST CASE 2
    // Gate enabled and receiver ready
    // Expected:
    // DATA passes
    // TVALID passes
    // TREADY passes
    // ========================================================

    enable = 1;

    s_axis_tdata  = 8'h25;
    s_axis_tvalid = 1;
    s_axis_tlast  = 0;

    m_axis_tready = 1;

    #1;

    if ((m_axis_tdata  == 8'h25) &&
        (m_axis_tvalid == 1'b1)  &&
        (s_axis_tready == 1'b1))

        $display("TEST CASE 2 PASS : Normal Transfer");

    else begin

        $display("TEST CASE 2 FAIL");

        errors = errors + 1;

    end


    // ========================================================
    // TEST CASE 3
    // TLAST transfer
    // ========================================================

    s_axis_tdata  = 8'hAA;
    s_axis_tvalid = 1;
    s_axis_tlast  = 1;

    m_axis_tready = 1;

    #1;

    if ((m_axis_tdata == 8'hAA) &&
        (m_axis_tlast == 1'b1))

        $display("TEST CASE 3 PASS : TLAST Transfer");

    else begin

        $display("TEST CASE 3 FAIL");

        errors = errors + 1;

    end


    // ========================================================
    // TEST CASE 4
    // Backpressure
    //
    // Receiver not ready
    // Input must also become not ready
    // ========================================================

    enable = 1;

    s_axis_tdata  = 8'h44;
    s_axis_tvalid = 1;
    s_axis_tlast  = 0;

    m_axis_tready = 0;

    #1;

    if ((s_axis_tready == 1'b0) &&
        (m_axis_tvalid == 1'b1) &&
        (m_axis_tdata  == 8'h44))

        $display("TEST CASE 4 PASS : Backpressure");

    else begin

        $display("TEST CASE 4 FAIL");

        errors = errors + 1;

    end


    // ========================================================
    // TEST CASE 5
    // Disable gate while valid input exists
    //
    // Input must be consumed
    // Output VALID must be blocked
    // ========================================================

    enable = 0;

    s_axis_tdata  = 8'h55;
    s_axis_tvalid = 1;

    m_axis_tready = 0;

    #1;

    if ((s_axis_tready == 1'b1) &&
        (m_axis_tvalid == 1'b0))

        $display("TEST CASE 5 PASS : Output Blocked");

    else begin

        $display("TEST CASE 5 FAIL");

        errors = errors + 1;

    end


    // ========================================================
    // TEST CASE 6
    // Re-enable gate
    // ========================================================

    enable = 1;

    s_axis_tdata  = 8'hF0;
    s_axis_tvalid = 1;
    s_axis_tlast  = 1;

    m_axis_tready = 1;

    #1;

    if ((m_axis_tdata  == 8'hF0) &&
        (m_axis_tvalid == 1'b1) &&
        (m_axis_tlast  == 1'b1) &&
        (s_axis_tready == 1'b1))

        $display("TEST CASE 6 PASS : Gate Re-enabled");

    else begin

        $display("TEST CASE 6 FAIL");

        errors = errors + 1;

    end


    // ========================================================
    // FINAL RESULT
    // ========================================================

    #1;

    $display("");
    $display("========================================");

    if (errors == 0) begin

        $display("ALL TEST CASES PASS");

    end
    else begin

        $display("TESTBENCH FAIL");

        $display(
            "Total Errors = %0d",
            errors
        );

    end

    $display("========================================");

    $finish;

end

endmodule