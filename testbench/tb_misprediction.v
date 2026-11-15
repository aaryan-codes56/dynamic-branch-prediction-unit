// =============================================================================
// Testbench : tb_misprediction
// Test 9    : Misprediction detection, flush and correct next-PC selection
//             (misprediction_unit) together with IF-stage next-PC selection
//             (prediction_control).
// Each case lists: inputs -> expected {dir_mispredict, mispredict/flush,
// correct_pc}. Both modules are purely combinational.
// =============================================================================
`timescale 1ns/1ps
module tb_misprediction;

    localparam PC_WIDTH = 32;
    localparam [31:0] PC  = 32'h0000_0100;
    localparam [31:0] TGT = 32'h0000_00c0;   // backward target
    localparam [31:0] FT  = PC + 4;          // fall-through

    // misprediction_unit
    reg                 ex_valid, actual_taken, pred_taken;
    reg  [PC_WIDTH-1:0] ex_pc, actual_target, pred_next_pc;
    wire                dir_mispredict, mispredict, flush;
    wire [PC_WIDTH-1:0] correct_pc;

    misprediction_unit #(.PC_WIDTH(PC_WIDTH)) u_mp (
        .ex_valid(ex_valid), .ex_pc(ex_pc),
        .actual_taken(actual_taken), .actual_target(actual_target),
        .pred_taken(pred_taken), .pred_next_pc(pred_next_pc),
        .dir_mispredict(dir_mispredict), .mispredict(mispredict),
        .flush(flush), .correct_pc(correct_pc)
    );

    // prediction_control
    reg                 if_valid, predict_taken, btb_hit;
    reg  [PC_WIDTH-1:0] if_pc, btb_target;
    wire                pred_valid, pred_redirect;
    wire [PC_WIDTH-1:0] pc_next;

    prediction_control #(.PC_WIDTH(PC_WIDTH)) u_pc (
        .if_valid(if_valid), .if_pc(if_pc),
        .predict_taken(predict_taken), .btb_hit(btb_hit), .btb_target(btb_target),
        .pred_valid(pred_valid), .pred_redirect(pred_redirect), .pred_next_pc(pc_next)
    );

    integer checks = 0, errors = 0;

    task mp_case(input v, input p_t, input [31:0] p_npc, input a_t, input [31:0] a_tgt,
                 input exp_dir, input exp_mp, input [31:0] exp_pc, input [8*48-1:0] what);
        begin
            ex_valid = v; ex_pc = PC; pred_taken = p_t; pred_next_pc = p_npc;
            actual_taken = a_t; actual_target = a_tgt; #1;
            checks = checks + 1;
            if (dir_mispredict !== exp_dir || mispredict !== exp_mp || flush !== exp_mp ||
                (v && correct_pc !== exp_pc)) begin
                errors = errors + 1;
                $display("  FAIL [%0s] dir=%b mp=%b flush=%b cpc=%h | expected dir=%b mp=%b cpc=%h",
                         what, dir_mispredict, mispredict, flush, correct_pc, exp_dir, exp_mp, exp_pc);
            end else
                $display("  ok   [%0s] dir_mp=%b flush=%b correct_pc=%h", what, dir_mispredict, flush, correct_pc);
        end
    endtask

    task pc_case(input v, input p_t, input hit, input [31:0] tgt,
                 input exp_redirect, input [31:0] exp_npc, input [8*48-1:0] what);
        begin
            if_valid = v; if_pc = PC; predict_taken = p_t; btb_hit = hit; btb_target = tgt; #1;
            checks = checks + 1;
            if (pred_valid !== v || pred_redirect !== exp_redirect || pc_next !== exp_npc) begin
                errors = errors + 1;
                $display("  FAIL [%0s] valid=%b redirect=%b next=%h expected redirect=%b next=%h",
                         what, pred_valid, pred_redirect, pc_next, exp_redirect, exp_npc);
            end else
                $display("  ok   [%0s] redirect=%b pred_next_pc=%h", what, pred_redirect, pc_next);
        end
    endtask

    initial begin
        $dumpfile("simulation/waveforms/tb_misprediction.vcd");
        $dumpvars(0, tb_misprediction);
        $display("=== Test 9: prediction control + misprediction detection ===");

        // ---------------- prediction_control (IF) ----------------
        pc_case(1, 0, 0, TGT, 0, FT,  "pred NT, BTB miss -> PC+4");
        pc_case(1, 0, 1, TGT, 0, FT,  "pred NT, BTB hit  -> PC+4");
        pc_case(1, 1, 0, TGT, 0, FT,  "pred T,  BTB miss -> PC+4 (no target)");
        pc_case(1, 1, 1, TGT, 1, TGT, "pred T,  BTB hit  -> redirect to target");
        pc_case(0, 1, 1, TGT, 0, FT,  "if_valid=0 -> no redirect, not valid");

        // ---------------- misprediction_unit (EX) ----------------
        //        valid pT  pred_npc  aT  a_tgt   dir mp  correct_pc
        mp_case(1,    0,  FT,       0,  TGT,    0,  0,  FT,  "pred NT, actual NT: correct");
        mp_case(1,    1,  TGT,      1,  TGT,    0,  0,  TGT, "pred T,  actual T : correct");
        mp_case(1,    0,  FT,       1,  TGT,    1,  1,  TGT, "pred NT, actual T : flush -> target");
        mp_case(1,    1,  TGT,      0,  TGT,    1,  1,  FT,  "pred T,  actual NT: flush -> PC+4");
        mp_case(1,    1,  FT,       1,  TGT,    0,  1,  TGT, "pred T but BTB miss: flush (target)");
        mp_case(1,    1,  32'h0000_0500, 1, TGT, 0, 1,  TGT, "pred T, wrong BTB target: flush");
        mp_case(0,    0,  FT,       1,  TGT,    0,  0,  TGT, "ex_valid=0: no flags");

        $display("TEST_RESULT: %s tb_misprediction (%0d/%0d checks passed)",
                 (errors == 0) ? "PASS" : "FAIL", checks - errors, checks);
        $finish;
    end
endmodule
