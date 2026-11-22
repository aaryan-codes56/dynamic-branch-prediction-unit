// =============================================================================
// Module      : rv32_alu
// Project     : DBPU - Dynamic Branch Prediction Unit (Phase II CPU)
// Description : 32-bit ALU for the RV32I subset used by rv32_pipeline_core.
//               Purely combinational.
// =============================================================================
`timescale 1ns / 1ps

module rv32_alu (
    input  wire [3:0]  alu_op,
    input  wire [31:0] a,
    input  wire [31:0] b,
    output reg  [31:0] y
);

    localparam [3:0] ALU_ADD = 4'd0, ALU_SUB = 4'd1, ALU_AND = 4'd2, ALU_OR  = 4'd3,
                     ALU_XOR = 4'd4, ALU_SLT = 4'd5, ALU_SLL = 4'd6, ALU_SRL = 4'd7;

    always @(*) begin
        case (alu_op)
            ALU_ADD: y = a + b;
            ALU_SUB: y = a - b;
            ALU_AND: y = a & b;
            ALU_OR : y = a | b;
            ALU_XOR: y = a ^ b;
            ALU_SLT: y = {31'd0, $signed(a) < $signed(b)};
            ALU_SLL: y = a << b[4:0];
            ALU_SRL: y = a >> b[4:0];
            default: y = a + b;
        endcase
    end

endmodule
