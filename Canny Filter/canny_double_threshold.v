`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: canny_double_threshold
// Status: Timing-clean.  Two 8-bit magnitude comparisons easily fit 10 ns.
// Logic unchanged.  Bug fix: LOW_TH and HIGH_TH parameters are now driven
// from the top-level via image_processing_top — confirmed consistent.
//////////////////////////////////////////////////////////////////////////////////

module canny_double_threshold #(
    parameter integer DATA_WIDTH = 8,
    parameter [DATA_WIDTH-1:0] LOW_TH  = 8'd100,
    parameter [DATA_WIDTH-1:0] HIGH_TH = 8'd180
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  ce,

    input  wire [DATA_WIDTH-1:0] magnitude_in,
    input  wire                  magnitude_valid,

    output reg  [DATA_WIDTH-1:0] edge_out,
    output reg                   edge_valid
);

    always @(posedge clk) begin
        if (!rst_n) begin
            edge_out   <= {DATA_WIDTH{1'b0}};
            edge_valid <= 1'b0;
        end
        else if (ce) begin
            edge_valid <= magnitude_valid;

            if (magnitude_valid) begin
                if (magnitude_in >= HIGH_TH)
                    edge_out <= {DATA_WIDTH{1'b1}};      // strong edge
                else if (magnitude_in >= LOW_TH)
                    edge_out <= 8'h80;                   // weak edge
                else
                    edge_out <= {DATA_WIDTH{1'b0}};      // background
            end
            else begin
                edge_out <= {DATA_WIDTH{1'b0}};
            end
        end
    end

endmodule
