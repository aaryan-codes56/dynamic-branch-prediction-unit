// =============================================================================
// Testbench : tb_two_bit_predictor
// Test 3    : Dynamic 2-bit saturating-counter predictor
//             (plus parts of Tests 4, 5, 6 and 10).
// Checks    : (a) update_logic exhaustively for 1-bit and 2-bit counters,
//             (b) reset state = 01 (Weakly Not Taken) in every entry,
//             (c) complete 8-entry transition table through the real BHT,
//             (d) prediction for all four states,
//             (e) saturation at 11 and 00 (no wrap-around),
//             (f) loop TTTTTN behaviour (1 misprediction per execution),
//             (g) alternating T N T N behaviour (reset 01 mispredicts 12/12;
//                 reset 00 mispredicts 6/12 -- also checked here),
//             (h) independent entries and aliasing,
//             (i) mid-run reset.
// =============================================================================
`timescale 1ns/1ps
module tb_two_bit_predictor;

    localparam PC_WIDTH = 32;
    localparam ENTRIES  = 16;

    localparam [1:0] SNT = 2'b00, WNT = 2'b01, WT = 2'b10, ST = 2'b11;

    localparam [31:0] PC_A     = 32'h0000_0100;  // index 0
    localparam [31:0] PC_B     = 32'h0000_0104;  // index 1
    localparam [31:0] PC_ALIAS = 32'h0000_0140;  // index 0 -> aliases PC_A

    reg                 clk = 1'b0;
    reg                 rst = 1'b1;
    reg  [PC_WIDTH-1:0] lookup_pc = 0;
    reg                 update_en = 1'b0;
    reg  [PC_WIDTH-1:0] update_pc = 0;
    reg                 actual_taken = 1'b0;
    wire                predict_taken;
    wire [1:0]          lookup_state;

    two_bit_predictor #(.PC_WIDTH(PC_WIDTH), .ENTRIES(ENTRIES)) dut (
        .clk(clk), .rst(rst),
        .lookup_pc(lookup_pc), .predict_taken(predict_taken),
        .lookup_state(lookup_state),
        .update_en(update_en), .update_pc(update_pc),
        .actual_taken(actual_taken)
    );

    // Second predictor with INIT_STATE=00 (Strongly Not Taken) to compare reset-state effect
    wire                predict_taken_00;
    wire [1:0]          lookup_state_00;
    two_bit_predictor #(.PC_WIDTH(PC_WIDTH), .ENTRIES(ENTRIES), .INIT_STATE(2'b00)) dut_init00 (
        .clk(clk), .rst(rst),
        .lookup_pc(lookup_pc), .predict_taken(predict_taken_00),
        .lookup_state(lookup_state_00),
        .update_en(update_en), .update_pc(update_pc),
        .actual_taken(actual_taken)
    );

    // Stand-alone update_logic instances for exhaustive checking
    reg  [1:0] ul2_cur;  reg ul2_t;  wire [1:0] ul2_next;
    reg        ul1_cur;  reg ul1_t;  wire       ul1_next;
    update_logic #(.STATE_BITS(2)) u_ul2 (.current_state(ul2_cur), .actual_taken(ul2_t), .next_state(ul2_next));
    update_logic #(.STATE_BITS(1)) u_ul1 (.current_state(ul1_cur), .actual_taken(ul1_t), .next_state(ul1_next));

    always #5 clk = ~clk;

    integer checks = 0, errors = 0, i, s, t, mispredicts, mispredicts_00;
    reg [1:0] expected_next;

    function [1:0] ref_next(input [1:0] cur, input taken);
        // Reference transition table written out explicitly (independent of RTL)
        case ({cur, taken})
            3'b00_1: ref_next = WNT;  3'b01_1: ref_next = WT;
            3'b10_1: ref_next = ST;   3'b11_1: ref_next = ST;
            3'b11_0: ref_next = WT;   3'b10_0: ref_next = WNT;
            3'b01_0: ref_next = SNT;  3'b00_0: ref_next = SNT;
        endcase
    endfunction

    task expect_state(input [31:0] pc, input [1:0] exp_state, input [8*48-1:0] what);
        begin
            @(negedge clk);
            update_en = 1'b0; lookup_pc = pc;
            #1 checks = checks + 1;
            if (lookup_state !== exp_state || predict_taken !== exp_state[1]) begin
                errors = errors + 1;
                $display("  FAIL [%0s] pc=%h state=%b pred=%b expected state=%b pred=%b",
                         what, pc, lookup_state, predict_taken, exp_state, exp_state[1]);
            end else
                $display("  ok   [%0s] pc=%h state=%b pred=%b", what, pc, lookup_state, predict_taken);
        end
    endtask

    task update(input [31:0] pc, input taken);
        begin
            @(negedge clk);
            lookup_pc = pc; update_pc = pc; actual_taken = taken; update_en = 1'b1;
        end
    endtask

    task do_reset;
        begin
            @(negedge clk); update_en = 1'b0; rst = 1'b1;
            @(negedge clk); rst = 1'b0;
        end
    endtask

    // Drive the entry for pc from reset (WNT) into state 'target'
    task drive_to(input [31:0] pc, input [1:0] target);
        begin
            do_reset;
            case (target)
                SNT: update(pc, 0);
                WNT: ;
                WT : update(pc, 1);
                ST : begin update(pc, 1); update(pc, 1); end
            endcase
        end
    endtask

    initial begin
        $dumpfile("simulation/waveforms/tb_two_bit_predictor.vcd");
        $dumpvars(0, tb_two_bit_predictor);
        $display("=== Test 3: dynamic 2-bit saturating predictor ===");

        // (a) update_logic exhaustive
        for (s = 0; s < 4; s = s + 1)
            for (t = 0; t < 2; t = t + 1) begin
                ul2_cur = s; ul2_t = t; #1;
                checks = checks + 1;
                if (ul2_next !== ref_next(s, t)) begin
                    errors = errors + 1;
                    $display("  FAIL [update_logic 2b] %b + %0d -> %b expected %b", s[1:0], t, ul2_next, ref_next(s, t));
                end else
                    $display("  ok   [update_logic 2b] %b + %s -> %b", s[1:0], t ? "T" : "N", ul2_next);
            end
        for (s = 0; s < 2; s = s + 1)
            for (t = 0; t < 2; t = t + 1) begin
                ul1_cur = s; ul1_t = t; #1;
                checks = checks + 1;
                if (ul1_next !== t[0]) begin
                    errors = errors + 1;
                    $display("  FAIL [update_logic 1b] %b + %0d -> %b", s[0], t, ul1_next);
                end else
                    $display("  ok   [update_logic 1b] %b + %s -> %b (= last outcome)", s[0], t ? "T" : "N", ul1_next);
            end

        @(negedge clk); @(negedge clk); rst = 1'b0;

        // (b) reset state
        for (i = 0; i < ENTRIES; i = i + 1)
            expect_state(PC_A + 4*i, WNT, "reset: Weakly Not Taken");

        // (c)+(d) full transition table through the BHT
        for (s = 0; s < 4; s = s + 1)
            for (t = 0; t < 2; t = t + 1) begin
                drive_to(PC_A, s);
                expect_state(PC_A, s, "start state");
                update(PC_A, t);
                expected_next = ref_next(s, t);
                expect_state(PC_A, expected_next, t ? "after TAKEN" : "after NOT TAKEN");
            end

        // (e) saturation, no wrap-around
        drive_to(PC_A, ST);
        for (i = 0; i < 5; i = i + 1) update(PC_A, 1);
        expect_state(PC_A, ST, "saturate high: 11 + T x5 stays 11");
        drive_to(PC_A, SNT);
        for (i = 0; i < 5; i = i + 1) update(PC_A, 0);
        expect_state(PC_A, SNT, "saturate low: 00 + N x5 stays 00");

        // (f) loop TTTTTN x3
        do_reset;
        mispredicts = 0;
        for (i = 0; i < 18; i = i + 1) begin
            @(negedge clk);
            lookup_pc = PC_B; update_pc = PC_B; update_en = 1'b1;
            actual_taken = ((i % 6) != 5);
            #1 if (predict_taken != actual_taken) mispredicts = mispredicts + 1;
        end
        // Execution 1: miss at i=0 (cold, WNT) and at exit; then 01->10->11.
        // After exit: 11->10 (still predicts T) -> executions 2,3 miss only at exit.
        checks = checks + 1;
        if (mispredicts !== 4) begin
            errors = errors + 1;
            $display("  FAIL [loop TTTTTN x3] mispredicts=%0d expected 4", mispredicts);
        end else
            $display("  ok   [loop TTTTTN x3] mispredicts=%0d (1 per execution after warm-up)", mispredicts);
        expect_state(PC_B, WT, "after loop exit counter is Weakly Taken");

        // (g) alternating T N T N ... from reset (WNT): oscillates 01<->10
        do_reset;
        mispredicts = 0; mispredicts_00 = 0;
        for (i = 0; i < 12; i = i + 1) begin
            @(negedge clk);
            lookup_pc = PC_B; update_pc = PC_B; update_en = 1'b1;
            actual_taken = ((i % 2) == 0);
            #1 if (predict_taken != actual_taken) mispredicts = mispredicts + 1;
            if (predict_taken_00 != actual_taken) mispredicts_00 = mispredicts_00 + 1;
        end
        checks = checks + 1;
        if (mispredicts !== 12) begin
            errors = errors + 1;
            $display("  FAIL [alternating x12] mispredicts=%0d expected 12", mispredicts);
        end else
            $display("  ok   [alternating x12] mispredicts=%0d (worst case: oscillates WNT<->WT)", mispredicts);
        checks = checks + 1;
        if (mispredicts_00 !== 6) begin
            errors = errors + 1;
            $display("  FAIL [alternating x12, reset 00] mispredicts=%0d expected 6", mispredicts_00);
        end else
            $display("  ok   [alternating x12, reset 00] mispredicts=%0d (right every second branch)", mispredicts_00);

        // (h) independent entries and aliasing
        do_reset;
        update(PC_A, 1); update(PC_A, 1);                   // PC_A -> 11
        expect_state(PC_A, ST, "PC_A trained Strongly Taken");
        expect_state(PC_B, WNT, "PC_B independent (still WNT)");
        expect_state(PC_ALIAS, ST, "alias reads PC_A's counter");
        update(PC_ALIAS, 0);
        expect_state(PC_A, WT, "PC_A disturbed by alias (11->10)");

        // (i) mid-run reset
        do_reset;
        for (i = 0; i < ENTRIES; i = i + 1)
            expect_state(PC_A + 4*i, WNT, "after reset: Weakly Not Taken");

        @(negedge clk); update_en = 1'b0;
        $display("TEST_RESULT: %s tb_two_bit_predictor (%0d/%0d checks passed)",
                 (errors == 0) ? "PASS" : "FAIL", checks - errors, checks);
        $finish;
    end
endmodule
