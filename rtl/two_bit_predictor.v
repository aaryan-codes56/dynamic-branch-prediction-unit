// =============================================================================
// Module      : two_bit_predictor
// Project     : DBPU - Dynamic Branch Prediction Unit
// Description : Dynamic 2-bit saturating-counter branch predictor.
//
//   Each BHT entry holds a 2-bit saturating counter:
//       2'b00  Strongly Not Taken  -> predict NOT TAKEN
//       2'b01  Weakly   Not Taken  -> predict NOT TAKEN
//       2'b10  Weakly   Taken      -> predict TAKEN
//       2'b11  Strongly Taken      -> predict TAKEN
//   Prediction = MSB of the counter.
//   Update (see update_logic.v): +1 on taken, -1 on not taken, saturating.
//
//   Reset state is a parameter; the default is 2'b01 (Weakly Not Taken):
//   it predicts not taken (same as the baseline) but needs only ONE taken
//   outcome to switch to predicting taken.
//
//   Strength: a single anomalous outcome (e.g. a loop exit) only moves the
//   counter from Strongly Taken to Weakly Taken, so the prediction for the
//   next execution of the loop is still TAKEN.
// =============================================================================
`timescale 1ns / 1ps

module two_bit_predictor #(
    parameter PC_WIDTH = 32,
    parameter ENTRIES  = 16,
    parameter [1:0] INIT_STATE = 2'b01        // Weakly Not Taken
) (
    input  wire                clk,
    input  wire                rst,
    // IF-stage lookup
    input  wire [PC_WIDTH-1:0] lookup_pc,
    output wire                predict_taken,
    output wire [1:0]          lookup_state,
    // EX-stage update
    input  wire                update_en,
    input  wire [PC_WIDTH-1:0] update_pc,
    input  wire                actual_taken
);

    localparam STATE_BITS = 2;

    // Named states (used for documentation / waveform reading)
    localparam [1:0] STRONG_NOT_TAKEN = 2'b00;
    localparam [1:0] WEAK_NOT_TAKEN   = 2'b01;
    localparam [1:0] WEAK_TAKEN       = 2'b10;
    localparam [1:0] STRONG_TAKEN     = 2'b11;

    wire [STATE_BITS-1:0] update_state;
    wire [STATE_BITS-1:0] next_state;

    branch_history_table #(
        .PC_WIDTH  (PC_WIDTH),
        .ENTRIES   (ENTRIES),
        .STATE_BITS(STATE_BITS),
        .INIT_STATE(INIT_STATE)
    ) u_bht (
        .clk         (clk),
        .rst         (rst),
        .lookup_pc   (lookup_pc),
        .lookup_state(lookup_state),
        .update_pc   (update_pc),
        .update_state(update_state),
        .wr_en       (update_en),
        .wr_state    (next_state)
    );

    update_logic #(.STATE_BITS(STATE_BITS)) u_update (
        .current_state(update_state),
        .actual_taken (actual_taken),
        .next_state   (next_state)
    );

    // Prediction logic: MSB = 1 for WEAK_TAKEN / STRONG_TAKEN.
    assign predict_taken = lookup_state[1];

endmodule
