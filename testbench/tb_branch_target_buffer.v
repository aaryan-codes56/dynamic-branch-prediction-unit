// =============================================================================
// Testbench : tb_branch_target_buffer
// Test 11   : Branch Target Buffer.
// Config    : ENTRIES = 8 -> index = pc[4:2], tag = pc[31:5].
// Checks    : miss after reset, hit + target after update, tag mismatch on
//             same index is a miss (tagged BTB), replacement of an entry,
//             target update of an existing branch, update_en = 0 ignored,
//             independent entries, reset clears valid bits.
// =============================================================================
`timescale 1ns/1ps
module tb_branch_target_buffer;

    localparam PC_WIDTH = 32;
    localparam ENTRIES  = 8;

    localparam [31:0] PC_A      = 32'h0000_0104;  // idx 1, tag 0x8
    localparam [31:0] PC_A_TGT  = 32'h0000_00f0;
    localparam [31:0] PC_A_TGT2 = 32'h0000_0200;
    localparam [31:0] PC_C      = 32'h0000_0124;  // idx 1, tag 0x9 (conflicts with PC_A)
    localparam [31:0] PC_C_TGT  = 32'h0000_0300;
    localparam [31:0] PC_D      = 32'h0000_0108;  // idx 2
    localparam [31:0] PC_D_TGT  = 32'h0000_0400;

    reg                 clk = 1'b0;
    reg                 rst = 1'b1;
    reg  [PC_WIDTH-1:0] lookup_pc = 0;
    reg                 update_en = 1'b0;
    reg  [PC_WIDTH-1:0] update_pc = 0;
    reg  [PC_WIDTH-1:0] update_target = 0;
    wire                lookup_hit;
    wire [PC_WIDTH-1:0] lookup_target;

    branch_target_buffer #(.PC_WIDTH(PC_WIDTH), .ENTRIES(ENTRIES)) dut (
        .clk(clk), .rst(rst),
        .lookup_pc(lookup_pc), .lookup_hit(lookup_hit), .lookup_target(lookup_target),
        .update_en(update_en), .update_pc(update_pc), .update_target(update_target)
    );

    always #5 clk = ~clk;

    integer checks = 0, errors = 0, i;

    task btb_write(input [31:0] pc, input [31:0] tgt, input en);
        begin
            @(negedge clk);
            update_pc = pc; update_target = tgt; update_en = en;
            @(negedge clk);
            update_en = 1'b0;
        end
    endtask

    task expect_hit(input [31:0] pc, input [31:0] tgt, input [8*48-1:0] what);
        begin
            lookup_pc = pc; #1;
            checks = checks + 1;
            if (lookup_hit !== 1'b1 || lookup_target !== tgt) begin
                errors = errors + 1;
                $display("  FAIL [%0s] pc=%h hit=%b target=%h expected HIT %h", what, pc, lookup_hit, lookup_target, tgt);
            end else
                $display("  ok   [%0s] pc=%h HIT target=%h", what, pc, lookup_target);
        end
    endtask

    task expect_miss(input [31:0] pc, input [8*48-1:0] what);
        begin
            lookup_pc = pc; #1;
            checks = checks + 1;
            if (lookup_hit !== 1'b0) begin
                errors = errors + 1;
                $display("  FAIL [%0s] pc=%h hit=%b expected MISS", what, pc, lookup_hit);
            end else
                $display("  ok   [%0s] pc=%h MISS", what, pc);
        end
    endtask

    initial begin
        $dumpfile("simulation/waveforms/tb_branch_target_buffer.vcd");
        $dumpvars(0, tb_branch_target_buffer);
        $display("=== Test 11: Branch Target Buffer (8 entries) ===");

        @(negedge clk); @(negedge clk); rst = 1'b0;

        for (i = 0; i < ENTRIES; i = i + 1)
            expect_miss(32'h0000_0100 + 4*i, "reset: all entries invalid");

        btb_write(PC_A, PC_A_TGT, 1'b1);
        expect_hit (PC_A, PC_A_TGT, "hit after first update");
        expect_miss(PC_C, "same index, different tag -> miss");
        expect_miss(PC_D, "other index still invalid");

        btb_write(PC_D, PC_D_TGT, 1'b1);
        expect_hit (PC_D, PC_D_TGT, "second entry hit");
        expect_hit (PC_A, PC_A_TGT, "first entry unaffected");

        btb_write(PC_A, PC_A_TGT2, 1'b1);
        expect_hit (PC_A, PC_A_TGT2, "target updated for same branch");

        btb_write(PC_C, PC_C_TGT, 1'b1);
        expect_hit (PC_C, PC_C_TGT, "conflicting branch replaces entry");
        expect_miss(PC_A, "replaced branch now misses");

        btb_write(PC_A, 32'hdead_beec, 1'b0);
        expect_miss(PC_A, "update_en=0 ignored (no allocate)");
        expect_hit (PC_C, PC_C_TGT, "update_en=0 ignored (no overwrite)");

        @(negedge clk); rst = 1'b1; @(negedge clk); rst = 1'b0;
        expect_miss(PC_C, "reset clears valid (PC_C)");
        expect_miss(PC_D, "reset clears valid (PC_D)");

        $display("TEST_RESULT: %s tb_branch_target_buffer (%0d/%0d checks passed)",
                 (errors == 0) ? "PASS" : "FAIL", checks - errors, checks);
        $finish;
    end
endmodule
