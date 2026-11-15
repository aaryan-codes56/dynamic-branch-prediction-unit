// =============================================================================
// Testbench : tb_static_predictor
// Test 1    : Static always-not-taken baseline.
// Purpose   : Every prediction must be NOT TAKEN regardless of PC, reset or
//             the history of actual outcomes fed to the update port.
// =============================================================================
`timescale 1ns/1ps
module tb_static_predictor;

    localparam PC_WIDTH = 32;

    reg                 clk = 1'b0;
    reg                 rst = 1'b1;
    reg  [PC_WIDTH-1:0] lookup_pc = 0;
    reg                 update_en = 1'b0;
    reg  [PC_WIDTH-1:0] update_pc = 0;
    reg                 actual_taken = 1'b0;
    wire                predict_taken;
    wire [1:0]          lookup_state;

    static_predictor #(.PC_WIDTH(PC_WIDTH)) dut (
        .clk(clk), .rst(rst),
        .lookup_pc(lookup_pc), .predict_taken(predict_taken),
        .lookup_state(lookup_state),
        .update_en(update_en), .update_pc(update_pc),
        .actual_taken(actual_taken)
    );

    always #5 clk = ~clk;

    integer checks = 0, errors = 0, i, seed = 7;

    task check_nt(input [PC_WIDTH-1:0] pc, input taken_in);
        begin
            checks = checks + 1;
            if (predict_taken !== 1'b0 || lookup_state !== 2'b00) begin
                errors = errors + 1;
                $display("  FAIL pc=%h actual=%0d pred=%b (expected 0)", pc, taken_in, predict_taken);
            end
        end
    endtask

    initial begin
        $dumpfile("simulation/waveforms/tb_static_predictor.vcd");
        $dumpvars(0, tb_static_predictor);
        $display("=== Test 1: static always-not-taken predictor ===");

        // During reset
        @(negedge clk); check_nt(lookup_pc, 0);
        @(negedge clk); rst = 1'b0;

        // Loop pattern T T T T T N, three times, same PC
        for (i = 0; i < 18; i = i + 1) begin
            @(negedge clk);
            lookup_pc = 32'h0000_010c; update_pc = lookup_pc;
            actual_taken = ((i % 6) != 5); update_en = 1'b1;
            #1 check_nt(lookup_pc, actual_taken);
        end

        // Random PCs and random outcomes
        for (i = 0; i < 64; i = i + 1) begin
            @(negedge clk);
            lookup_pc = {$random(seed)} & 32'hffff_fffc; update_pc = lookup_pc;
            actual_taken = $random(seed); update_en = 1'b1;
            #1 check_nt(lookup_pc, actual_taken);
        end
        $display("  first prediction after 82 updates (incl. many taken) = %b", predict_taken);

        @(negedge clk); update_en = 1'b0;
        $display("TEST_RESULT: %s tb_static_predictor (%0d/%0d checks passed)",
                 (errors == 0) ? "PASS" : "FAIL", checks - errors, checks);
        $finish;
    end
endmodule
