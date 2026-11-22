// =============================================================================
// Testbench : tb_rv32_pipeline
// Purpose   : Phase II system test. Runs every program listed in
//             programs/build/programs.list (built by scripts/build_programs.py)
//             on three copies of rv32_pipeline_core, one per predictor
//             (0 static, 1 one-bit, 2 two-bit), and checks after each run:
//               * all 31 architectural registers  == reference ISS
//               * all 256 data-memory words        == reference ISS
//               * instructions retired             == reference ISS
//               * cycles == instret + 4 + 2*flushes + stalls
//             Performance counters are written to a CSV file
//             (default analysis/results/cpu_results.csv, override with +OUT=).
//             +DUMP writes simulation/waveforms/tb_rv32_pipeline.vcd.
// =============================================================================
`timescale 1ns/1ps

// -----------------------------------------------------------------------------
// One CPU + its checker
// -----------------------------------------------------------------------------
module cpu_harness #(
    parameter TYPE = 2
) (
    input wire clk,
    input wire rst
);
    localparam IMEM_WORDS = 256, DMEM_WORDS = 256;
    localparam [31:0] NOP = 32'h0000_0013;

    wire        halted;
    wire [31:0] cycles, instret, branches, flushes, dir_miss, stalls;

    rv32_pipeline_core #(.PREDICTOR_TYPE(TYPE)) core (
        .clk(clk), .rst(rst),
        .prog_we(1'b0), .prog_addr(32'd0), .prog_data(32'd0),
        .halted(halted),
        .cnt_cycles(cycles), .cnt_instret(instret), .cnt_branches(branches),
        .cnt_flushes(flushes), .cnt_dir_mispredicts(dir_miss), .cnt_stalls(stalls)
    );

    reg [31:0] exp_state [0:32+DMEM_WORDS];   // 32 regs, 256 dmem words, instret
    integer i, checks = 0, errors = 0;

    task load(input [8*256-1:0] hexfile);
        begin
            for (i = 0; i < IMEM_WORDS; i = i + 1) core.u_imem.mem[i] = NOP;
            for (i = 0; i < DMEM_WORDS; i = i + 1) core.u_dmem.mem[i] = 32'd0;
            $readmemh(hexfile, core.u_imem.mem);
        end
    endtask

    task chk(input cond, input [8*48-1:0] what, input [31:0] got, input [31:0] exp);
        begin
            checks = checks + 1;
            if (!cond) begin
                errors = errors + 1;
                if (errors <= 20)
                    $display("  FAIL type=%0d [%0s] got=%h expected=%h", TYPE, what, got, exp);
            end
        end
    endtask

    task check(input [8*256-1:0] expfile, input [8*64-1:0] name, input integer fd);
        integer e0;
        reg [8*16-1:0] label;
        begin
            e0 = errors;
            $readmemh(expfile, exp_state);
            for (i = 1; i < 32; i = i + 1)
                chk(core.u_rf.regs[i] === exp_state[i], "register", core.u_rf.regs[i], exp_state[i]);
            for (i = 0; i < DMEM_WORDS; i = i + 1)
                chk(core.u_dmem.mem[i] === exp_state[32+i], "data memory", core.u_dmem.mem[i], exp_state[32+i]);
            chk(instret === exp_state[32+DMEM_WORDS], "instructions retired", instret, exp_state[32+DMEM_WORDS]);
            chk(cycles === instret + 4 + 2*flushes + stalls, "cycle accounting", cycles,
                instret + 4 + 2*flushes + stalls);
            label = (TYPE == 0) ? "static" : (TYPE == 1) ? "one_bit" : "two_bit";
            $display("  %-16s %-8s cycles=%6d instret=%6d CPI=%0.3f branches=%5d flushes=%5d dir_miss=%5d stalls=%4d  %0s",
                     name, label, cycles, instret, $itor(cycles) / $itor(instret), branches,
                     flushes, dir_miss, stalls, (errors == e0) ? "OK" : "MISMATCH");
            $fdisplay(fd, "%0s,%0s,%0d,%0d,%0.4f,%0d,%0d,%0d,%0d", name, label, cycles, instret,
                      $itor(cycles) / $itor(instret), branches, flushes, dir_miss, stalls);
        end
    endtask
endmodule

// -----------------------------------------------------------------------------
// Top
// -----------------------------------------------------------------------------
module tb_rv32_pipeline;

    localparam MAX_CYCLES = 200000;

    reg clk = 1'b0;
    reg rst = 1'b1;
    always #5 clk = ~clk;

    cpu_harness #(.TYPE(0)) h_static (.clk(clk), .rst(rst));
    cpu_harness #(.TYPE(1)) h_one    (.clk(clk), .rst(rst));
    cpu_harness #(.TYPE(2)) h_two    (.clk(clk), .rst(rst));

    integer fl, fo, r, n_prog = 0, waited, total_checks, total_errors;
    reg [8*64-1:0]  name;
    reg [8*256-1:0] hexf, expf, outf;

    initial begin
        if (!$value$plusargs("OUT=%s", outf)) outf = "analysis/results/cpu_results.csv";
        if ($test$plusargs("DUMP")) begin
            $dumpfile("simulation/waveforms/tb_rv32_pipeline.vcd");
            $dumpvars(0, tb_rv32_pipeline.h_two.core);
        end
        fl = $fopen("programs/build/programs.list", "r");
        if (fl == 0) begin
            $display("ERROR: programs/build/programs.list not found (run: python3 scripts/build_programs.py)");
            $display("TEST_RESULT: FAIL tb_rv32_pipeline (no programs)");
            $finish;
        end
        fo = $fopen(outf, "w");
        $fdisplay(fo, "program,predictor,cycles,instret,cpi,branches,flushes,dir_mispredicts,stalls");
        $display("=== Phase II: RV32I 5-stage pipeline with DBPU ===");

        while (!$feof(fl)) begin
            r = $fscanf(fl, "%s\n", name);
            if (r == 1) begin
                $sformat(hexf, "programs/build/%0s.hex", name);
                $sformat(expf, "programs/build/%0s.exp", name);
                @(negedge clk);
                rst = 1'b1;
                h_static.load(hexf);  h_one.load(hexf);  h_two.load(hexf);
                repeat (2) @(negedge clk);
                rst = 1'b0;
                waited = 0;
                while (!(h_static.halted && h_one.halted && h_two.halted) && waited < MAX_CYCLES) begin
                    @(negedge clk);
                    waited = waited + 1;
                end
                if (waited >= MAX_CYCLES)
                    $display("  FAIL %0s: timeout (did not halt)", name);
                h_static.check(expf, name, fo);
                h_one.check(expf, name, fo);
                h_two.check(expf, name, fo);
                n_prog = n_prog + 1;
            end
        end
        $fclose(fl);
        $fclose(fo);

        total_checks = h_static.checks + h_one.checks + h_two.checks;
        total_errors = h_static.errors + h_one.errors + h_two.errors + (waited >= MAX_CYCLES);
        $display("  %0d programs x 3 predictors, results written to %0s", n_prog, outf);
        $display("TEST_RESULT: %s tb_rv32_pipeline (%0d/%0d checks passed)",
                 (total_errors == 0 && n_prog > 0) ? "PASS" : "FAIL",
                 total_checks - total_errors, total_checks);
        $finish;
    end
endmodule
