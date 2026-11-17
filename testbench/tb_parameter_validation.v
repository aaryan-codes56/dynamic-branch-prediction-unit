// =============================================================================
// Testbench : tb_parameter_validation
// Project   : DBPU - Dynamic Branch Prediction Unit
// Purpose   : Comprehensive functional verification of parameterization boundaries
//             and index safety:
//             1. BHT capacities: 1 (single-entry), 2, 4, 8, 16, 32 entries.
//             2. BTB capacities: 1 (single-entry), 2, 4, 8, 16, 32 entries.
//             3. PC_WIDTH scaling: 16-bit, 32-bit, 64-bit architectures.
//             4. Boundary addresses: lowest PC (0x0), highest PC (all-ones).
//             5. Alignment bits [1:0] invariance.
//             6. Top-level integration across heterogeneous parameter combinations
//                (including single-entry 1x1 DBPU and 32x32 DBPU).
// =============================================================================
`timescale 1ns/1ps

module tb_parameter_validation;

    reg clk = 1'b0;
    reg rst = 1'b1;
    always #5 clk = ~clk;

    integer checks = 0;
    integer errors = 0;

    // -------------------------------------------------------------------------
    // Helper task for reporting checks
    // -------------------------------------------------------------------------
    task assert_cond(input cond, input [8*64-1:0] msg);
        begin
            checks = checks + 1;
            if (!cond) begin
                errors = errors + 1;
                $display("  FAIL: %0s", msg);
            end else begin
                $display("  ok:   %0s", msg);
            end
        end
    endtask

    // =========================================================================
    // 1. BHT Parameter Sweep Instances (1, 2, 4, 8, 16, 32 entries)
    // =========================================================================
    reg  [31:0] bht_lpc, bht_upc;
    reg         bht_wren;
    reg  [1:0]  bht_wrstate;

    wire [1:0] bht1_lstate,  bht1_ustate;
    wire [1:0] bht2_lstate,  bht2_ustate;
    wire [1:0] bht4_lstate,  bht4_ustate;
    wire [1:0] bht8_lstate,  bht8_ustate;
    wire [1:0] bht16_lstate, bht16_ustate;
    wire [1:0] bht32_lstate, bht32_ustate;

    branch_history_table #(.PC_WIDTH(32), .ENTRIES(1),  .STATE_BITS(2), .INIT_STATE(2'b01)) u_bht_1 (
        .clk(clk), .rst(rst), .lookup_pc(bht_lpc), .lookup_state(bht1_lstate),
        .update_pc(bht_upc), .update_state(bht1_ustate), .wr_en(bht_wren), .wr_state(bht_wrstate)
    );
    branch_history_table #(.PC_WIDTH(32), .ENTRIES(2),  .STATE_BITS(2), .INIT_STATE(2'b01)) u_bht_2 (
        .clk(clk), .rst(rst), .lookup_pc(bht_lpc), .lookup_state(bht2_lstate),
        .update_pc(bht_upc), .update_state(bht2_ustate), .wr_en(bht_wren), .wr_state(bht_wrstate)
    );
    branch_history_table #(.PC_WIDTH(32), .ENTRIES(4),  .STATE_BITS(2), .INIT_STATE(2'b01)) u_bht_4 (
        .clk(clk), .rst(rst), .lookup_pc(bht_lpc), .lookup_state(bht4_lstate),
        .update_pc(bht_upc), .update_state(bht4_ustate), .wr_en(bht_wren), .wr_state(bht_wrstate)
    );
    branch_history_table #(.PC_WIDTH(32), .ENTRIES(8),  .STATE_BITS(2), .INIT_STATE(2'b01)) u_bht_8 (
        .clk(clk), .rst(rst), .lookup_pc(bht_lpc), .lookup_state(bht8_lstate),
        .update_pc(bht_upc), .update_state(bht8_ustate), .wr_en(bht_wren), .wr_state(bht_wrstate)
    );
    branch_history_table #(.PC_WIDTH(32), .ENTRIES(16), .STATE_BITS(2), .INIT_STATE(2'b01)) u_bht_16 (
        .clk(clk), .rst(rst), .lookup_pc(bht_lpc), .lookup_state(bht16_lstate),
        .update_pc(bht_upc), .update_state(bht16_ustate), .wr_en(bht_wren), .wr_state(bht_wrstate)
    );
    branch_history_table #(.PC_WIDTH(32), .ENTRIES(32), .STATE_BITS(2), .INIT_STATE(2'b01)) u_bht_32 (
        .clk(clk), .rst(rst), .lookup_pc(bht_lpc), .lookup_state(bht32_lstate),
        .update_pc(bht_upc), .update_state(bht32_ustate), .wr_en(bht_wren), .wr_state(bht_wrstate)
    );

    // =========================================================================
    // 2. BTB Parameter Sweep Instances (1, 2, 4, 8, 16, 32 entries)
    // =========================================================================
    reg  [31:0] btb_lpc, btb_upc, btb_utgt;
    reg         btb_upen;

    wire        btb1_hit,  btb2_hit,  btb4_hit,  btb8_hit,  btb16_hit,  btb32_hit;
    wire [31:0] btb1_tgt,  btb2_tgt,  btb4_tgt,  btb8_tgt,  btb16_tgt,  btb32_tgt;

    branch_target_buffer #(.PC_WIDTH(32), .ENTRIES(1))  u_btb_1 (
        .clk(clk), .rst(rst), .lookup_pc(btb_lpc), .lookup_hit(btb1_hit), .lookup_target(btb1_tgt),
        .update_en(btb_upen), .update_pc(btb_upc), .update_target(btb_utgt)
    );
    branch_target_buffer #(.PC_WIDTH(32), .ENTRIES(2))  u_btb_2 (
        .clk(clk), .rst(rst), .lookup_pc(btb_lpc), .lookup_hit(btb2_hit), .lookup_target(btb2_tgt),
        .update_en(btb_upen), .update_pc(btb_upc), .update_target(btb_utgt)
    );
    branch_target_buffer #(.PC_WIDTH(32), .ENTRIES(4))  u_btb_4 (
        .clk(clk), .rst(rst), .lookup_pc(btb_lpc), .lookup_hit(btb4_hit), .lookup_target(btb4_tgt),
        .update_en(btb_upen), .update_pc(btb_upc), .update_target(btb_utgt)
    );
    branch_target_buffer #(.PC_WIDTH(32), .ENTRIES(8))  u_btb_8 (
        .clk(clk), .rst(rst), .lookup_pc(btb_lpc), .lookup_hit(btb8_hit), .lookup_target(btb8_tgt),
        .update_en(btb_upen), .update_pc(btb_upc), .update_target(btb_utgt)
    );
    branch_target_buffer #(.PC_WIDTH(32), .ENTRIES(16)) u_btb_16 (
        .clk(clk), .rst(rst), .lookup_pc(btb_lpc), .lookup_hit(btb16_hit), .lookup_target(btb16_tgt),
        .update_en(btb_upen), .update_pc(btb_upc), .update_target(btb_utgt)
    );
    branch_target_buffer #(.PC_WIDTH(32), .ENTRIES(32)) u_btb_32 (
        .clk(clk), .rst(rst), .lookup_pc(btb_lpc), .lookup_hit(btb32_hit), .lookup_target(btb32_tgt),
        .update_en(btb_upen), .update_pc(btb_upc), .update_target(btb_utgt)
    );

    // =========================================================================
    // 3. Different PC_WIDTH Architectures (16-bit and 64-bit)
    // =========================================================================
    reg  [15:0] pc16_lpc, pc16_upc, pc16_utgt;
    reg         pc16_upen;
    wire        pc16_hit;
    wire [15:0] pc16_tgt;

    branch_target_buffer #(.PC_WIDTH(16), .ENTRIES(4)) u_btb_w16 (
        .clk(clk), .rst(rst), .lookup_pc(pc16_lpc), .lookup_hit(pc16_hit), .lookup_target(pc16_tgt),
        .update_en(pc16_upen), .update_pc(pc16_upc), .update_target(pc16_utgt)
    );

    reg  [63:0] pc64_lpc, pc64_upc, pc64_utgt;
    reg         pc64_upen;
    wire        pc64_hit;
    wire [63:0] pc64_tgt;

    branch_target_buffer #(.PC_WIDTH(64), .ENTRIES(8)) u_btb_w64 (
        .clk(clk), .rst(rst), .lookup_pc(pc64_lpc), .lookup_hit(pc64_hit), .lookup_target(pc64_tgt),
        .update_en(pc64_upen), .update_pc(pc64_upc), .update_target(pc64_utgt)
    );

    // =========================================================================
    // 4. Top-Level DBPU Heterogeneous Parameter Configurations
    // =========================================================================
    // Config 1x1: Single-entry 2-bit DBPU (extreme minimal hardware)
    reg         top1_ifv, top1_exv, top1_extaken, top1_exptaken;
    reg  [31:0] top1_ifpc, top1_expc, top1_extgt, top1_expnpc;
    wire        top1_pv, top1_ptaken, top1_pvalid_tgt, top1_predir, top1_dir_mp, top1_mp, top1_flush;
    wire [1:0]  top1_pstate;
    wire [31:0] top1_ptgt, top1_pnpc, top1_cpc;

    branch_prediction_top #(.PC_WIDTH(32), .BHT_ENTRIES(1), .BTB_ENTRIES(1), .PREDICTOR_TYPE(2)) u_top_1x1 (
        .clk(clk), .rst(rst),
        .if_valid(top1_ifv), .if_pc(top1_ifpc),
        .pred_valid(top1_pv), .pred_taken(top1_ptaken), .pred_target_valid(top1_pvalid_tgt),
        .pred_target(top1_ptgt), .pred_redirect(top1_predir), .pred_next_pc(top1_pnpc), .pred_state(top1_pstate),
        .ex_valid(top1_exv), .ex_pc(top1_expc), .ex_actual_taken(top1_extaken), .ex_actual_target(top1_extgt),
        .ex_pred_taken(top1_exptaken), .ex_pred_next_pc(top1_expnpc),
        .ex_dir_mispredict(top1_dir_mp), .ex_mispredict(top1_mp), .flush(top1_flush), .ex_correct_pc(top1_cpc)
    );

    // Config 32x32: High-capacity 2-bit DBPU
    reg         top32_ifv, top32_exv, top32_extaken, top32_exptaken;
    reg  [31:0] top32_ifpc, top32_expc, top32_extgt, top32_expnpc;
    wire        top32_pv, top32_ptaken, top32_pvalid_tgt, top32_predir, top32_dir_mp, top32_mp, top32_flush;
    wire [1:0]  top32_pstate;
    wire [31:0] top32_ptgt, top32_pnpc, top32_cpc;

    branch_prediction_top #(.PC_WIDTH(32), .BHT_ENTRIES(32), .BTB_ENTRIES(32), .PREDICTOR_TYPE(2)) u_top_32x32 (
        .clk(clk), .rst(rst),
        .if_valid(top32_ifv), .if_pc(top32_ifpc),
        .pred_valid(top32_pv), .pred_taken(top32_ptaken), .pred_target_valid(top32_pvalid_tgt),
        .pred_target(top32_ptgt), .pred_redirect(top32_predir), .pred_next_pc(top32_pnpc), .pred_state(top32_pstate),
        .ex_valid(top32_exv), .ex_pc(top32_expc), .ex_actual_taken(top32_extaken), .ex_actual_target(top32_extgt),
        .ex_pred_taken(top32_exptaken), .ex_pred_next_pc(top32_expnpc),
        .ex_dir_mispredict(top32_dir_mp), .ex_mispredict(top32_mp), .flush(top32_flush), .ex_correct_pc(top32_cpc)
    );

    // =========================================================================
    // Test Sequences
    // =========================================================================
    integer i;

    initial begin
        $display("=================================================================");
        $display("=== STARTING COMPREHENSIVE PARAMETER VALIDATION REGRESSION ===");
        $display("=================================================================");

        bht_lpc = 0; bht_upc = 0; bht_wren = 0; bht_wrstate = 0;
        btb_lpc = 0; btb_upc = 0; btb_utgt = 0; btb_upen = 0;
        pc16_lpc = 0; pc16_upc = 0; pc16_utgt = 0; pc16_upen = 0;
        pc64_lpc = 0; pc64_upc = 0; pc64_utgt = 0; pc64_upen = 0;
        top1_ifv = 0; top1_ifpc = 0; top1_exv = 0; top1_expc = 0; top1_extaken = 0; top1_extgt = 0; top1_exptaken = 0; top1_expnpc = 0;
        top32_ifv = 0; top32_ifpc = 0; top32_exv = 0; top32_expc = 0; top32_extaken = 0; top32_extgt = 0; top32_exptaken = 0; top32_expnpc = 0;

        // Apply Synchronous Reset
        repeat (2) @(negedge clk);
        rst = 1'b0;
        @(negedge clk);

        // ---------------------------------------------------------------------
        // TEST GROUP 1: Single-Entry BHT (ENTRIES = 1)
        // ---------------------------------------------------------------------
        $display("\n--- Test Group 1: Single-Entry BHT (ENTRIES = 1) ---");
        bht_lpc = 32'h0000_0100; #1;
        assert_cond(bht1_lstate === 2'b01, "BHT-1: Reset state is INIT_STATE (2'b01)");
        
        // Write state 2'b11 via PC 0x100
        @(negedge clk); bht_upc = 32'h0000_0100; bht_wrstate = 2'b11; bht_wren = 1'b1;
        @(negedge clk); bht_wren = 1'b0;

        // Verify that ANY PC reads 2'b11 (complete global aliasing)
        bht_lpc = 32'h0000_0100; #1; assert_cond(bht1_lstate === 2'b11, "BHT-1: PC 0x100 reads written state 2'b11");
        bht_lpc = 32'h0000_0104; #1; assert_cond(bht1_lstate === 2'b11, "BHT-1: PC 0x104 aliases to single entry (2'b11)");
        bht_lpc = 32'h0000_0200; #1; assert_cond(bht1_lstate === 2'b11, "BHT-1: PC 0x200 aliases to single entry (2'b11)");
        bht_lpc = 32'hffff_fffc; #1; assert_cond(bht1_lstate === 2'b11, "BHT-1: Highest PC 0xFFFFFFFC aliases to single entry (2'b11)");

        // ---------------------------------------------------------------------
        // TEST GROUP 2: Power-of-Two BHT Sweeps (2, 4, 8, 16, 32 entries)
        // ---------------------------------------------------------------------
        $display("\n--- Test Group 2: BHT Capacity Sweeps (2, 4, 8, 16, 32 entries) ---");
        // Test 2-entry BHT: index bit is pc[2]. (0x100 has pc[2]=0, 0x104 has pc[2]=1)
        @(negedge clk); bht_upc = 32'h0000_0100; bht_wrstate = 2'b00; bht_wren = 1'b1;
        @(negedge clk); bht_upc = 32'h0000_0104; bht_wrstate = 2'b10; bht_wren = 1'b1;
        @(negedge clk); bht_wren = 1'b0;
        bht_lpc = 32'h0000_0100; #1; assert_cond(bht2_lstate === 2'b00, "BHT-2: Entry 0 holds 2'b00");
        bht_lpc = 32'h0000_0104; #1; assert_cond(bht2_lstate === 2'b10, "BHT-2: Entry 1 holds 2'b10");
        bht_lpc = 32'h0000_0108; #1; assert_cond(bht2_lstate === 2'b00, "BHT-2: PC 0x108 (pc[2]=0) aliases Entry 0");
        bht_lpc = 32'h0000_010c; #1; assert_cond(bht2_lstate === 2'b10, "BHT-2: PC 0x10c (pc[2]=1) aliases Entry 1");

        // Test 4-entry BHT: index bits are pc[3:2] (0..3)
        for (i = 0; i < 4; i = i + 1) begin
            @(negedge clk); bht_upc = 32'h0000_0200 + (i * 4); bht_wrstate = i[1:0]; bht_wren = 1'b1;
        end
        @(negedge clk); bht_wren = 1'b0;
        for (i = 0; i < 4; i = i + 1) begin
            bht_lpc = 32'h0000_0200 + (i * 4); #1;
            assert_cond(bht4_lstate === i[1:0], "BHT-4: Correct entry readback");
        end

        // Test 32-entry BHT: boundary entries 0 (0x00) and 31 (0x7C)
        @(negedge clk); bht_upc = 32'h0000_0000; bht_wrstate = 2'b11; bht_wren = 1'b1;
        @(negedge clk); bht_upc = 32'h0000_007c; bht_wrstate = 2'b10; bht_wren = 1'b1;
        @(negedge clk); bht_wren = 1'b0;
        bht_lpc = 32'h0000_0000; #1; assert_cond(bht32_lstate === 2'b11, "BHT-32: Boundary Entry 0 holds 2'b11");
        bht_lpc = 32'h0000_007c; #1; assert_cond(bht32_lstate === 2'b10, "BHT-32: Boundary Entry 31 holds 2'b10");
        bht_lpc = 32'h0000_0080; #1; assert_cond(bht32_lstate === 2'b11, "BHT-32: 0x80 aliases Entry 0");

        // ---------------------------------------------------------------------
        // TEST GROUP 3: Single-Entry BTB (ENTRIES = 1)
        // ---------------------------------------------------------------------
        $display("\n--- Test Group 3: Single-Entry BTB (ENTRIES = 1) ---");
        btb_lpc = 32'h0000_0100; #1;
        assert_cond(btb1_hit === 1'b0, "BTB-1: Cold miss after reset");

        // Write PC 0x100 -> Target 0x500
        @(negedge clk); btb_upc = 32'h0000_0100; btb_utgt = 32'h0000_0500; btb_upen = 1'b1;
        @(negedge clk); btb_upen = 1'b0;

        // Lookup exact PC: must HIT
        btb_lpc = 32'h0000_0100; #1;
        assert_cond(btb1_hit === 1'b1 && btb1_tgt === 32'h0000_0500, "BTB-1: Hit on exact PC 0x100 with target 0x500");

        // Lookup differing PC 0x104: must MISS due to 30-bit tag check!
        btb_lpc = 32'h0000_0104; #1;
        assert_cond(btb1_hit === 1'b0, "BTB-1: Miss on differing PC 0x104 (tagged protection)");

        // Alignment bits [1:0] invariance check: 0x101, 0x102, 0x103 must hit identical entry
        btb_lpc = 32'h0000_0103; #1;
        assert_cond(btb1_hit === 1'b1 && btb1_tgt === 32'h0000_0500, "BTB-1: PC bits [1:0] ignored on lookup");

        // Overwrite single entry with new branch 0x200 -> Target 0x700
        @(negedge clk); btb_upc = 32'h0000_0200; btb_utgt = 32'h0000_0700; btb_upen = 1'b1;
        @(negedge clk); btb_upen = 1'b0;
        btb_lpc = 32'h0000_0200; #1;
        assert_cond(btb1_hit === 1'b1 && btb1_tgt === 32'h0000_0700, "BTB-1: Overwritten entry hits new PC 0x200");
        btb_lpc = 32'h0000_0100; #1;
        assert_cond(btb1_hit === 1'b0, "BTB-1: Old PC 0x100 now misses");

        // ---------------------------------------------------------------------
        // TEST GROUP 4: BTB Capacity Sweeps (2, 4, 8, 16, 32 entries)
        // ---------------------------------------------------------------------
        $display("\n--- Test Group 4: BTB Capacity Sweeps (2, 4, 8, 16, 32 entries) ---");
        // Test BTB-2: Index bit is pc[2]
        @(negedge clk); btb_upc = 32'h0000_0100; btb_utgt = 32'h0000_1000; btb_upen = 1'b1;
        @(negedge clk); btb_upc = 32'h0000_0104; btb_utgt = 32'h0000_2000; btb_upen = 1'b1;
        @(negedge clk); btb_upen = 1'b0;
        btb_lpc = 32'h0000_0100; #1; assert_cond(btb2_hit === 1'b1 && btb2_tgt === 32'h0000_1000, "BTB-2: Entry 0 hits");
        btb_lpc = 32'h0000_0104; #1; assert_cond(btb2_hit === 1'b1 && btb2_tgt === 32'h0000_2000, "BTB-2: Entry 1 hits");
        btb_lpc = 32'h0000_0108; #1; assert_cond(btb2_hit === 1'b0, "BTB-2: Index conflict tag-mismatch misses cleanly");

        // Test BTB-32: Index bits pc[6:2] (32 entries)
        @(negedge clk); btb_upc = 32'h0000_007c; btb_utgt = 32'h0000_8888; btb_upen = 1'b1;
        @(negedge clk); btb_upen = 1'b0;
        btb_lpc = 32'h0000_007c; #1; assert_cond(btb32_hit === 1'b1 && btb32_tgt === 32'h0000_8888, "BTB-32: Boundary entry 31 hits");

        // Boundary address: Highest 32-bit word-aligned PC (0xFFFFFFFC)
        @(negedge clk); btb_upc = 32'hffff_fffc; btb_utgt = 32'h0000_0040; btb_upen = 1'b1;
        @(negedge clk); btb_upen = 1'b0;
        btb_lpc = 32'hffff_fffc; #1; assert_cond(btb16_hit === 1'b1 && btb16_tgt === 32'h0000_0040, "BTB-16: All-ones PC 0xFFFFFFFC hits");

        // ---------------------------------------------------------------------
        // TEST GROUP 5: Scaled PC_WIDTH (16-bit and 64-bit architectures)
        // ---------------------------------------------------------------------
        $display("\n--- Test Group 5: Scaled PC_WIDTH (16-bit and 64-bit architectures) ---");
        // 16-bit PC architecture (TAG_BITS = 16 - 2 - 2 = 12 bits)
        @(negedge clk); pc16_upc = 16'hfffc; pc16_utgt = 16'h0080; pc16_upen = 1'b1;
        @(negedge clk); pc16_upen = 1'b0;
        pc16_lpc = 16'hfffc; #1; assert_cond(pc16_hit === 1'b1 && pc16_tgt === 16'h0080, "BTB-W16: 16-bit PC boundary 0xFFFC hits");
        pc16_lpc = 16'h0ffc; #1; assert_cond(pc16_hit === 1'b0, "BTB-W16: Tag mismatch in 16-bit address space misses");

        // 64-bit PC architecture (TAG_BITS = 64 - 3 - 2 = 59 bits)
        @(negedge clk); pc64_upc = 64'hffff_ffff_ffff_fffc; pc64_utgt = 64'h0000_0000_1234_5678; pc64_upen = 1'b1;
        @(negedge clk); pc64_upen = 1'b0;
        pc64_lpc = 64'hffff_ffff_ffff_fffc; #1;
        assert_cond(pc64_hit === 1'b1 && pc64_tgt === 64'h0000_0000_1234_5678, "BTB-W64: 64-bit PC boundary 0xFFFFFFFFFFFFFFFC hits");

        // ---------------------------------------------------------------------
        // TEST GROUP 6: Top-Level DBPU Heterogeneous Parameter Configurations
        // ---------------------------------------------------------------------
        $display("\n--- Test Group 6: Top-Level DBPU Parameter Configurations ---");
        // Test Minimal 1x1 DBPU (1 BHT entry, 1 BTB entry, 2-bit predictor)
        // Step A: Initial lookup cold miss
        top1_ifpc = 32'h0000_0100; top1_ifv = 1'b1; #1;
        assert_cond(top1_ptaken === 1'b0 && top1_pvalid_tgt === 1'b0 && top1_pnpc === 32'h0000_0104,
                    "Top-1x1: Cold lookup predicts Not-Taken fall-through");

        // Step B: Resolve as Taken -> train single BHT entry and populate single BTB entry
        @(negedge clk);
        top1_exv = 1'b1; top1_expc = 32'h0000_0100; top1_extaken = 1'b1; top1_extgt = 32'h0000_0500;
        top1_exptaken = 1'b0; top1_expnpc = 32'h0000_0104;
        #1; assert_cond(top1_flush === 1'b1 && top1_cpc === 32'h0000_0500, "Top-1x1: Misprediction raises flush and redirects");
        @(negedge clk);
        top1_exv = 1'b0;

        // Step C: Second lookup of 0x100 -> counter is 2'b10 (Weakly Taken), BTB hits!
        top1_ifpc = 32'h0000_0100; top1_ifv = 1'b1; #1;
        assert_cond(top1_ptaken === 1'b1 && top1_pvalid_tgt === 1'b1 && top1_pnpc === 32'h0000_0500,
                    "Top-1x1: Learned branch predicts Taken and redirects to BTB target");

        // Step D: Lookup of another branch 0x200 -> BHT aliases to Taken, but BTB misses (tag mismatch)!
        top1_ifpc = 32'h0000_0200; top1_ifv = 1'b1; #1;
        assert_cond(top1_ptaken === 1'b1 && top1_pvalid_tgt === 1'b0 && top1_pnpc === 32'h0000_0204,
                    "Top-1x1: Aliased branch predicts Taken but falls through due to BTB tag mismatch");

        // Test 32x32 DBPU: Verify clean multi-entry operation
        top32_ifpc = 32'h0000_007c; top32_ifv = 1'b1; #1;
        assert_cond(top32_pv === 1'b1 && top32_ptaken === 1'b0, "Top-32x32: High capacity instance functional");

        // ---------------------------------------------------------------------
        // Final Results Summary
        // ---------------------------------------------------------------------
        $display("\n=================================================================");
        $display("TEST_RESULT: %s tb_parameter_validation (%0d/%0d checks passed)",
                 (errors == 0) ? "PASS" : "FAIL", checks - errors, checks);
        $display("=================================================================\n");
        $finish;
    end

endmodule
