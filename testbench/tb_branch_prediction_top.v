// =============================================================================
// Testbench : tb_branch_prediction_top
// Test 12   : Top-level integration of the complete prediction unit.
//
// Three instances of branch_prediction_top (PREDICTOR_TYPE = 0, 1, 2) receive
// the SAME branch stream. Each instance sits inside a pipe_harness that
// models the timing of a hypothetical 5-stage pipeline:
//
//     cycle c : IF  looks up branch k          (if_valid, if_pc)
//     cycle c+2: EX resolves branch k          (ex_valid, ex_* inputs)
//
// so a lookup can see a predictor entry that is still waiting for an older
// in-flight update of the same branch (realistic "stale" prediction).
// When the DUT raises flush, the harness squashes the two younger in-flight
// lookups and restarts fetch at the branch after the resolved one; this
// costs 2 bubble cycles, exactly like a branch resolved in EX.
//
// Every cycle each harness compares ALL DUT outputs against its own
// behavioural reference model (plain arrays, independent of the RTL):
//   pred_taken, pred_state, pred_target_valid, pred_target, pred_redirect,
//   pred_next_pc, ex_dir_mispredict, ex_mispredict, flush, ex_correct_pc.
// It also checks cycles == branches + 2 + 2 * flushes (minus 2 if the very
// last branch flushes, because nothing remains to be refetched).
//
// Stimulus: a directed sequence (default) or a trace file:
//     vvp build/tb_branch_prediction_top +TRACE=traces/loop_trace.csv
// =============================================================================
`timescale 1ns/1ps

// -----------------------------------------------------------------------------
// Harness: one DUT + pipeline model + reference model
// -----------------------------------------------------------------------------
module pipe_harness #(
    parameter TYPE        = 2,
    parameter BHT_ENTRIES = 16,
    parameter BTB_ENTRIES = 16
) (
    input wire clk,
    input wire rst,
    input wire go
);
    localparam W = 32;
    localparam BHT_IDX = $clog2(BHT_ENTRIES);
    localparam BTB_IDX = $clog2(BTB_ENTRIES);

    // DUT signals
    reg          if_valid = 0, ex_valid = 0, ex_actual_taken = 0, ex_pred_taken = 0;
    reg  [W-1:0] if_pc = 0, ex_pc = 0, ex_actual_target = 0, ex_pred_next_pc = 0;
    wire         pred_valid, pred_taken, pred_target_valid, pred_redirect;
    wire [W-1:0] pred_target, pred_next_pc, ex_correct_pc;
    wire [1:0]   pred_state;
    wire         ex_dir_mispredict, ex_mispredict, flush;

    branch_prediction_top #(
        .PC_WIDTH(W), .BHT_ENTRIES(BHT_ENTRIES), .BTB_ENTRIES(BTB_ENTRIES),
        .PREDICTOR_TYPE(TYPE)
    ) dut (
        .clk(clk), .rst(rst),
        .if_valid(if_valid), .if_pc(if_pc),
        .pred_valid(pred_valid), .pred_taken(pred_taken),
        .pred_target_valid(pred_target_valid), .pred_target(pred_target),
        .pred_redirect(pred_redirect), .pred_next_pc(pred_next_pc),
        .pred_state(pred_state),
        .ex_valid(ex_valid), .ex_pc(ex_pc),
        .ex_actual_taken(ex_actual_taken), .ex_actual_target(ex_actual_target),
        .ex_pred_taken(ex_pred_taken), .ex_pred_next_pc(ex_pred_next_pc),
        .ex_dir_mispredict(ex_dir_mispredict), .ex_mispredict(ex_mispredict),
        .flush(flush), .ex_correct_pc(ex_correct_pc)
    );

    // ---------------- reference model state ----------------
    reg  [1:0]   ref_ctr   [0:BHT_ENTRIES-1];
    reg          ref_valid [0:BTB_ENTRIES-1];
    reg  [W-1:0] ref_tagpc [0:BTB_ENTRIES-1];   // full PC stored = tag check
    reg  [W-1:0] ref_tgt   [0:BTB_ENTRIES-1];

    // ---------------- pipeline model state ----------------
    // slot1 = IF/ID register, slot2 = ID/EX register
    reg          v1, v2, pt1, pt2;
    reg  [W-1:0] pn1, pn2;
    integer      i1, i2, fetch_idx;

    integer checks = 0, errors = 0, cycles = 0, flushes = 0, dir_mp = 0, resolved = 0;
    reg     last_flushed = 0;   // final branch flushed -> nothing left to refetch
    reg     done = 0;

    integer k, bi, ti;
    reg          r_pred, r_hit, r_redirect, r_dir, r_mp;
    reg  [1:0]   r_state;
    reg  [W-1:0] r_tgt, r_npc, r_actual_npc;

    function [1:0] ctr_init; input dummy; begin
        ctr_init = (TYPE == 2) ? 2'b01 : 2'b00; end endfunction

    function [1:0] ctr_next(input [1:0] c, input t);
        begin
            if (TYPE == 1)      ctr_next = {1'b0, t};
            else if (TYPE == 2) ctr_next = t ? ((c == 2'b11) ? 2'b11 : c + 1'b1)
                                             : ((c == 2'b00) ? 2'b00 : c - 1'b1);
            else                ctr_next = 2'b00;
        end
    endfunction

    task check(input cond, input [8*24-1:0] what);
        begin
            checks = checks + 1;
            if (!cond) begin
                errors = errors + 1;
                if (errors <= 20)
                    $display("  FAIL type=%0d cycle=%0d [%0s] if_pc=%h ex_pc=%h", TYPE, cycles, what, if_pc, ex_pc);
            end
        end
    endtask

    task ref_reset;
        begin
            for (k = 0; k < BHT_ENTRIES; k = k + 1) ref_ctr[k] = ctr_init(0);
            for (k = 0; k < BTB_ENTRIES; k = k + 1) begin
                ref_valid[k] = 0; ref_tagpc[k] = 0; ref_tgt[k] = 0;
            end
        end
    endtask

    initial begin
        ref_reset;
        v1 = 0; v2 = 0; pt1 = 0; pt2 = 0; pn1 = 0; pn2 = 0; i1 = 0; i2 = 0;
        fetch_idx = 0;
        wait (go === 1'b1);
        while (fetch_idx < tb_branch_prediction_top.n || v1 || v2) begin
            @(negedge clk);
            // ---- drive EX (oldest in-flight branch) ----
            ex_valid         = v2;
            ex_pc            = tb_branch_prediction_top.s_pc[i2];
            ex_actual_taken  = tb_branch_prediction_top.s_taken[i2];
            ex_actual_target = tb_branch_prediction_top.s_tgt[i2];
            ex_pred_taken    = pt2;
            ex_pred_next_pc  = pn2;
            // ---- drive IF (next branch on the correct path) ----
            if_valid = (fetch_idx < tb_branch_prediction_top.n);
            if_pc    = if_valid ? tb_branch_prediction_top.s_pc[fetch_idx] : 0;
            #1;

            // ---- reference: IF prediction (state BEFORE this cycle's update) ----
            bi = (if_pc >> 2) % BHT_ENTRIES;
            ti = (if_pc >> 2) % BTB_ENTRIES;
            r_state    = (TYPE == 0) ? 2'b00 : ref_ctr[bi];
            r_pred     = (TYPE == 2) ? r_state[1] : r_state[0];
            r_hit      = ref_valid[ti] && (ref_tagpc[ti] == if_pc);
            r_tgt      = ref_tgt[ti];
            r_redirect = if_valid && r_pred && r_hit;
            r_npc      = r_redirect ? r_tgt : if_pc + 4;
            check(pred_valid    === if_valid,   "pred_valid");
            check(pred_taken    === r_pred,     "pred_taken");
            check(pred_state    === r_state,    "pred_state");
            check(pred_target_valid === r_hit,  "pred_target_valid");
            if (r_hit) check(pred_target === r_tgt, "pred_target");
            check(pred_redirect === r_redirect, "pred_redirect");
            check(pred_next_pc  === r_npc,      "pred_next_pc");

            // ---- reference: EX resolution ----
            r_actual_npc = ex_actual_taken ? ex_actual_target : ex_pc + 4;
            r_dir = v2 && (pt2 != ex_actual_taken);
            r_mp  = v2 && (pn2 != r_actual_npc);
            check(ex_dir_mispredict === r_dir, "ex_dir_mispredict");
            check(ex_mispredict     === r_mp,  "ex_mispredict");
            check(flush             === r_mp,  "flush");
            if (v2) check(ex_correct_pc === r_actual_npc, "ex_correct_pc");

            if (v2) begin
                resolved = resolved + 1;
                if (r_dir) dir_mp = dir_mp + 1;
                if (r_mp)  flushes = flushes + 1;
                last_flushed = r_mp;
                // reference update (mirrors the rising clock edge)
                bi = (ex_pc >> 2) % BHT_ENTRIES;
                ti = (ex_pc >> 2) % BTB_ENTRIES;
                ref_ctr[bi] = ctr_next(ref_ctr[bi], ex_actual_taken);
                if (ex_actual_taken) begin
                    ref_valid[ti] = 1; ref_tagpc[ti] = ex_pc; ref_tgt[ti] = ex_actual_target;
                end
            end

            // ---- advance pipeline model (use DUT's flush) ----
            if (flush) begin
                // squash IF/ID and the lookup made this cycle; refetch
                v1 = 0; v2 = 0;
                fetch_idx = i2 + 1;
            end else begin
                v2 = v1; i2 = i1; pt2 = pt1; pn2 = pn1;
                v1 = if_valid; i1 = fetch_idx; pt1 = pred_taken; pn1 = pred_next_pc;
                if (if_valid) fetch_idx = fetch_idx + 1;
            end
            cycles = cycles + 1;
        end
        @(negedge clk);
        if_valid = 0; ex_valid = 0;
        check(resolved == tb_branch_prediction_top.n, "all branches resolved");
        // no flush: last branch resolves 2 cycles after its fetch (cycle n+2);
        // every flush adds 2 bubble cycles, except a flush of the final branch
        check(cycles == tb_branch_prediction_top.n + 2 + 2 * (flushes - last_flushed), "cycle count model");
        done = 1;
    end
endmodule

// -----------------------------------------------------------------------------
// Top-level testbench
// -----------------------------------------------------------------------------
module tb_branch_prediction_top;

    localparam MAX_BR = 4096;

    reg clk = 1'b0;
    reg rst = 1'b1;
    reg go  = 1'b0;
    always #5 clk = ~clk;

    // Shared branch stream (read by the harnesses hierarchically)
    reg [31:0] s_pc    [0:MAX_BR-1];
    reg [31:0] s_tgt   [0:MAX_BR-1];
    reg        s_taken [0:MAX_BR-1];
    integer    n = 0;

    pipe_harness #(.TYPE(0)) h_static (.clk(clk), .rst(rst), .go(go));
    pipe_harness #(.TYPE(1)) h_one    (.clk(clk), .rst(rst), .go(go));
    pipe_harness #(.TYPE(2)) h_two    (.clk(clk), .rst(rst), .go(go));

    // ---------------- stimulus helpers ----------------
    task add(input [31:0] pc, input [31:0] tgt, input t);
        begin s_pc[n] = pc; s_tgt[n] = tgt; s_taken[n] = t; n = n + 1; end
    endtask

    integer fd, r, o, i, tk, total_errors, total_checks;
    reg [31:0] f_pc, f_tgt;
    reg [8*256-1:0] trace_name, line;

    initial begin
        if ($value$plusargs("TRACE=%s", trace_name)) begin
            fd = $fopen(trace_name, "r");
            if (fd == 0) begin $display("ERROR: cannot open %0s", trace_name); $finish; end
            r = $fgets(line, fd);                       // skip CSV header
            while (!$feof(fd) && n < MAX_BR) begin
                r = $fscanf(fd, "%h,%h,%d,", f_pc, f_tgt, tk);
                if (r == 3) begin
                    add(f_pc, f_tgt, tk[0]);
                    r = $fgets(line, fd);               // rest of line (instr)
                end else
                    r = $fgets(line, fd);
            end
            $fclose(fd);
            $display("=== Test 12 (trace mode): %0s, %0d branches ===", trace_name, n);
        end else begin
            $dumpfile("simulation/waveforms/tb_branch_prediction_top.vcd");
            $dumpvars(0, tb_branch_prediction_top);
            // Directed stimulus: nested loop (inner TTTTTN x3)
            for (o = 0; o < 3; o = o + 1) begin
                for (i = 0; i < 6; i = i + 1) add(32'h0000_010c, 32'h0000_0104, i < 5);
                add(32'h0000_0114, 32'h0000_0100, o < 2);
            end
            // Alternating forward branch
            for (i = 0; i < 8; i = i + 1) add(32'h0000_0200, 32'h0000_0220, (i % 2) == 0);
            // BTB conflict: 0x14c shares BTB/BHT index 3 with 0x10c (tag differs)
            for (i = 0; i < 4; i = i + 1) begin
                add(32'h0000_014c, 32'h0000_0180, 1);
                add(32'h0000_010c, 32'h0000_0104, 1);
            end
            // Same branch, target changes (exercises wrong-target flush)
            add(32'h0000_0300, 32'h0000_0340, 1);
            add(32'h0000_0300, 32'h0000_0340, 1);
            add(32'h0000_0300, 32'h0000_0340, 1);
            add(32'h0000_0300, 32'h0000_0380, 1);
            add(32'h0000_0300, 32'h0000_0380, 1);
            $display("=== Test 12: top-level integration, %0d directed branches ===", n);
        end

        repeat (2) @(negedge clk);
        rst = 1'b0;
        go  = 1'b1;
        wait (h_static.done && h_one.done && h_two.done);

        $display("PIPE_SUMMARY type=static branches=%0d cycles=%0d dir_mispredicts=%0d flushes=%0d",
                 n, h_static.cycles, h_static.dir_mp, h_static.flushes);
        $display("PIPE_SUMMARY type=one_bit branches=%0d cycles=%0d dir_mispredicts=%0d flushes=%0d",
                 n, h_one.cycles, h_one.dir_mp, h_one.flushes);
        $display("PIPE_SUMMARY type=two_bit branches=%0d cycles=%0d dir_mispredicts=%0d flushes=%0d",
                 n, h_two.cycles, h_two.dir_mp, h_two.flushes);

        // ---- reset check: everything back to the reset state ----
        @(negedge clk); rst = 1'b1; @(negedge clk); rst = 1'b0;
        h_static.if_pc = s_pc[0]; h_one.if_pc = s_pc[0]; h_two.if_pc = s_pc[0];
        h_static.if_valid = 1; h_one.if_valid = 1; h_two.if_valid = 1;
        #1;
        h_two.check(h_two.pred_state === 2'b01 && h_two.pred_taken === 1'b0, "2b reset WNT");
        h_one.check(h_one.pred_state === 2'b00 && h_one.pred_taken === 1'b0, "1b reset NT");
        h_static.check(h_static.pred_taken === 1'b0, "static reset NT");
        h_two.check(h_two.pred_target_valid === 1'b0, "BTB invalid after rst");
        h_one.check(h_one.pred_target_valid === 1'b0, "BTB invalid after rst");

        total_errors = h_static.errors + h_one.errors + h_two.errors;
        total_checks = h_static.checks + h_one.checks + h_two.checks;
        $display("TEST_RESULT: %s tb_branch_prediction_top (%0d/%0d checks passed)",
                 (total_errors == 0) ? "PASS" : "FAIL", total_checks - total_errors, total_checks);
        $finish;
    end

    // Watchdog
    initial begin
        #(10 * 20 * MAX_BR);
        $display("TEST_RESULT: FAIL tb_branch_prediction_top (timeout)");
        $finish;
    end
endmodule
