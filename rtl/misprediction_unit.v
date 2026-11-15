// =============================================================================
// Module      : misprediction_unit
// Project     : DBPU - Dynamic Branch Prediction Unit
// Description : EX-stage branch resolution check (combinational).
//
//   When a conditional branch (BEQ/BNE) resolves in EX, the pipeline knows
//   the actual outcome and actual target. The prediction made in IF
//   (pred_taken, pred_next_pc) has travelled down the pipeline with the
//   instruction. This unit compares them:
//
//       actual_next_pc  = actual_taken ? actual_target : pc + 4
//       dir_mispredict  = ex_valid & (pred_taken != actual_taken)
//       mispredict      = ex_valid & (pred_next_pc != actual_next_pc)
//       flush           = mispredict
//       correct_pc      = actual_next_pc
//
//   dir_mispredict measures DIRECTION accuracy (used for the accuracy and
//   CPI tables). mispredict / flush is what a pipeline actually reacts to:
//   it also covers "predicted taken but BTB had no target" and "BTB target
//   was wrong". When flush = 1, the younger wrong-path instructions in IF/ID
//   must be squashed and fetch restarts at correct_pc.
// =============================================================================
`timescale 1ns / 1ps

module misprediction_unit #(
    parameter PC_WIDTH = 32
) (
    input  wire                ex_valid,         // a branch resolves this cycle
    input  wire [PC_WIDTH-1:0] ex_pc,
    input  wire                actual_taken,
    input  wire [PC_WIDTH-1:0] actual_target,
    input  wire                pred_taken,       // carried from IF
    input  wire [PC_WIDTH-1:0] pred_next_pc,     // carried from IF

    output wire                dir_mispredict,
    output wire                mispredict,
    output wire                flush,
    output wire [PC_WIDTH-1:0] correct_pc
);

    localparam [PC_WIDTH-1:0] INSTR_BYTES = 4;

    wire [PC_WIDTH-1:0] actual_next_pc = actual_taken ? actual_target
                                                      : (ex_pc + INSTR_BYTES);

    assign dir_mispredict = ex_valid & (pred_taken != actual_taken);
    assign mispredict     = ex_valid & (pred_next_pc != actual_next_pc);
    assign flush          = mispredict;
    assign correct_pc     = actual_next_pc;

endmodule
