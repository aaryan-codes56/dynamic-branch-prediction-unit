// =============================================================================
// Module      : prediction_control
// Project     : DBPU - Dynamic Branch Prediction Unit
// Description : IF-stage next-PC selection (combinational).
//
//   Combines the DIRECTION prediction (from the selected predictor) with the
//   TARGET prediction (from the BTB) to choose the next fetch address:
//
//       redirect     = if_valid & predict_taken & btb_hit
//       pred_next_pc = redirect ? btb_target : if_pc + 4
//
//   A branch can only be steered to its target when the BTB knows the target
//   (btb_hit). If the direction predictor says "taken" but the BTB misses,
//   fetch falls through to PC + 4; if the branch is actually taken this is
//   caught later as a next-PC misprediction by misprediction_unit.
// =============================================================================
`timescale 1ns / 1ps

module prediction_control #(
    parameter PC_WIDTH = 32
) (
    input  wire                if_valid,       // a lookup is requested
    input  wire [PC_WIDTH-1:0] if_pc,
    input  wire                predict_taken,  // direction predictor output
    input  wire                btb_hit,
    input  wire [PC_WIDTH-1:0] btb_target,

    output wire                pred_valid,     // outputs below are meaningful
    output wire                pred_redirect,  // fetch will jump to target
    output wire [PC_WIDTH-1:0] pred_next_pc
);

    localparam [PC_WIDTH-1:0] INSTR_BYTES = 4; // RV32I/MIPS instruction size

    wire [PC_WIDTH-1:0] fall_through_pc = if_pc + INSTR_BYTES;

    assign pred_valid    = if_valid;
    assign pred_redirect = if_valid & predict_taken & btb_hit;
    assign pred_next_pc  = pred_redirect ? btb_target : fall_through_pc;

endmodule
