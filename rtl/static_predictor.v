// =============================================================================
// Module      : static_predictor
// Project     : DBPU - Dynamic Branch Prediction Unit
// Description : Baseline STATIC "always not taken" predictor.
//
//   It ignores the branch PC and never learns from outcomes: every branch is
//   predicted NOT TAKEN, so the processor simply keeps fetching PC + 4.
//   It has the same port list as the dynamic predictors so that the top level
//   can swap predictors with a single parameter. The update inputs are
//   accepted but intentionally unused (no state, no storage).
// =============================================================================
`timescale 1ns / 1ps

module static_predictor #(
    parameter PC_WIDTH = 32
) (
    input  wire                clk,          // unused (no state)
    input  wire                rst,          // unused (no state)
    input  wire [PC_WIDTH-1:0] lookup_pc,    // unused
    output wire                predict_taken,
    output wire [1:0]          lookup_state, // always 0 (for uniform debug)
    input  wire                update_en,    // unused
    input  wire [PC_WIDTH-1:0] update_pc,    // unused
    input  wire                actual_taken  // unused
);

    localparam PREDICT_NOT_TAKEN = 1'b0;

    assign predict_taken = PREDICT_NOT_TAKEN;
    assign lookup_state  = 2'b00;

endmodule
