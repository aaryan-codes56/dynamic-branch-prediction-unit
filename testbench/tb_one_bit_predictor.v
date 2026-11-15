// =============================================================================
// Testbench : tb_one_bit_predictor
// Test 2    : Dynamic 1-bit predictor (plus parts of Tests 4, 6 and 10).
// Checks    : reset state, initial prediction, first taken, repeated taken,
//             switch to not taken, repeated not taken, independent entries,
//             index aliasing, loop behaviour (2 mispredictions per loop
//             execution) and mid-run reset.
// Method    : Each step() drives one branch: lookup and update use the same
//             PC in one clock cycle. The prediction/state is checked BEFORE
//             the rising edge (old state), the update happens AT the edge.
// =============================================================================
`timescale 1ns/1ps
module tb_one_bit_predictor;

    localparam PC_WIDTH = 32;
    localparam ENTRIES  = 16;

    // PCs used in the test (index = pc[5:2] for 16 entries)
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

    one_bit_predictor #(.PC_WIDTH(PC_WIDTH), .ENTRIES(ENTRIES)) dut (
        .clk(clk), .rst(rst),
        .lookup_pc(lookup_pc), .predict_taken(predict_taken),
        .lookup_state(lookup_state),
        .update_en(update_en), .update_pc(update_pc),
        .actual_taken(actual_taken)
    );

    always #5 clk = ~clk;

    integer checks = 0, errors = 0, i, mispredicts;

    // Lookup only (no update); check prediction for pc
    task peek(input [31:0] pc, input exp_pred, input [8*48-1:0] what);
        begin
            @(negedge clk);
            update_en = 1'b0; lookup_pc = pc;
            #1 checks = checks + 1;
            if (predict_taken !== exp_pred || lookup_state !== {1'b0, exp_pred}) begin
                errors = errors + 1;
                $display("  FAIL [%0s] pc=%h pred=%b expected=%b", what, pc, predict_taken, exp_pred);
            end else
                $display("  ok   [%0s] pc=%h pred=%b", what, pc, predict_taken);
        end
    endtask

    // One resolved branch: check prediction, then update with actual outcome
    task step(input [31:0] pc, input taken, input exp_pred, input [8*48-1:0] what);
        begin
            @(negedge clk);
            lookup_pc = pc; update_pc = pc; actual_taken = taken; update_en = 1'b1;
            #1 checks = checks + 1;
            if (predict_taken !== exp_pred) begin
                errors = errors + 1;
                $display("  FAIL [%0s] pc=%h actual=%0d pred=%b expected=%b", what, pc, taken, predict_taken, exp_pred);
            end else
                $display("  ok   [%0s] pc=%h actual=%0d pred=%b", what, pc, taken, predict_taken);
        end
    endtask

    initial begin
        $dumpfile("simulation/waveforms/tb_one_bit_predictor.vcd");
        $dumpvars(0, tb_one_bit_predictor);
        $display("=== Test 2: dynamic 1-bit predictor ===");

        @(negedge clk); @(negedge clk); rst = 1'b0;

        // --- Reset state: every entry predicts NOT TAKEN -------------------
        for (i = 0; i < ENTRIES; i = i + 1)
            peek(PC_A + 4*i, 1'b0, "reset: entry not taken");

        // --- Basic learning --------------------------------------------------
        step(PC_A, 1, 0, "initial prediction NT, actual T");
        step(PC_A, 1, 1, "learned T after first taken");
        step(PC_A, 1, 1, "repeated taken");
        step(PC_A, 0, 1, "actual N while predicting T (mispredict)");
        step(PC_A, 0, 0, "switched to NT after one N");
        step(PC_A, 0, 0, "repeated not taken");
        step(PC_A, 1, 0, "single T after N run (mispredict)");
        peek(PC_A, 1'b1, "1-bit flips immediately on a single outcome");

        // --- Multiple addresses: independent entries (Test 6) ----------------
        peek(PC_B, 1'b0, "PC_B unaffected by PC_A training");
        step(PC_B, 0, 0, "PC_B trained NT");
        peek(PC_A, 1'b1, "PC_A still T after PC_B update");

        // --- Aliasing (Test 6): PC_ALIAS shares index 0 with PC_A ------------
        peek(PC_ALIAS, 1'b1, "alias sees PC_A's state (aliasing)");
        step(PC_ALIAS, 0, 1, "alias trains entry to NT");
        peek(PC_A, 1'b0, "PC_A prediction corrupted by alias");

        // --- Loop behaviour (Test 4): T T T T T N, executed 3 times ----------
        @(negedge clk); rst = 1'b1; @(negedge clk); rst = 1'b0;
        mispredicts = 0;
        for (i = 0; i < 18; i = i + 1) begin
            @(negedge clk);
            lookup_pc = PC_B; update_pc = PC_B; update_en = 1'b1;
            actual_taken = ((i % 6) != 5);
            #1 if (predict_taken != actual_taken) mispredicts = mispredicts + 1;
        end
        // Execution 1: miss at i=0 (cold) and i=5 (exit) = 2
        // Executions 2,3: miss at first iteration and at exit = 2 each
        checks = checks + 1;
        if (mispredicts !== 6) begin
            errors = errors + 1;
            $display("  FAIL [loop TTTTTN x3] mispredicts=%0d expected 6", mispredicts);
        end else
            $display("  ok   [loop TTTTTN x3] mispredicts=%0d (2 per loop execution)", mispredicts);

        // --- Mid-run reset (Test 10) ----------------------------------------
        step(PC_A, 1, 0, "train PC_A before reset");
        peek(PC_A, 1'b1, "PC_A taken before reset");
        @(negedge clk); update_en = 1'b0; rst = 1'b1;
        @(negedge clk); rst = 1'b0;
        for (i = 0; i < ENTRIES; i = i + 1)
            peek(PC_A + 4*i, 1'b0, "after reset: entry not taken");

        @(negedge clk); update_en = 1'b0;
        $display("TEST_RESULT: %s tb_one_bit_predictor (%0d/%0d checks passed)",
                 (errors == 0) ? "PASS" : "FAIL", checks - errors, checks);
        $finish;
    end
endmodule
