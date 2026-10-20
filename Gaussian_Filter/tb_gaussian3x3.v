`timescale 1ns / 1ps

module tb_image_process_ip_top;

    // ============================================================
    // Parameters
    // ============================================================

    parameter IMG_WIDTH  = 256;
    parameter IMG_HEIGHT = 256;
    parameter DATA_WIDTH = 8;

    localparam TOTAL_PIXELS   = IMG_WIDTH * IMG_HEIGHT;
    localparam TIMEOUT_CYCLES = 1000000;


    // ============================================================
    // Clock and Reset
    // ============================================================

    reg aclk;
    reg aresetn;

    initial
        aclk = 1'b0;

    always #5 aclk = ~aclk;     // 100 MHz


    // ============================================================
    // AXI Stream Input
    // ============================================================

    reg  [DATA_WIDTH-1:0] s_axis_tdata;
    reg                   s_axis_tvalid;
    wire                  s_axis_tready;
    reg                   s_axis_tlast;


    // ============================================================
    // AXI Stream Gaussian Output
    // ============================================================

    wire [DATA_WIDTH-1:0] m_axis_tdata;
    wire                  m_axis_tvalid;
    reg                   m_axis_tready;
    wire                  m_axis_tlast;

    wire                  done_interrupt;


    // ============================================================
    // DUT
    // ============================================================

    image_process_ip_top #(
        .IMG_WIDTH  (IMG_WIDTH),
        .IMG_HEIGHT (IMG_HEIGHT),
        .DATA_WIDTH (DATA_WIDTH)
    ) dut (

        .aclk             (aclk),
        .aresetn          (aresetn),

        .s_axis_tdata     (s_axis_tdata),
        .s_axis_tvalid    (s_axis_tvalid),
        .s_axis_tready    (s_axis_tready),
        .s_axis_tlast     (s_axis_tlast),

        .m_axis_tdata     (m_axis_tdata),
        .m_axis_tvalid    (m_axis_tvalid),
        .m_axis_tready    (m_axis_tready),
        .m_axis_tlast     (m_axis_tlast),

        .done_interrupt   (done_interrupt)
    );


    // ============================================================
    // Input Memory
    // ============================================================

    reg [DATA_WIDTH-1:0] input_memory
        [0:TOTAL_PIXELS-1];


    // ============================================================
    // Variables
    // ============================================================

    integer input_count;
    integer output_count;
    integer cycle_count;

    integer output_file;

    reg output_done;
    reg interrupt_seen;


    // ============================================================
    // Reset Task
    // ============================================================

    task apply_reset;
    begin

        aresetn = 1'b0;

        s_axis_tdata  = {DATA_WIDTH{1'b0}};
        s_axis_tvalid = 1'b0;
        s_axis_tlast  = 1'b0;

        m_axis_tready = 1'b0;

        repeat (10)
            @(posedge aclk);

        @(negedge aclk);

        aresetn = 1'b1;

        repeat (5)
            @(posedge aclk);

        m_axis_tready = 1'b1;

    end
    endtask


    // ============================================================
    // Send Complete 256 x 256 Image
    // ============================================================

    task send_complete_image;

        integer index;

    begin

        index = 0;

        @(negedge aclk);

        while (index < TOTAL_PIXELS) begin

            s_axis_tvalid = 1'b1;
            s_axis_tdata  = input_memory[index];

            if (index == TOTAL_PIXELS - 1)
                s_axis_tlast = 1'b1;
            else
                s_axis_tlast = 1'b0;


            @(posedge aclk);


            // AXI transfer occurs only when
            // TVALID and TREADY are both HIGH

            if (s_axis_tvalid && s_axis_tready) begin

                index = index + 1;

                input_count = index;

            end


            @(negedge aclk);

        end


        // Stop AXI input

        s_axis_tvalid = 1'b0;
        s_axis_tlast  = 1'b0;
        s_axis_tdata  = {DATA_WIDTH{1'b0}};


        $display("");
        $display(
            "[%0t] Input transfer complete",
            $time
        );

        $display(
            "Input pixels = %0d",
            input_count
        );

    end
    endtask


    // ============================================================
    // Gaussian Output Monitor
    // ============================================================

    always @(posedge aclk) begin

        if (!aresetn) begin

            output_count = 0;
            output_done  = 1'b0;

        end

        else if (
            m_axis_tvalid &&
            m_axis_tready
        ) begin


            // ----------------------------------------------------
            // Save Gaussian pixel
            // ----------------------------------------------------

            $fwrite(
                output_file,
                "%02X\n",
                m_axis_tdata
            );


            // ----------------------------------------------------
            // Display first few pixels
            // ----------------------------------------------------

            if (output_count < 10) begin

                $display(
                    "Gaussian[%0d] = %02X",
                    output_count,
                    m_axis_tdata
                );

            end


            // ----------------------------------------------------
            // Check TLAST
            // ----------------------------------------------------

            if (m_axis_tlast) begin

                if (
                    output_count ==
                    TOTAL_PIXELS - 1
                ) begin

                    output_done = 1'b1;

                    $display("");
                    $display(
                        "[%0t] Gaussian TLAST received",
                        $time
                    );

                    $display(
                        "Last pixel number = %0d",
                        output_count + 1
                    );

                end

                else begin

                    $display("");
                    $display(
                        "ERROR: TLAST received early"
                    );

                    $display(
                        "TLAST pixel = %0d",
                        output_count + 1
                    );

                end

            end


            // ----------------------------------------------------
            // Missing TLAST check
            // ----------------------------------------------------

            else if (
                output_count ==
                TOTAL_PIXELS - 1
            ) begin

                $display(
                    "ERROR: TLAST missing on final pixel"
                );

            end


            // ----------------------------------------------------
            // Count output pixel
            // ----------------------------------------------------

            output_count =
                output_count + 1;

        end

    end


    // ============================================================
    // Interrupt Monitor
    // ============================================================

    always @(posedge aclk) begin

        if (!aresetn) begin

            interrupt_seen <= 1'b0;

        end

        else if (done_interrupt) begin

            interrupt_seen <= 1'b1;

            $display(
                "[%0t] done_interrupt detected",
                $time
            );

        end

    end


    // ============================================================
    // Timeout Monitor
    // ============================================================

    always @(posedge aclk) begin

        if (!aresetn) begin

            cycle_count = 0;

        end

        else begin

            cycle_count =
                cycle_count + 1;


            if (
                cycle_count >=
                TIMEOUT_CYCLES
            ) begin

                $display("");
                $display("======================================");
                $display("SIMULATION TIMEOUT");
                $display("======================================");

                $display(
                    "Input count  = %0d",
                    input_count
                );

                $display(
                    "Output count = %0d",
                    output_count
                );

                $finish;

            end

        end

    end


    // ============================================================
    // Main Test
    // ============================================================

    initial begin


        // --------------------------------------------------------
        // Initial Values
        // --------------------------------------------------------

        aresetn = 1'b0;

        s_axis_tdata  = 0;
        s_axis_tvalid = 1'b0;
        s_axis_tlast  = 1'b0;

        m_axis_tready = 1'b0;

        input_count   = 0;
        output_count  = 0;
        cycle_count   = 0;

        output_done   = 1'b0;
        interrupt_seen = 1'b0;


        // --------------------------------------------------------
        // Load Input Image
        // --------------------------------------------------------

        $display("");
        $display("Loading input_image.mem...");

        $readmemh(
            "input_image.mem",
            input_memory
        );


        // --------------------------------------------------------
        // Open Output File
        // --------------------------------------------------------

        output_file =
            $fopen(
                "gaussian_output.mem",
                "w"
            );


        if (output_file == 0) begin

            $display(
                "ERROR: Cannot open gaussian_output.mem"
            );

            $finish;

        end


        // --------------------------------------------------------
        // Test Information
        // --------------------------------------------------------

        $display("");
        $display("======================================");
        $display("GAUSSIAN FILTER AXI TEST");
        $display("======================================");

        $display(
            "Image width   = %0d",
            IMG_WIDTH
        );

        $display(
            "Image height  = %0d",
            IMG_HEIGHT
        );

        $display(
            "Total pixels  = %0d",
            TOTAL_PIXELS
        );

        $display("======================================");


        // --------------------------------------------------------
        // Apply Reset
        // --------------------------------------------------------

        apply_reset;


        // --------------------------------------------------------
        // Send Image
        // --------------------------------------------------------

        send_complete_image;


        // --------------------------------------------------------
        // Wait for Gaussian output
        // --------------------------------------------------------

        wait(output_done);


        repeat (10)
            @(posedge aclk);


        // --------------------------------------------------------
        // Close File
        // --------------------------------------------------------

        $fclose(output_file);


        // --------------------------------------------------------
        // Final Verification
        // --------------------------------------------------------

        $display("");
        $display("======================================");
        $display("FINAL VERIFICATION RESULT");
        $display("======================================");

        $display(
            "Input pixels      = %0d",
            input_count
        );

        $display(
            "Gaussian pixels   = %0d",
            output_count
        );

        $display(
            "Interrupt observed = %0d",
            interrupt_seen
        );


        // --------------------------------------------------------
        // PASS / FAIL
        // --------------------------------------------------------

        if (
            input_count  == TOTAL_PIXELS &&
            output_count == TOTAL_PIXELS &&
            interrupt_seen
        ) begin

            $display("");
            $display("**************************************");
            $display("SIMULATION PASS");
            $display("**************************************");

            $display("65536 input pixels transferred");
            $display("65536 Gaussian pixels received");
            $display("TLAST received correctly");
            $display("done_interrupt received");
            $display("gaussian_output.mem created");

        end

        else begin

            $display("");
            $display("**************************************");
            $display("SIMULATION FAIL");
            $display("**************************************");

            if (input_count != TOTAL_PIXELS)
                $display("ERROR: Incorrect input pixel count");

            if (output_count != TOTAL_PIXELS)
                $display("ERROR: Incorrect output pixel count");

            if (!interrupt_seen)
                $display("ERROR: done_interrupt not detected");

        end


        #100;

        $finish;

    end


endmodule