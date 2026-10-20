`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06.08.2026 23:18:21
// Design Name: 
// Module Name: tb_image_process_ip_top
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

module tb_image_process_ip_top;

    parameter integer IMG_WIDTH      = 256;
    parameter integer IMG_HEIGHT     = 256;
    parameter integer DATA_WIDTH     = 8;
    parameter integer TOTAL_PIXELS   = IMG_WIDTH * IMG_HEIGHT;
    parameter integer TIMEOUT_CYCLES = 3000000;

    // ============================================================
    // Clock and reset
    // ============================================================

    reg aclk;
    reg aresetn;

    // ============================================================
    // AXI4-Stream input
    // ============================================================

    reg  [DATA_WIDTH-1:0] s_axis_tdata;
    reg                   s_axis_tvalid;
    wire                  s_axis_tready;
    reg                   s_axis_tlast;

    // ============================================================
    // AXI4-Stream output
    // ============================================================

    wire [DATA_WIDTH-1:0] m_axis_tdata;
    wire                  m_axis_tvalid;
    reg                   m_axis_tready;
    wire                  m_axis_tlast;

    wire                  done_interrupt;

    // ============================================================
    // Memories
    // ============================================================

    reg [DATA_WIDTH-1:0] input_mem  [0:TOTAL_PIXELS-1];
    reg [DATA_WIDTH-1:0] output_mem [0:TOTAL_PIXELS-1];

    // ============================================================
    // Counters
    // ============================================================

    integer input_count;
    integer output_count;
    integer cycle_count;
    integer error_count;
    integer index;

    integer zero_count;
    integer nonzero_count;
    integer max_value;

    reg simulation_done;

    // ============================================================
    // Stall checking
    // ============================================================

    reg [DATA_WIDTH-1:0] stalled_data;
    reg                  stalled_last;
    reg                  stall_active;

    // ============================================================
    // DUT
    // ============================================================

    image_process_ip_top #(
        .IMG_WIDTH  (IMG_WIDTH),
        .IMG_HEIGHT (IMG_HEIGHT),
        .DATA_WIDTH (DATA_WIDTH)
    ) dut (
        .aclk           (aclk),
        .aresetn        (aresetn),

        .s_axis_tdata   (s_axis_tdata),
        .s_axis_tvalid  (s_axis_tvalid),
        .s_axis_tready  (s_axis_tready),
        .s_axis_tlast   (s_axis_tlast),

        .m_axis_tdata   (m_axis_tdata),
        .m_axis_tvalid  (m_axis_tvalid),
        .m_axis_tready  (m_axis_tready),
        .m_axis_tlast   (m_axis_tlast),

        .done_interrupt (done_interrupt)
    );

    // ============================================================
    // 100 MHz clock
    // ============================================================

    initial begin
        aclk = 1'b0;
    end

    always #5 aclk = ~aclk;

    // ============================================================
    // Load input image
    // ============================================================

    initial begin
        for (index = 0; index < TOTAL_PIXELS; index = index + 1) begin
            input_mem[index]  = {DATA_WIDTH{1'b0}};
            output_mem[index] = {DATA_WIDTH{1'b0}};
        end

        $readmemh("input_image.mem", input_mem);

        $display("============================================");
        $display("Gaussian-Laplacian Testbench");
        $display("Input image loaded");
        $display("Image size  = %0d x %0d", IMG_WIDTH, IMG_HEIGHT);
        $display("Pixel count = %0d", TOTAL_PIXELS);
        $display("First pixel = %02h", input_mem[0]);
        $display("Last pixel  = %02h", input_mem[TOTAL_PIXELS-1]);
        $display("============================================");
    end

    // ============================================================
    // Initialization
    // ============================================================

    initial begin
        aresetn       = 1'b0;

        s_axis_tdata  = {DATA_WIDTH{1'b0}};
        s_axis_tvalid = 1'b0;
        s_axis_tlast  = 1'b0;

        m_axis_tready = 1'b0;

        input_count   = 0;
        output_count  = 0;
        cycle_count   = 0;
        error_count   = 0;

        zero_count    = 0;
        nonzero_count = 0;
        max_value     = 0;

        simulation_done = 1'b0;

        stalled_data = {DATA_WIDTH{1'b0}};
        stalled_last = 1'b0;
        stall_active = 1'b0;

        // Reset
        repeat (10) @(posedge aclk);

        aresetn = 1'b1;

        repeat (5) @(posedge aclk);
    end

    // ============================================================
    // AXI input driver
    //
    // Current pixel remains stable until the DUT accepts it.
    // ============================================================

    always @(*) begin
        s_axis_tdata  = {DATA_WIDTH{1'b0}};
        s_axis_tvalid = 1'b0;
        s_axis_tlast  = 1'b0;

        if (aresetn &&
            !simulation_done &&
            (input_count < TOTAL_PIXELS)) begin

            s_axis_tdata  = input_mem[input_count];
            s_axis_tvalid = 1'b1;

            if (input_count == TOTAL_PIXELS - 1)
                s_axis_tlast = 1'b1;
        end
    end

    // ============================================================
    // Input transfer counter
    // ============================================================

    always @(posedge aclk) begin
        if (!aresetn) begin
            input_count <= 0;
        end
        else if (!simulation_done) begin
            if (s_axis_tvalid && s_axis_tready)
                input_count <= input_count + 1;
        end
    end

    // ============================================================
    // AXI output-ready generation
    //
    // One stalled cycle every 16 clocks.
    // ============================================================

    always @(posedge aclk) begin
        if (!aresetn) begin
            m_axis_tready <= 1'b0;
        end
        else if (!simulation_done) begin

            if ((cycle_count % 16) == 15)
                m_axis_tready <= 1'b0;
            else
                m_axis_tready <= 1'b1;

        end
        else begin
            m_axis_tready <= 1'b0;
        end
    end

    // ============================================================
    // Timeout counter
    // ============================================================

    always @(posedge aclk) begin
        if (!aresetn) begin
            cycle_count <= 0;
        end
        else if (!simulation_done) begin
            cycle_count <= cycle_count + 1;

            if (cycle_count >= TIMEOUT_CYCLES) begin

                $display("============================================");
                $display("TEST FAILED: TIMEOUT");
                $display("Input pixels   = %0d", input_count);
                $display("Output pixels  = %0d", output_count);
                $display("s_axis_tvalid  = %b", s_axis_tvalid);
                $display("s_axis_tready  = %b", s_axis_tready);
                $display("m_axis_tvalid  = %b", m_axis_tvalid);
                $display("m_axis_tready  = %b", m_axis_tready);
                $display("m_axis_tlast   = %b", m_axis_tlast);
                $display("done_interrupt = %b", done_interrupt);
                $display("============================================");

                $finish;
            end
        end
    end

    // ============================================================
    // AXI output stability checker
    //
    // When TVALID = 1 and TREADY = 0,
    // TDATA and TLAST must stay unchanged.
    // ============================================================

    always @(posedge aclk) begin
        if (!aresetn) begin
            stalled_data <= {DATA_WIDTH{1'b0}};
            stalled_last <= 1'b0;
            stall_active <= 1'b0;
        end
        else if (!simulation_done) begin

            if (m_axis_tvalid && !m_axis_tready) begin

                if (!stall_active) begin
                    stalled_data <= m_axis_tdata;
                    stalled_last <= m_axis_tlast;
                    stall_active <= 1'b1;
                end
                else begin

                    if (m_axis_tdata !== stalled_data) begin
                        $display(
                            "ERROR: TDATA changed during stall at %0t",
                            $time
                        );

                        error_count = error_count + 1;
                    end

                    if (m_axis_tlast !== stalled_last) begin
                        $display(
                            "ERROR: TLAST changed during stall at %0t",
                            $time
                        );

                        error_count = error_count + 1;
                    end
                end
            end
            else begin
                stall_active <= 1'b0;
            end
        end
    end

    // ============================================================
    // Output monitor
    // ============================================================

    always @(posedge aclk) begin
        if (!aresetn) begin
            output_count  <= 0;
            zero_count    = 0;
            nonzero_count = 0;
            max_value     = 0;
        end
        else if (!simulation_done) begin

            if (m_axis_tvalid && m_axis_tready) begin

                // Store output pixel
                if (output_count < TOTAL_PIXELS) begin
                    output_mem[output_count] = m_axis_tdata;
                end
                else begin
                    $display(
                        "ERROR: Extra output pixel at time %0t",
                        $time
                    );

                    error_count = error_count + 1;
                end

                // Statistics
                if (m_axis_tdata == {DATA_WIDTH{1'b0}})
                    zero_count = zero_count + 1;
                else
                    nonzero_count = nonzero_count + 1;

                if (m_axis_tdata > max_value)
                    max_value = m_axis_tdata;

                // TLAST check
                if (output_count == TOTAL_PIXELS - 1) begin

                    if (m_axis_tlast !== 1'b1) begin
                        $display(
                            "ERROR: TLAST missing on final pixel"
                        );

                        error_count = error_count + 1;
                    end
                end
                else begin

                    if (m_axis_tlast !== 1'b0) begin
                        $display(
                            "ERROR: Early TLAST at pixel %0d",
                            output_count
                        );

                        error_count = error_count + 1;
                    end
                end

                output_count <= output_count + 1;
            end
        end
    end

    // ============================================================
    // Completion monitor
    // ============================================================

    always @(posedge aclk) begin
        if (!aresetn) begin
            simulation_done <= 1'b0;
        end
        else if (done_interrupt && !simulation_done) begin

            simulation_done <= 1'b1;

            $display("============================================");
            $display("Gaussian-Laplacian processing completed");
            $display("Input pixels   = %0d", input_count);
            $display("Output pixels  = %0d", output_count);
            $display("Zero pixels    = %0d", zero_count);
            $display("Nonzero pixels = %0d", nonzero_count);
            $display("Maximum value  = %0d", max_value);
            $display("Error count    = %0d", error_count);

            if ((input_count  == TOTAL_PIXELS) &&
                (output_count == TOTAL_PIXELS) &&
                (error_count  == 0)) begin

                $display("TEST PASSED");

            end
            else begin

                $display("TEST FAILED");

            end

            $display("Writing laplacian_output.mem...");
            $display("============================================");

            $writememh(
                "laplacian_output.mem",
                output_mem
            );

            #50;
            $finish;
        end
    end

endmodule