// =============================================================================
// Testbench : tb_branch_history_table
// Purpose   : Verify the parameterized BHT on its own (Tests 6 and 10).
// Config    : ENTRIES = 8, STATE_BITS = 2, INIT_STATE = 2'b10 (a non-zero
//             value, to prove the INIT_STATE parameter is honoured).
// Checks    : reset initialisation of every entry, index calculation
//             (pc[4:2] for 8 entries), first/last entry boundaries, upper PC
//             bits ignored (aliasing), wr_en = 0 does not write, both read
//             ports, read-during-write returns the old value, mid-run reset.
// =============================================================================
`timescale 1ns/1ps
module tb_branch_history_table;

    localparam PC_WIDTH   = 32;
    localparam ENTRIES    = 8;
    localparam STATE_BITS = 2;
    localparam [1:0] INIT = 2'b10;

    reg                   clk = 1'b0;
    reg                   rst = 1'b1;
    reg  [PC_WIDTH-1:0]   lookup_pc = 0;
    reg  [PC_WIDTH-1:0]   update_pc = 0;
    reg                   wr_en = 1'b0;
    reg  [STATE_BITS-1:0] wr_state = 0;
    wire [STATE_BITS-1:0] lookup_state;
    wire [STATE_BITS-1:0] update_state;

    branch_history_table #(
        .PC_WIDTH(PC_WIDTH), .ENTRIES(ENTRIES),
        .STATE_BITS(STATE_BITS), .INIT_STATE(INIT)
    ) dut (
        .clk(clk), .rst(rst),
        .lookup_pc(lookup_pc), .lookup_state(lookup_state),
        .update_pc(update_pc), .update_state(update_state),
        .wr_en(wr_en), .wr_state(wr_state)
    );

    always #5 clk = ~clk;

    integer checks = 0, errors = 0, i;

    task write_entry(input [31:0] pc, input [1:0] value);
        begin
            @(negedge clk);
            update_pc = pc; wr_state = value; wr_en = 1'b1;
            @(negedge clk);
            wr_en = 1'b0;
        end
    endtask

    task expect_lookup(input [31:0] pc, input [1:0] exp, input [8*48-1:0] what);
        begin
            lookup_pc = pc; #1;
            checks = checks + 1;
            if (lookup_state !== exp) begin
                errors = errors + 1;
                $display("  FAIL [%0s] pc=%h idx=%0d state=%b expected=%b", what, pc, pc[4:2], lookup_state, exp);
            end else
                $display("  ok   [%0s] pc=%h idx=%0d state=%b", what, pc, pc[4:2], lookup_state);
        end
    endtask

    task expect_update_port(input [31:0] pc, input [1:0] exp, input [8*48-1:0] what);
        begin
            update_pc = pc; #1;
            checks = checks + 1;
            if (update_state !== exp) begin
                errors = errors + 1;
                $display("  FAIL [%0s] update port pc=%h state=%b expected=%b", what, pc, update_state, exp);
            end else
                $display("  ok   [%0s] update port pc=%h state=%b", what, pc, update_state);
        end
    endtask

    initial begin
        $dumpfile("simulation/waveforms/tb_branch_history_table.vcd");
        $dumpvars(0, tb_branch_history_table);
        $display("=== BHT unit test (8 entries, INIT_STATE=10) ===");

        @(negedge clk); @(negedge clk); rst = 1'b0;

        // Reset initialisation
        for (i = 0; i < ENTRIES; i = i + 1)
            expect_lookup(4*i, INIT, "reset value = INIT_STATE");

        // Write a distinct value into every entry: entry i <- i[1:0]
        for (i = 0; i < ENTRIES; i = i + 1)
            write_entry(32'h0000_2000 + 4*i, i[1:0]);
        for (i = 0; i < ENTRIES; i = i + 1)
            expect_lookup(32'h0000_2000 + 4*i, i[1:0], "entry holds written value");

        // Boundaries: index 0 and index ENTRIES-1
        expect_lookup(32'h0000_0000, 2'd0, "first entry (idx 0)");
        expect_lookup(32'h0000_001c, 2'd3, "last entry (idx 7)");
        // Byte-offset bits [1:0] are ignored
        expect_lookup(32'h0000_001f, 2'd3, "pc[1:0] ignored");
        // Upper bits ignored -> aliasing: 0x20 maps to idx 0, 0xFFFF_FFFC to idx 7
        expect_lookup(32'h0000_0020, 2'd0, "0x20 aliases idx 0");
        expect_lookup(32'hffff_fffc, 2'd3, "0xfffffffc aliases idx 7");

        // Second read port
        expect_update_port(32'h0000_0008, 2'd2, "update port reads idx 2");

        // wr_en = 0 must not write
        @(negedge clk); update_pc = 32'h0000_0004; wr_state = 2'b11; wr_en = 1'b0;
        @(negedge clk);
        expect_lookup(32'h0000_0004, 2'd1, "wr_en=0 does not write");

        // Read during write: lookup sees old value until the clock edge
        @(negedge clk);
        update_pc = 32'h0000_000c; wr_state = 2'b00; wr_en = 1'b1;
        expect_lookup(32'h0000_000c, 2'd3, "read-during-write sees old value");
        @(posedge clk); #1 wr_en = 1'b0;
        expect_lookup(32'h0000_000c, 2'd0, "new value visible after edge");

        // Mid-run reset restores every entry
        @(negedge clk); rst = 1'b1; @(negedge clk); rst = 1'b0;
        for (i = 0; i < ENTRIES; i = i + 1)
            expect_lookup(4*i, INIT, "after reset = INIT_STATE");

        $display("TEST_RESULT: %s tb_branch_history_table (%0d/%0d checks passed)",
                 (errors == 0) ? "PASS" : "FAIL", checks - errors, checks);
        $finish;
    end
endmodule
