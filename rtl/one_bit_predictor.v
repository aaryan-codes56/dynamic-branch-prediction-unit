// =============================================================================
// Module      : one_bit_predictor
// Project     : DBPU - Dynamic Branch Prediction Unit
// Description : Dynamic 1-bit branch predictor.
//
//   Each BHT entry stores ONE bit = the outcome of the most recent execution
//   of the branch(es) mapping to that entry.
//       state 0 -> predict NOT TAKEN
//       state 1 -> predict TAKEN
//   On resolution the entry is overwritten with the actual outcome.
//   Reset state is 0 (not taken), matching the static baseline.
//
//   Weakness: a loop branch that is taken N-1 times and then falls through
//   is mispredicted TWICE per loop execution (once at the exit, and once on
//   the first iteration of the next execution of the loop).
// =============================================================================
`timescale 1ns / 1ps

module one_bit_predictor #(
    parameter PC_WIDTH = 32,
    parameter ENTRIES  = 16
) (
    input  wire                clk,
    input  wire                rst,
    // IF-stage lookup
    input  wire [PC_WIDTH-1:0] lookup_pc,
    output wire                predict_taken,
    output wire [1:0]          lookup_state,  // zero-extended for debug
    // EX-stage update
    input  wire                update_en,
    input  wire [PC_WIDTH-1:0] update_pc,
    input  wire                actual_taken
);

    localparam STATE_BITS = 1;
    localparam [STATE_BITS-1:0] INIT_STATE = 1'b0;   // not taken

    wire [STATE_BITS-1:0] lookup_bit;
    wire [STATE_BITS-1:0] update_bit;
    wire [STATE_BITS-1:0] next_bit;

    branch_history_table #(
        .PC_WIDTH  (PC_WIDTH),
        .ENTRIES   (ENTRIES),
        .STATE_BITS(STATE_BITS),
        .INIT_STATE(INIT_STATE)
    ) u_bht (
        .clk         (clk),
        .rst         (rst),
        .lookup_pc   (lookup_pc),
        .lookup_state(lookup_bit),
        .update_pc   (update_pc),
        .update_state(update_bit),
        .wr_en       (update_en),
        .wr_state    (next_bit)
    );

    // A 1-bit saturating counter == "store the last outcome".
    update_logic #(.STATE_BITS(STATE_BITS)) u_update (
        .current_state(update_bit),
        .actual_taken (actual_taken),
        .next_state   (next_bit)
    );

    // Prediction logic: the stored bit IS the prediction.
    assign predict_taken = lookup_bit[0];
    assign lookup_state  = {1'b0, lookup_bit};

endmodule
