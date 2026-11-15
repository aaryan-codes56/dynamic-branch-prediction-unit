// =============================================================================
// Module      : branch_prediction_top
// Project     : DBPU - Dynamic Branch Prediction Unit
// Description : Top level of the Dynamic Branch Prediction Unit.
//
//   This is a STANDALONE prediction unit with a pipeline-style interface. It
//   is NOT a processor: a hypothetical 5-stage pipeline would connect
//     * the IF-stage signals (if_*, pred_*) to its fetch logic, and
//     * the EX-stage signals (ex_*, flush, ex_correct_pc) to its branch
//       resolution logic.
//
//   Internal structure
//     direction predictor  (selected by PREDICTOR_TYPE)
//         0 = static_predictor   (always not taken, baseline)
//         1 = one_bit_predictor  (1-bit BHT)
//         2 = two_bit_predictor  (2-bit saturating-counter BHT)
//     branch_target_buffer  (target prediction)
//     prediction_control    (IF: chooses pred_next_pc)
//     misprediction_unit    (EX: detects misprediction, raises flush)
//
//   Timing: lookup is combinational in the same cycle as if_valid/if_pc.
//   Predictor and BTB state are updated on the rising clock edge of the
//   cycle in which ex_valid = 1. The BTB is written only for TAKEN branches
//   (a not-taken branch needs no target).
// =============================================================================
`timescale 1ns / 1ps

module branch_prediction_top #(
    parameter PC_WIDTH       = 32,
    parameter BHT_ENTRIES    = 16,
    parameter BTB_ENTRIES    = 16,
    parameter PREDICTOR_TYPE = 2     // 0 static, 1 one-bit, 2 two-bit
) (
    input  wire                clk,
    input  wire                rst,               // synchronous, active-high

    // ---------------- IF stage: prediction request / response -------------
    input  wire                if_valid,          // branch lookup this cycle
    input  wire [PC_WIDTH-1:0] if_pc,
    output wire                pred_valid,        // prediction outputs valid
    output wire                pred_taken,        // direction prediction
    output wire                pred_target_valid, // BTB hit
    output wire [PC_WIDTH-1:0] pred_target,       // BTB target
    output wire                pred_redirect,     // fetch jumps to pred_target
    output wire [PC_WIDTH-1:0] pred_next_pc,      // next fetch address
    output wire [1:0]          pred_state,        // predictor state (debug)

    // ---------------- EX stage: branch resolution / update ----------------
    input  wire                ex_valid,          // branch resolves (update en)
    input  wire [PC_WIDTH-1:0] ex_pc,
    input  wire                ex_actual_taken,
    input  wire [PC_WIDTH-1:0] ex_actual_target,
    input  wire                ex_pred_taken,     // prediction carried from IF
    input  wire [PC_WIDTH-1:0] ex_pred_next_pc,   // prediction carried from IF
    output wire                ex_dir_mispredict, // direction was wrong
    output wire                ex_mispredict,     // next PC was wrong
    output wire                flush,             // squash wrong-path instrs
    output wire [PC_WIDTH-1:0] ex_correct_pc      // restart fetch here
);

    localparam TYPE_STATIC  = 0;
    localparam TYPE_ONE_BIT = 1;
    localparam TYPE_TWO_BIT = 2;

    wire btb_hit;
    wire [PC_WIDTH-1:0] btb_target;

    // ------------------------------------------------------------------
    // Direction predictor (chosen at elaboration time)
    // ------------------------------------------------------------------
    generate
        if (PREDICTOR_TYPE == TYPE_STATIC) begin : g_pred
            static_predictor #(.PC_WIDTH(PC_WIDTH)) u_predictor (
                .clk(clk), .rst(rst),
                .lookup_pc(if_pc), .predict_taken(pred_taken),
                .lookup_state(pred_state),
                .update_en(ex_valid), .update_pc(ex_pc),
                .actual_taken(ex_actual_taken)
            );
        end else if (PREDICTOR_TYPE == TYPE_ONE_BIT) begin : g_pred
            one_bit_predictor #(.PC_WIDTH(PC_WIDTH), .ENTRIES(BHT_ENTRIES)) u_predictor (
                .clk(clk), .rst(rst),
                .lookup_pc(if_pc), .predict_taken(pred_taken),
                .lookup_state(pred_state),
                .update_en(ex_valid), .update_pc(ex_pc),
                .actual_taken(ex_actual_taken)
            );
        end else begin : g_pred
            two_bit_predictor #(.PC_WIDTH(PC_WIDTH), .ENTRIES(BHT_ENTRIES)) u_predictor (
                .clk(clk), .rst(rst),
                .lookup_pc(if_pc), .predict_taken(pred_taken),
                .lookup_state(pred_state),
                .update_en(ex_valid), .update_pc(ex_pc),
                .actual_taken(ex_actual_taken)
            );
        end
    endgenerate

    // ------------------------------------------------------------------
    // Branch Target Buffer (written only by taken branches)
    // ------------------------------------------------------------------
    branch_target_buffer #(.PC_WIDTH(PC_WIDTH), .ENTRIES(BTB_ENTRIES)) u_btb (
        .clk(clk), .rst(rst),
        .lookup_pc(if_pc),
        .lookup_hit(btb_hit),
        .lookup_target(btb_target),
        .update_en(ex_valid & ex_actual_taken),
        .update_pc(ex_pc),
        .update_target(ex_actual_target)
    );

    assign pred_target_valid = btb_hit;
    assign pred_target       = btb_target;

    // ------------------------------------------------------------------
    // IF stage: next-PC selection
    // ------------------------------------------------------------------
    prediction_control #(.PC_WIDTH(PC_WIDTH)) u_pred_ctrl (
        .if_valid(if_valid), .if_pc(if_pc),
        .predict_taken(pred_taken),
        .btb_hit(btb_hit), .btb_target(btb_target),
        .pred_valid(pred_valid),
        .pred_redirect(pred_redirect),
        .pred_next_pc(pred_next_pc)
    );

    // ------------------------------------------------------------------
    // EX stage: misprediction detection and flush
    // ------------------------------------------------------------------
    misprediction_unit #(.PC_WIDTH(PC_WIDTH)) u_mispredict (
        .ex_valid(ex_valid), .ex_pc(ex_pc),
        .actual_taken(ex_actual_taken), .actual_target(ex_actual_target),
        .pred_taken(ex_pred_taken), .pred_next_pc(ex_pred_next_pc),
        .dir_mispredict(ex_dir_mispredict),
        .mispredict(ex_mispredict),
        .flush(flush),
        .correct_pc(ex_correct_pc)
    );

endmodule
