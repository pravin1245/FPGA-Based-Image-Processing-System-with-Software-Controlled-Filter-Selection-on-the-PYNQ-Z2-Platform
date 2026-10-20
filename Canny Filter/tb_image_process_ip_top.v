`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench: tb_image_process_ip_top
// Updated for fixed pipeline (extra ~4-cycle latency from pipelining fixes).
// Timeout extended.  Output .mem file saved as canny_output.mem.
//////////////////////////////////////////////////////////////////////////////////

module tb_image_process_ip_top;

    // --------------------------------------------------------------------------
    // Parameters
    // --------------------------------------------------------------------------
    parameter integer IMG_WIDTH  = 256;
    parameter integer IMG_HEIGHT = 256;
    parameter integer DATA_WIDTH = 8;
    parameter integer TOTAL_PIX  = IMG_WIDTH * IMG_HEIGHT; // 65536

    // Generous timeout: 2× total pixels × 20 cycles headroom
    parameter integer TIMEOUT_CYCLES = TOTAL_PIX * 40;

    // --------------------------------------------------------------------------
    // DUT signals
    // --------------------------------------------------------------------------
    reg                   aclk    = 0;
    reg                   aresetn = 0;

    reg  [DATA_WIDTH-1:0] s_axis_tdata  = 0;
    reg                   s_axis_tvalid = 0;
    reg                   s_axis_tlast  = 0;
    wire                  s_axis_tready;

    wire [DATA_WIDTH-1:0] m_axis_tdata;
    wire                  m_axis_tvalid;
    reg                   m_axis_tready = 1;
    wire                  m_axis_tlast;
    wire                  done_interrupt;

    // --------------------------------------------------------------------------
    // Clock: 10 ns = 100 MHz
    // --------------------------------------------------------------------------
    always #5 aclk = ~aclk;

    // --------------------------------------------------------------------------
    // DUT instantiation
    // --------------------------------------------------------------------------
    image_process_ip_top #(
        .IMG_WIDTH  (IMG_WIDTH),
        .IMG_HEIGHT (IMG_HEIGHT),
        .DATA_WIDTH (DATA_WIDTH)
    ) dut (
        .aclk           (aclk),
        .aresetn         (aresetn),
        .s_axis_tdata   (s_axis_tdata),
        .s_axis_tvalid  (s_axis_tvalid),
        .s_axis_tready  (s_axis_tready),
        .s_axis_tlast   (s_axis_tlast),
        .m_axis_tdata   (m_axis_tdata),
        .m_axis_tvalid  (m_axis_tvalid),
        .m_axis_tready  (m_axis_tready),
        .m_axis_tlast   (m_axis_tlast),
        .done_interrupt  (done_interrupt)
    );

    // --------------------------------------------------------------------------
    // Input image memory
    // --------------------------------------------------------------------------
    reg [DATA_WIDTH-1:0] input_mem [0:TOTAL_PIX-1];

    // --------------------------------------------------------------------------
    // Output image memory
    // --------------------------------------------------------------------------
    reg [DATA_WIDTH-1:0] output_mem [0:TOTAL_PIX-1];
    integer out_idx = 0;

    // --------------------------------------------------------------------------
    // Read input image
    // --------------------------------------------------------------------------
    initial begin
        $readmemh("input_image.mem", input_mem);
    end

    // --------------------------------------------------------------------------
    // Reset sequence
    // --------------------------------------------------------------------------
    initial begin
        aresetn = 0;
        repeat(10) @(posedge aclk);
        aresetn = 1;
        @(posedge aclk);
    end

    // --------------------------------------------------------------------------
    // Send all pixels via AXI-Stream
    // --------------------------------------------------------------------------
    integer pix_idx;
    initial begin
        s_axis_tvalid = 0;
        s_axis_tlast  = 0;
        // Wait for reset de-assertion + 2 extra cycles
        @(posedge aresetn);
        repeat(2) @(posedge aclk);

        for (pix_idx = 0; pix_idx < TOTAL_PIX; pix_idx = pix_idx + 1) begin
            // Wait for ready (back-pressure support)
            @(posedge aclk);
            while (!s_axis_tready) @(posedge aclk);

            s_axis_tdata  = input_mem[pix_idx];
            s_axis_tvalid = 1;
            s_axis_tlast  = (pix_idx == TOTAL_PIX - 1) ? 1 : 0;
        end
        @(posedge aclk);
        s_axis_tvalid = 0;
        s_axis_tlast  = 0;
    end

    // --------------------------------------------------------------------------
    // Capture output pixels
    // --------------------------------------------------------------------------
    always @(posedge aclk) begin
        if (m_axis_tvalid && m_axis_tready) begin
            output_mem[out_idx] = m_axis_tdata;
            out_idx = out_idx + 1;
        end
    end

    // --------------------------------------------------------------------------
    // Finish: wait for done_interrupt or timeout
    // --------------------------------------------------------------------------
    integer timer = 0;
    initial begin
        wait (aresetn == 1);
        while (!done_interrupt && timer < TIMEOUT_CYCLES) begin
            @(posedge aclk);
            timer = timer + 1;
        end

        if (done_interrupt) begin
            $display("PASS: done_interrupt asserted after %0d cycles.", timer);
            $display("Output pixels captured: %0d", out_idx);
        end
        else begin
            $display("FAIL: Timeout after %0d cycles. Only %0d output pixels received.",
                     timer, out_idx);
        end

        $writememh("canny_output.mem", output_mem);
        $display("Output written to canny_output.mem");
        $finish;
    end

endmodule
