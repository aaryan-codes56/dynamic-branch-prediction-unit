// =============================================================================
// Testbench : tb_trace_runner
// Purpose   : Trace-driven accuracy evaluation (Tests 4, 5, 7, 8 + analysis).
//
// Three branch_prediction_top instances (static, 1-bit, 2-bit) receive the
// SAME trace, one branch per clock cycle:
//     1. drive if_pc = branch PC and sample each predictor's prediction
//        (state BEFORE this branch is learned),
//     2. drive the EX inputs for the same branch with that prediction,
//        sample dir_mispredict / flush,
//     3. rising clock edge -> predictor and BTB learn the outcome.
// This is the "immediate update" model used in textbook accuracy studies
// (each branch sees all older outcomes). The pipelined timing with delayed
// update and squash is exercised separately in tb_branch_prediction_top.
//
// Output: one CSV row per branch (written to +OUT=<file>) containing the
// RTL's predictions and predictor states; analysis/performance_analysis.py
// computes the metrics from this file and cross-checks it against an
// independent Python reference model.
//
// Usage:
//   vvp build/tb_trace_runner +TRACE=traces/loop_trace.csv +OUT=analysis/results/sim_loop_trace.csv
//   (BHT size can be overridden at compile time: -Ptb_trace_runner.BHT_ENTRIES=64)
// =============================================================================
`timescale 1ns/1ps
module tb_trace_runner;

    parameter BHT_ENTRIES = 16;
    parameter BTB_ENTRIES = 16;
    localparam W = 32;

    reg clk = 1'b0;
    reg rst = 1'b1;
    always #5 clk = ~clk;

    // Shared stimulus to all three DUTs
    reg          if_valid = 0, ex_valid = 0, ex_actual_taken = 0;
    reg  [W-1:0] if_pc = 0, ex_pc = 0, ex_actual_target = 0;
    reg          ex_pred_taken_s = 0, ex_pred_taken_1 = 0, ex_pred_taken_2 = 0;
    reg  [W-1:0] ex_npc_s = 0, ex_npc_1 = 0, ex_npc_2 = 0;

    wire         pt_s, pt_1, pt_2, hit_s, hit_1, hit_2;
    wire [1:0]   st_s, st_1, st_2;
    wire [W-1:0] npc_s, npc_1, npc_2;
    wire         dmp_s, dmp_1, dmp_2, fl_s, fl_1, fl_2;
    wire         unused_pv_s, unused_pv_1, unused_pv_2, unused_rd_s, unused_rd_1, unused_rd_2;
    wire         unused_mp_s, unused_mp_1, unused_mp_2;
    wire [W-1:0] unused_tg_s, unused_tg_1, unused_tg_2, unused_cp_s, unused_cp_1, unused_cp_2;

`define DBPU_INST(NAME, TYPE, PT, ST, HIT, NPC, EPT, ENPC, DMP, FL, PV, RD, MP, TG, CP) \
    branch_prediction_top #(.PC_WIDTH(W), .BHT_ENTRIES(BHT_ENTRIES), .BTB_ENTRIES(BTB_ENTRIES), \
                            .PREDICTOR_TYPE(TYPE)) NAME ( \
        .clk(clk), .rst(rst), .if_valid(if_valid), .if_pc(if_pc), \
        .pred_valid(PV), .pred_taken(PT), .pred_target_valid(HIT), .pred_target(TG), \
        .pred_redirect(RD), .pred_next_pc(NPC), .pred_state(ST), \
        .ex_valid(ex_valid), .ex_pc(ex_pc), .ex_actual_taken(ex_actual_taken), \
        .ex_actual_target(ex_actual_target), .ex_pred_taken(EPT), .ex_pred_next_pc(ENPC), \
        .ex_dir_mispredict(DMP), .ex_mispredict(MP), .flush(FL), .ex_correct_pc(CP));

    `DBPU_INST(u_static, 0, pt_s, st_s, hit_s, npc_s, ex_pred_taken_s, ex_npc_s, dmp_s, fl_s, unused_pv_s, unused_rd_s, unused_mp_s, unused_tg_s, unused_cp_s)
    `DBPU_INST(u_one,    1, pt_1, st_1, hit_1, npc_1, ex_pred_taken_1, ex_npc_1, dmp_1, fl_1, unused_pv_1, unused_rd_1, unused_mp_1, unused_tg_1, unused_cp_1)
    `DBPU_INST(u_two,    2, pt_2, st_2, hit_2, npc_2, ex_pred_taken_2, ex_npc_2, dmp_2, fl_2, unused_pv_2, unused_rd_2, unused_mp_2, unused_tg_2, unused_cp_2)

    integer fd_in, fd_out, r, tk, idx;
    integer miss_s = 0, miss_1 = 0, miss_2 = 0, flush_s = 0, flush_1 = 0, flush_2 = 0;
    reg [31:0] f_pc, f_tgt;
    reg [8*256-1:0] trace_name, out_name, line;
    reg dump;

    initial begin
        if (!$value$plusargs("TRACE=%s", trace_name)) begin
            $display("ERROR: usage +TRACE=<trace.csv> +OUT=<log.csv> [+DUMP]");
            $finish;
        end
        if (!$value$plusargs("OUT=%s", out_name)) out_name = "trace_log.csv";
        dump = $test$plusargs("DUMP");
        if (dump) begin
            $dumpfile("simulation/waveforms/tb_trace_runner.vcd");
            $dumpvars(0, tb_trace_runner);
        end

        fd_in = $fopen(trace_name, "r");
        if (fd_in == 0) begin $display("ERROR: cannot open %0s", trace_name); $finish; end
        fd_out = $fopen(out_name, "w");
        if (fd_out == 0) begin $display("ERROR: cannot write %0s", out_name); $finish; end
        $fdisplay(fd_out, "idx,pc,target,actual_taken,static_pred,static_flush,onebit_state,onebit_pred,onebit_flush,twobit_state,twobit_pred,twobit_flush,btb_hit");

        repeat (2) @(negedge clk);
        rst = 1'b0;

        r = $fgets(line, fd_in);               // skip header
        idx = 0;
        while (!$feof(fd_in)) begin
            r = $fscanf(fd_in, "%h,%h,%d,", f_pc, f_tgt, tk);
            if (r == 3) begin
                r = $fgets(line, fd_in);       // consume rest of line
                @(negedge clk);
                // 1. IF lookup
                if_valid = 1'b1; if_pc = f_pc; ex_valid = 1'b0;
                #1;
                // 2. EX resolution of the same branch, carrying each prediction
                ex_valid = 1'b1; ex_pc = f_pc; ex_actual_taken = tk[0]; ex_actual_target = f_tgt;
                ex_pred_taken_s = pt_s; ex_npc_s = npc_s;
                ex_pred_taken_1 = pt_1; ex_npc_1 = npc_1;
                ex_pred_taken_2 = pt_2; ex_npc_2 = npc_2;
                #1;
                $fdisplay(fd_out, "%0d,%h,%h,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
                          idx, f_pc, f_tgt, tk[0], pt_s, fl_s, st_1[0], pt_1, fl_1, st_2, pt_2, fl_2, hit_2);
                miss_s = miss_s + dmp_s; miss_1 = miss_1 + dmp_1; miss_2 = miss_2 + dmp_2;
                flush_s = flush_s + fl_s; flush_1 = flush_1 + fl_1; flush_2 = flush_2 + fl_2;
                idx = idx + 1;
                // 3. rising edge updates predictor + BTB
            end else
                r = $fgets(line, fd_in);
        end
        @(negedge clk); ex_valid = 1'b0; if_valid = 1'b0;
        $fclose(fd_in); $fclose(fd_out);
        $display("TRACE_SUMMARY trace=%0s bht=%0d branches=%0d static_miss=%0d onebit_miss=%0d twobit_miss=%0d static_flush=%0d onebit_flush=%0d twobit_flush=%0d",
                 trace_name, BHT_ENTRIES, idx, miss_s, miss_1, miss_2, flush_s, flush_1, flush_2);
        $finish;
    end
endmodule
