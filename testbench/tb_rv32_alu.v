// =============================================================================
// Testbench : tb_rv32_alu
// Purpose   : Self-checking unit test of rtl/rv32_alu.v (Phase II CPU).
//             For each of the 8 operations (ADD, SUB, AND, OR, XOR, SLT, SLL,
//             SRL) it applies corner cases and 100 random vectors, and compares
//             the ALU output with an expected value computed independently in
//             the testbench. SLT must be a SIGNED comparison; SRL is logical.
// =============================================================================
`timescale 1ns/1ps
module tb_rv32_alu;

    localparam [3:0] ALU_ADD = 4'd0, ALU_SUB = 4'd1, ALU_AND = 4'd2, ALU_OR  = 4'd3,
                     ALU_XOR = 4'd4, ALU_SLT = 4'd5, ALU_SLL = 4'd6, ALU_SRL = 4'd7;

    reg  [3:0]  op;
    reg  [31:0] a, b;
    wire [31:0] y;

    rv32_alu dut (.alu_op(op), .a(a), .b(b), .y(y));

    integer i, checks = 0, errors = 0, seed = 2026;
    reg [31:0] expected;

    task run(input [3:0] o, input [31:0] x, input [31:0] z);
        begin
            op = o; a = x; b = z; #1;
            case (o)
                ALU_ADD: expected = x + z;
                ALU_SUB: expected = x - z;
                ALU_AND: expected = x & z;
                ALU_OR : expected = x | z;
                ALU_XOR: expected = x ^ z;
                ALU_SLT: expected = ($signed(x) < $signed(z)) ? 32'd1 : 32'd0;
                ALU_SLL: expected = x << z[4:0];
                ALU_SRL: expected = x >> z[4:0];
                default: expected = x + z;
            endcase
            checks = checks + 1;
            if (y !== expected) begin
                errors = errors + 1;
                $display("  FAIL op=%0d a=%h b=%h y=%h expected=%h", o, x, z, y, expected);
            end
        end
    endtask

    initial begin
        $display("=== RV32I ALU unit test ===");
        for (i = 0; i < 8; i = i + 1) begin
            run(i, 32'h0000_0000, 32'h0000_0000);
            run(i, 32'hffff_ffff, 32'h0000_0001);   // -1 vs 1 (signed SLT = 1)
            run(i, 32'h8000_0000, 32'h7fff_ffff);   // most negative vs most positive
            run(i, 32'h7fff_ffff, 32'h8000_0000);   // overflow on ADD/SUB
            run(i, 32'h1234_5678, 32'd31);          // largest shift amount
        end
        for (i = 0; i < 800; i = i + 1)
            run(i % 8, $random(seed), $random(seed));
        $display("TEST_RESULT: %s tb_rv32_alu (%0d/%0d checks passed)",
                 (errors == 0) ? "PASS" : "FAIL", checks - errors, checks);
        $finish;
    end
endmodule
