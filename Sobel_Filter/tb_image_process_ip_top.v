`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.07.2026 00:14:27
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

    // ============================================================
    // Parameters
    // ============================================================

    parameter IMG_WIDTH  = 256;
    parameter IMG_HEIGHT = 256;
    parameter DATA_WIDTH = 8;

    localparam TOTAL_PIXELS   = IMG_WIDTH * IMG_HEIGHT;
    localparam TIMEOUT_CYCLES = 3000000;

    localparam MODE_GAUSSIAN = 1'b0;
    localparam MODE_SOBEL    = 1'b1;

    // Test phases
    localparam TEST_IDLE              = 0;
    localparam TEST_GAUSS_GOLDEN      = 1;
    localparam TEST_GAUSS_BACKPRESS   = 2;
    localparam TEST_GAUSS_BUBBLE      = 3;
    localparam TEST_GAUSS_LONG_STALL  = 4;

    localparam TEST_SOBEL_GOLDEN      = 5;
    localparam TEST_SOBEL_BACKPRESS   = 6;
    localparam TEST_SOBEL_BUBBLE      = 7;
    localparam TEST_SOBEL_LONG_STALL  = 8;

    localparam TEST_RESET_MIDFRAME    = 9;


    // ============================================================
    // Clock / Reset
    // ============================================================

    reg aclk;
    reg aresetn;

    initial
        aclk = 1'b0;

    always #5 aclk = ~aclk;     // 100 MHz


    // ============================================================
    // Filter Selection
    // ============================================================

    reg filter_select;


    // ============================================================
    // AXI4-Stream Input
    // ============================================================

    reg  [DATA_WIDTH-1:0] s_axis_tdata;
    reg                   s_axis_tvalid;
    wire                  s_axis_tready;
    reg                   s_axis_tlast;


    // ============================================================
    // AXI4-Stream Output
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
    )
    dut (
        .aclk           (aclk),
        .aresetn        (aresetn),

        .filter_select  (filter_select),

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
    // Image Memories
    // ============================================================

    reg [DATA_WIDTH-1:0] input_memory
        [0:TOTAL_PIXELS-1];

    reg [DATA_WIDTH-1:0] gaussian_golden
        [0:TOTAL_PIXELS-1];

    reg [DATA_WIDTH-1:0] sobel_golden
        [0:TOTAL_PIXELS-1];


    // ============================================================
    // Counters / Status
    // ============================================================

    integer test_phase;

    integer input_count;
    integer output_count;

    integer error_count;
    integer mismatch_count;

    integer cycle_count;
    integer stall_counter;

    integer random_value;

    integer gaussian_file;
    integer sobel_file;

    integer i;

    reg output_done;
    reg interrupt_seen;


    // ============================================================
    // Apply Reset
    // ============================================================

    task apply_reset;
    begin

        @(negedge aclk);

        aresetn = 1'b0;

        s_axis_tdata  = 0;
        s_axis_tvalid = 1'b0;
        s_axis_tlast  = 1'b0;

        repeat (10)
            @(posedge aclk);

        @(negedge aclk);

        aresetn = 1'b1;

        repeat (5)
            @(posedge aclk);

    end
    endtask


    // ============================================================
    // Clear Status
    // ============================================================

    task clear_status;
    begin

        input_count     = 0;
        output_count    = 0;

        mismatch_count  = 0;

        cycle_count     = 0;
        stall_counter   = 0;

        output_done     = 1'b0;
        interrupt_seen  = 1'b0;

    end
    endtask


    // ============================================================
    // Send Normal Image
    // ============================================================

    task send_image_normal;

        integer index;

    begin

        index = 0;

        @(negedge aclk);

        while (index < TOTAL_PIXELS) begin

            s_axis_tvalid = 1'b1;

            s_axis_tdata =
                input_memory[index];

            s_axis_tlast =
                (index == TOTAL_PIXELS - 1);


            @(posedge aclk);


            if (
                s_axis_tvalid &&
                s_axis_tready
            ) begin

                index = index + 1;

                input_count = index;

            end


            @(negedge aclk);

        end


        s_axis_tvalid = 1'b0;
        s_axis_tlast  = 1'b0;
        s_axis_tdata  = 0;


        $display(
            "[%0t] Input complete: %0d pixels",
            $time,
            input_count
        );

    end
    endtask


    // ============================================================
    // Send Image with Random TVALID Bubbles
    // ============================================================

    task send_image_with_bubbles;

        integer index;

    begin

        index = 0;

        @(negedge aclk);


        while (index < TOTAL_PIXELS) begin

            random_value = $random;


            // Approximately 25% input bubbles
            if (
                (random_value & 32'h00000003)
                == 0
            ) begin

                s_axis_tvalid = 1'b0;

                s_axis_tlast = 1'b0;

            end
            else begin

                s_axis_tvalid = 1'b1;

                s_axis_tdata =
                    input_memory[index];

                s_axis_tlast =
                    (index == TOTAL_PIXELS - 1);

            end


            @(posedge aclk);


            if (
                s_axis_tvalid &&
                s_axis_tready
            ) begin

                index = index + 1;

                input_count = index;

            end


            @(negedge aclk);

        end


        s_axis_tvalid = 1'b0;
        s_axis_tlast  = 1'b0;
        s_axis_tdata  = 0;


        $display(
            "[%0t] Bubble input complete: %0d pixels",
            $time,
            input_count
        );

    end
    endtask


    // ============================================================
    // Send Half Frame then Reset
    // ============================================================

    task send_half_frame;

        integer index;

    begin

        index = 0;

        @(negedge aclk);


        while (
            index < TOTAL_PIXELS / 2
        ) begin

            s_axis_tvalid = 1'b1;

            s_axis_tdata =
                input_memory[index];

            s_axis_tlast = 1'b0;


            @(posedge aclk);


            if (
                s_axis_tvalid &&
                s_axis_tready
            )
                index = index + 1;


            @(negedge aclk);

        end


        s_axis_tvalid = 1'b0;

        s_axis_tlast = 1'b0;


        $display(
            "[%0t] Half frame sent = %0d pixels",
            $time,
            index
        );

    end
    endtask


    // ============================================================
    // Output TREADY Generator
    // ============================================================

    always @(negedge aclk) begin

        if (!aresetn) begin

            m_axis_tready <= 1'b0;

            stall_counter <= 0;

        end
        else begin

            case (test_phase)


                // =================================================
                // Always ready
                // =================================================

                TEST_GAUSS_GOLDEN,
                TEST_GAUSS_BUBBLE,
                TEST_SOBEL_GOLDEN,
                TEST_SOBEL_BUBBLE,
                TEST_RESET_MIDFRAME:
                begin

                    m_axis_tready <= 1'b1;

                end


                // =================================================
                // Random Backpressure
                // =================================================

                TEST_GAUSS_BACKPRESS,
                TEST_SOBEL_BACKPRESS:
                begin

                    random_value = $random;

                    // Approximately 75% ready
                    m_axis_tready <=
                        ((random_value &
                          32'h00000003) != 0);

                end


                // =================================================
                // Long Stall
                //
                // 30 clocks ready
                // 50 clocks stalled
                // =================================================

                TEST_GAUSS_LONG_STALL,
                TEST_SOBEL_LONG_STALL:
                begin

                    stall_counter <=
                        stall_counter + 1;


                    if (
                        stall_counter < 30
                    )
                        m_axis_tready <= 1'b1;

                    else if (
                        stall_counter < 80
                    )
                        m_axis_tready <= 1'b0;

                    else begin

                        stall_counter <= 0;

                        m_axis_tready <= 1'b1;

                    end

                end


                default:
                begin

                    m_axis_tready <= 1'b0;

                end

            endcase

        end

    end


    // ============================================================
    // Output Monitor
    // ============================================================

    always @(posedge aclk) begin

        if (!aresetn) begin

            output_count = 0;

            output_done = 1'b0;

        end
        else if (
            m_axis_tvalid &&
            m_axis_tready
        ) begin


            // =====================================================
            // Protect memory indexes
            // =====================================================

            if (
                output_count >= TOTAL_PIXELS
            ) begin

                $display(
                    "ERROR: Too many output pixels"
                );

                error_count =
                    error_count + 1;

            end


            // =====================================================
            // Gaussian Golden Run
            // =====================================================

            if (
                test_phase ==
                TEST_GAUSS_GOLDEN
            ) begin

                gaussian_golden[
                    output_count
                ] = m_axis_tdata;


                // Generate Gaussian output file
                $fwrite(
                    gaussian_file,
                    "%02X\n",
                    m_axis_tdata
                );

            end


            // =====================================================
            // Sobel Golden Run
            // =====================================================

            if (
                test_phase ==
                TEST_SOBEL_GOLDEN
            ) begin

                sobel_golden[
                    output_count
                ] = m_axis_tdata;


                // Generate Sobel output file
                $fwrite(
                    sobel_file,
                    "%02X\n",
                    m_axis_tdata
                );

            end


            // =====================================================
            // Gaussian Corner-Case Comparison
            // =====================================================

            if (
                test_phase == TEST_GAUSS_BACKPRESS ||
                test_phase == TEST_GAUSS_BUBBLE ||
                test_phase == TEST_GAUSS_LONG_STALL
            ) begin

                if (
                    m_axis_tdata !==
                    gaussian_golden[
                        output_count
                    ]
                ) begin

                    mismatch_count =
                        mismatch_count + 1;

                    error_count =
                        error_count + 1;


                    if (
                        mismatch_count <= 20
                    )
                        $display(
                            "GAUSSIAN MISMATCH pixel=%0d expected=%02h actual=%02h",
                            output_count,
                            gaussian_golden[
                                output_count
                            ],
                            m_axis_tdata
                        );

                end

            end


            // =====================================================
            // Sobel Corner-Case Comparison
            // =====================================================

            if (
                test_phase == TEST_SOBEL_BACKPRESS ||
                test_phase == TEST_SOBEL_BUBBLE ||
                test_phase == TEST_SOBEL_LONG_STALL ||
                test_phase == TEST_RESET_MIDFRAME
            ) begin

                if (
                    m_axis_tdata !==
                    sobel_golden[
                        output_count
                    ]
                ) begin

                    mismatch_count =
                        mismatch_count + 1;

                    error_count =
                        error_count + 1;


                    if (
                        mismatch_count <= 20
                    )
                        $display(
                            "SOBEL MISMATCH pixel=%0d expected=%02h actual=%02h",
                            output_count,
                            sobel_golden[
                                output_count
                            ],
                            m_axis_tdata
                        );

                end

            end


            // =====================================================
            // TLAST Verification
            // =====================================================

            if (
                m_axis_tlast
            ) begin

                if (
                    output_count !=
                    TOTAL_PIXELS - 1
                ) begin

                    $display(
                        "ERROR: Early TLAST at pixel %0d",
                        output_count
                    );

                    error_count =
                        error_count + 1;

                end
                else begin

                    output_done =
                        1'b1;


                    $display(
                        "[%0t] Correct TLAST at pixel %0d",
                        $time,
                        output_count + 1
                    );

                end

            end
            else if (
                output_count ==
                TOTAL_PIXELS - 1
            ) begin

                $display(
                    "ERROR: TLAST missing at final pixel"
                );

                error_count =
                    error_count + 1;

            end


            output_count =
                output_count + 1;

        end

    end


    // ============================================================
    // OUTPUT STABILITY DURING STALL
    // ============================================================

    reg previous_output_stall;

    reg [DATA_WIDTH-1:0]
        previous_output_data;

    reg previous_output_last;


    always @(posedge aclk) begin

        if (!aresetn) begin

            previous_output_stall <=
                1'b0;

            previous_output_data <=
                0;

            previous_output_last <=
                0;

        end
        else begin


            if (
                previous_output_stall
            ) begin


                if (
                    !m_axis_tvalid
                ) begin

                    $display(
                        "ERROR: Output TVALID dropped during stall"
                    );

                    error_count =
                        error_count + 1;

                end


                if (
                    m_axis_tdata !==
                    previous_output_data
                ) begin

                    $display(
                        "ERROR: Output TDATA changed during stall"
                    );

                    error_count =
                        error_count + 1;

                end


                if (
                    m_axis_tlast !==
                    previous_output_last
                ) begin

                    $display(
                        "ERROR: Output TLAST changed during stall"
                    );

                    error_count =
                        error_count + 1;

                end

            end


            previous_output_stall <=
                m_axis_tvalid &&
                !m_axis_tready;


            if (
                m_axis_tvalid &&
                !m_axis_tready
            ) begin

                previous_output_data <=
                    m_axis_tdata;

                previous_output_last <=
                    m_axis_tlast;

            end

        end

    end


    // ============================================================
    // INPUT STABILITY DURING STALL
    // ============================================================

    reg previous_input_stall;

    reg [DATA_WIDTH-1:0]
        previous_input_data;

    reg previous_input_last;


    always @(posedge aclk) begin

        if (!aresetn) begin

            previous_input_stall <=
                1'b0;

            previous_input_data <=
                0;

            previous_input_last <=
                0;

        end
        else begin


            if (
                previous_input_stall
            ) begin


                if (
                    !s_axis_tvalid
                ) begin

                    $display(
                        "ERROR: Input TVALID dropped during stall"
                    );

                    error_count =
                        error_count + 1;

                end


                if (
                    s_axis_tdata !==
                    previous_input_data
                ) begin

                    $display(
                        "ERROR: Input TDATA changed during stall"
                    );

                    error_count =
                        error_count + 1;

                end


                if (
                    s_axis_tlast !==
                    previous_input_last
                ) begin

                    $display(
                        "ERROR: Input TLAST changed during stall"
                    );

                    error_count =
                        error_count + 1;

                end

            end


            previous_input_stall <=
                s_axis_tvalid &&
                !s_axis_tready;


            if (
                s_axis_tvalid &&
                !s_axis_tready
            ) begin

                previous_input_data <=
                    s_axis_tdata;

                previous_input_last <=
                    s_axis_tlast;

            end

        end

    end


    // ============================================================
    // Interrupt Verification
    // ============================================================

    reg previous_final_transfer;


    always @(posedge aclk) begin

        if (!aresetn) begin

            previous_final_transfer <=
                1'b0;

            interrupt_seen <=
                1'b0;

        end
        else begin


            if (
                done_interrupt
            ) begin

                interrupt_seen <=
                    1'b1;


                if (
                    !previous_final_transfer
                ) begin

                    $display(
                        "ERROR: done_interrupt timing incorrect"
                    );

                    error_count =
                        error_count + 1;

                end

            end


            previous_final_transfer <=
                m_axis_tvalid &&
                m_axis_tready &&
                m_axis_tlast;

        end

    end


    // ============================================================
    // Timeout
    // ============================================================

    always @(posedge aclk) begin

        if (!aresetn) begin

            cycle_count <= 0;

        end
        else begin

            cycle_count <=
                cycle_count + 1;


            if (
                cycle_count >
                TIMEOUT_CYCLES
            ) begin

                $display("");
                $display(
                    "ERROR: SIMULATION TIMEOUT"
                );

                $display(
                    "Test phase   = %0d",
                    test_phase
                );

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
    // Check Frame
    // ============================================================

    task check_frame;
    begin


        if (
            input_count !=
            TOTAL_PIXELS
        ) begin

            $display(
                "ERROR: Input count %0d expected %0d",
                input_count,
                TOTAL_PIXELS
            );

            error_count =
                error_count + 1;

        end


        if (
            output_count !=
            TOTAL_PIXELS
        ) begin

            $display(
                "ERROR: Output count %0d expected %0d",
                output_count,
                TOTAL_PIXELS
            );

            error_count =
                error_count + 1;

        end


        if (
            !interrupt_seen
        ) begin

            $display(
                "ERROR: done_interrupt not detected"
            );

            error_count =
                error_count + 1;

        end


        $display(
            "Input pixels  = %0d",
            input_count
        );

        $display(
            "Output pixels = %0d",
            output_count
        );

        $display(
            "Mismatches    = %0d",
            mismatch_count
        );

    end
    endtask


    // ============================================================
    // MAIN
    // ============================================================

    initial begin


        // ========================================================
        // Initialization
        // ========================================================

        aresetn = 1'b0;

        filter_select =
            MODE_GAUSSIAN;

        s_axis_tdata  = 0;
        s_axis_tvalid = 0;
        s_axis_tlast  = 0;

        m_axis_tready = 0;

        test_phase =
            TEST_IDLE;

        input_count     = 0;
        output_count    = 0;

        error_count     = 0;
        mismatch_count  = 0;

        cycle_count     = 0;
        stall_counter   = 0;

        output_done     = 0;
        interrupt_seen  = 0;


        // ========================================================
        // Load Input Image
        // ========================================================

        $readmemh(
            "input_image.mem",
            input_memory
        );


        // ========================================================
        // Open Output Files
        // ========================================================

        gaussian_file =
            $fopen(
                "gaussian_output.mem",
                "w"
            );


        sobel_file =
            $fopen(
                "sobel_output.mem",
                "w"
            );


        if (
            gaussian_file == 0
        ) begin

            $display(
                "ERROR: Cannot open gaussian_output.mem"
            );

            $finish;

        end


        if (
            sobel_file == 0
        ) begin

            $display(
                "ERROR: Cannot open sobel_output.mem"
            );

            $finish;

        end


        $display("");
        $display(
            "=============================================="
        );

        $display(
            "GAUSSIAN + SOBEL COMPLETE CORNER CASE TEST"
        );

        $display(
            "=============================================="
        );

        $display(
            "Image = %0d x %0d",
            IMG_WIDTH,
            IMG_HEIGHT
        );

        $display(
            "Pixels = %0d",
            TOTAL_PIXELS
        );


        // ========================================================
        // TEST 1
        // Gaussian Golden
        // Also generates gaussian_output.mem
        // ========================================================

        $display("");
        $display(
            "TEST 1 : GAUSSIAN GOLDEN"
        );

        filter_select =
            MODE_GAUSSIAN;

        test_phase =
            TEST_GAUSS_GOLDEN;


        clear_status;

        apply_reset;

        send_image_normal;

        wait(output_done);

        repeat(10)
            @(posedge aclk);

        check_frame;


        // ========================================================
        // TEST 2
        // Gaussian Random Backpressure
        // ========================================================

        $display("");
        $display(
            "TEST 2 : GAUSSIAN RANDOM BACKPRESSURE"
        );

        filter_select =
            MODE_GAUSSIAN;

        test_phase =
            TEST_GAUSS_BACKPRESS;


        clear_status;

        apply_reset;

        send_image_normal;

        wait(output_done);

        repeat(10)
            @(posedge aclk);

        check_frame;


        // ========================================================
        // TEST 3
        // Gaussian Input Bubbles
        // ========================================================

        $display("");
        $display(
            "TEST 3 : GAUSSIAN INPUT BUBBLES"
        );

        filter_select =
            MODE_GAUSSIAN;

        test_phase =
            TEST_GAUSS_BUBBLE;


        clear_status;

        apply_reset;

        send_image_with_bubbles;

        wait(output_done);

        repeat(10)
            @(posedge aclk);

        check_frame;


        // ========================================================
        // TEST 4
        // Gaussian Long Output Stall
        // ========================================================

        $display("");
        $display(
            "TEST 4 : GAUSSIAN LONG STALL"
        );

        filter_select =
            MODE_GAUSSIAN;

        test_phase =
            TEST_GAUSS_LONG_STALL;


        clear_status;

        apply_reset;

        send_image_normal;

        wait(output_done);

        repeat(10)
            @(posedge aclk);

        check_frame;


        // ========================================================
        // TEST 5
        // Sobel Golden
        // Also generates sobel_output.mem
        // ========================================================

        $display("");
        $display(
            "TEST 5 : SOBEL GOLDEN"
        );

        filter_select =
            MODE_SOBEL;

        test_phase =
            TEST_SOBEL_GOLDEN;


        clear_status;

        apply_reset;

        send_image_normal;

        wait(output_done);

        repeat(10)
            @(posedge aclk);

        check_frame;


        // ========================================================
        // TEST 6
        // Sobel Random Backpressure
        // ========================================================

        $display("");
        $display(
            "TEST 6 : SOBEL RANDOM BACKPRESSURE"
        );

        filter_select =
            MODE_SOBEL;

        test_phase =
            TEST_SOBEL_BACKPRESS;


        clear_status;

        apply_reset;

        send_image_normal;

        wait(output_done);

        repeat(10)
            @(posedge aclk);

        check_frame;


        // ========================================================
        // TEST 7
        // Sobel Input Bubbles
        // ========================================================

        $display("");
        $display(
            "TEST 7 : SOBEL INPUT BUBBLES"
        );

        filter_select =
            MODE_SOBEL;

        test_phase =
            TEST_SOBEL_BUBBLE;


        clear_status;

        apply_reset;

        send_image_with_bubbles;

        wait(output_done);

        repeat(10)
            @(posedge aclk);

        check_frame;


        // ========================================================
        // TEST 8
        // Sobel Long Output Stall
        // ========================================================

        $display("");
        $display(
            "TEST 8 : SOBEL LONG STALL"
        );

        filter_select =
            MODE_SOBEL;

        test_phase =
            TEST_SOBEL_LONG_STALL;


        clear_status;

        apply_reset;

        send_image_normal;

        wait(output_done);

        repeat(10)
            @(posedge aclk);

        check_frame;


        // ========================================================
        // TEST 9
        // Reset During Sobel Frame
        // ========================================================

        $display("");
        $display(
            "TEST 9 : RESET DURING FRAME"
        );

        filter_select =
            MODE_SOBEL;

        test_phase =
            TEST_RESET_MIDFRAME;


        clear_status;

        apply_reset;


        // Send only half a frame
        send_half_frame;


        // Reset DUT in middle
        apply_reset;


        // Reset counters for new frame
        input_count   = 0;
        output_count  = 0;
        output_done   = 0;
        interrupt_seen = 0;
        mismatch_count = 0;


        // Complete clean frame after reset
        send_image_normal;

        wait(output_done);

        repeat(10)
            @(posedge aclk);

        check_frame;


        // ========================================================
        // Close files
        // ========================================================

        $fclose(
            gaussian_file
        );

        $fclose(
            sobel_file
        );


        // ========================================================
        // FINAL RESULT
        // ========================================================

        $display("");
        $display(
            "=============================================="
        );

        $display(
            "FINAL VERIFICATION RESULT"
        );

        $display(
            "=============================================="
        );


        if (
            error_count == 0
        ) begin

            $display("");
            $display(
                "**********************************************"
            );

            $display(
                "              SIMULATION PASS"
            );

            $display(
                "**********************************************"
            );

            $display(
                "Gaussian golden         : PASS"
            );

            $display(
                "Gaussian backpressure   : PASS"
            );

            $display(
                "Gaussian input bubbles  : PASS"
            );

            $display(
                "Gaussian long stall     : PASS"
            );

            $display(
                "Sobel golden            : PASS"
            );

            $display(
                "Sobel backpressure      : PASS"
            );

            $display(
                "Sobel input bubbles     : PASS"
            );

            $display(
                "Sobel long stall        : PASS"
            );

            $display(
                "Reset during frame      : PASS"
            );

            $display(
                "AXI TDATA stability     : PASS"
            );

            $display(
                "AXI TVALID stability    : PASS"
            );

            $display(
                "AXI TLAST stability     : PASS"
            );

            $display(
                "Pixel count             : PASS"
            );

            $display(
                "done_interrupt          : PASS"
            );

            $display("");
            $display(
                "Generated files:"
            );

            $display(
                "  gaussian_output.mem"
            );

            $display(
                "  sobel_output.mem"
            );

            $display(
                "**********************************************"
            );

        end
        else begin

            $display("");
            $display(
                "**********************************************"
            );

            $display(
                "              SIMULATION FAIL"
            );

            $display(
                "Total errors = %0d",
                error_count
            );

            $display(
                "**********************************************"
            );

        end


        #100;

        $finish;

    end

endmodule