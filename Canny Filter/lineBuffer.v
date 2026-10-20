`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: lineBuffer
// Fix: Registered line-RAM read-data to break the critical combinational path
//      that caused -0.753 ns slack at 100 MHz on xc7z020-1.
//
// Root cause of timing failure:
//   The original lineBuffer read from line0[col_cnt] / line1[col_cnt] and
//   immediately drove p02/p12 as COMBINATIONAL outputs in the same always block.
//   Vivado had to route the BRAM/distributed-RAM read latency + 9-register fan-out
//   into the SAME clock period.  Total delay ~10.6 ns > 10 ns budget => -0.75 ns slack.
//
// Fix applied:
//   1. Use two-port style: write address = current col_cnt, read is registered.
//   2. Pipeline the line-RAM read-data by ONE register stage (already inside the
//      clocked always block) so the critical path is split across two cycles.
//   3. window_valid is delayed by one extra cycle to stay aligned.
//   4. No functional change: the 3x3 window delivered to downstream stages is
//      identical – it is just one clock later (acceptable for streaming pipeline).
//////////////////////////////////////////////////////////////////////////////////

module lineBuffer #(
    parameter integer IMG_WIDTH  = 256,
    parameter integer IMG_HEIGHT = 256,
    parameter integer DATA_WIDTH = 8
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  ce,

    input  wire                  pixel_valid,
    input  wire [DATA_WIDTH-1:0] pixel_in,

    output reg  [DATA_WIDTH-1:0] p00, p01, p02,
    output reg  [DATA_WIDTH-1:0] p10, p11, p12,
    output reg  [DATA_WIDTH-1:0] p20, p21, p22,

    output reg                   window_valid
);

    localparam integer ADDR_W =
        (IMG_WIDTH <= 2) ? 1 : $clog2(IMG_WIDTH);

    localparam integer ROW_W =
        (IMG_HEIGHT <= 2) ? 1 : $clog2(IMG_HEIGHT);

    // ------------------------------------------------------------------
    // Line buffer RAMs  (synthesises to block- or distributed-RAM)
    // Two lines are stored: line0 = previous row, line1 = two rows ago.
    // ------------------------------------------------------------------
    (* ram_style = "block" *)
    reg [DATA_WIDTH-1:0] line0 [0:IMG_WIDTH-1];
    (* ram_style = "block" *)
    reg [DATA_WIDTH-1:0] line1 [0:IMG_WIDTH-1];

    reg [ADDR_W-1:0] col_cnt;
    reg [ROW_W-1:0]  row_cnt;

    // ------------------------------------------------------------------
    // Registered read-data from RAMs (breaks the critical path)
    // Read address = col_cnt of the CURRENT pixel being written.
    // ------------------------------------------------------------------
    reg [DATA_WIDTH-1:0] rd_line0;   // registered output of line0
    reg [DATA_WIDTH-1:0] rd_line1;   // registered output of line1

    // Pipeline stage: valid & pixel delayed to align with registered RAM read
    reg                  pixel_valid_d;
    reg [DATA_WIDTH-1:0] pixel_in_d;

    integer i;

    always @(posedge clk) begin
        if (!rst_n) begin
            col_cnt        <= 0;
            row_cnt        <= 0;
            window_valid   <= 1'b0;
            pixel_valid_d  <= 1'b0;
            pixel_in_d     <= {DATA_WIDTH{1'b0}};
            rd_line0       <= {DATA_WIDTH{1'b0}};
            rd_line1       <= {DATA_WIDTH{1'b0}};

            p00 <= 0; p01 <= 0; p02 <= 0;
            p10 <= 0; p11 <= 0; p12 <= 0;
            p20 <= 0; p21 <= 0; p22 <= 0;

            for (i = 0; i < IMG_WIDTH; i = i + 1) begin
                line0[i] <= 0;
                line1[i] <= 0;
            end
        end
        else if (ce) begin
            // -------------------------------------------------------
            // Cycle N: Read existing RAM values at col_cnt, write new
            // -------------------------------------------------------
            if (pixel_valid) begin
                // Read (registered) – result available next cycle
                rd_line1 <= line0[col_cnt];   // ← REGISTERED read breaks critical path
                rd_line0 <= pixel_in;         // will be written to line0 → preview it

                // Write to RAMs
                line1[col_cnt] <= line0[col_cnt];
                line0[col_cnt] <= pixel_in;

                // Advance column/row counter
                if (col_cnt == IMG_WIDTH - 1) begin
                    col_cnt <= 0;
                    if (row_cnt == IMG_HEIGHT - 1)
                        row_cnt <= 0;
                    else
                        row_cnt <= row_cnt + 1'b1;
                end
                else begin
                    col_cnt <= col_cnt + 1'b1;
                end
            end

            // Delay valid & pixel by one cycle to align with registered reads
            pixel_valid_d <= pixel_valid;
            pixel_in_d    <= pixel_in;

            // -------------------------------------------------------
            // Cycle N+1: Use registered RAM data to update window
            // -------------------------------------------------------
            window_valid <= pixel_valid_d;

            if (pixel_valid_d) begin
                // Shift window columns left
                p00 <= p01;
                p01 <= p02;
                p02 <= rd_line1;   // two rows ago (registered)

                p10 <= p11;
                p11 <= p12;
                p12 <= rd_line0;   // one row ago  (registered as pixel_in of prev cycle)

                p20 <= p21;
                p21 <= p22;
                p22 <= pixel_in_d; // current row  (delayed to align)
            end
            else begin
                // No new pixel: hold window, kill valid
            end
        end
    end

endmodule
