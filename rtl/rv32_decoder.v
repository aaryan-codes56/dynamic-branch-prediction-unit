// =============================================================================
// Module      : rv32_decoder
// Project     : DBPU - Dynamic Branch Prediction Unit (Phase II CPU)
// Description : ID-stage instruction decoder / main control for the RV32I subset
//                 R-type : ADD SUB AND OR XOR SLT SLL SRL
//                 I-type : ADDI ANDI ORI XORI SLTI SLLI SRLI
//                 LW, SW, BEQ, BNE, ECALL (used as "halt")
//               Any other encoding is treated as a NOP (no state change).
//               Purely combinational.
// =============================================================================
`timescale 1ns / 1ps

module rv32_decoder (
    input  wire [31:0] instr,
    output wire [4:0]  rd,
    output wire [4:0]  rs1,
    output wire [4:0]  rs2,
    output reg  [31:0] imm,
    output reg  [3:0]  alu_op,
    output reg         alu_src_imm,   // ALU operand B = immediate
    output reg         reg_write,
    output reg         mem_read,
    output reg         mem_write,
    output reg         mem_to_reg,
    output reg         is_branch,
    output reg         branch_ne,     // 1 = BNE, 0 = BEQ
    output reg         is_halt,       // ECALL
    output reg         uses_rs1,
    output reg         uses_rs2
);

    localparam [6:0] OP_R = 7'b0110011, OP_I = 7'b0010011, OP_LOAD = 7'b0000011,
                     OP_STORE = 7'b0100011, OP_BRANCH = 7'b1100011, OP_SYSTEM = 7'b1110011;
    localparam [3:0] ALU_ADD = 4'd0, ALU_SUB = 4'd1, ALU_AND = 4'd2, ALU_OR  = 4'd3,
                     ALU_XOR = 4'd4, ALU_SLT = 4'd5, ALU_SLL = 4'd6, ALU_SRL = 4'd7;
    localparam [31:0] ECALL = 32'h0000_0073;

    wire [6:0] opcode = instr[6:0];
    wire [2:0] funct3 = instr[14:12];
    wire [6:0] funct7 = instr[31:25];

    assign rd  = instr[11:7];
    assign rs1 = instr[19:15];
    assign rs2 = instr[24:20];

    wire [31:0] imm_i = {{20{instr[31]}}, instr[31:20]};
    wire [31:0] imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    wire [31:0] imm_b = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};

    always @(*) begin
        // default: NOP
        imm = 32'd0;  alu_op = ALU_ADD;  alu_src_imm = 1'b0;
        reg_write = 1'b0;  mem_read = 1'b0;  mem_write = 1'b0;  mem_to_reg = 1'b0;
        is_branch = 1'b0;  branch_ne = 1'b0;  is_halt = 1'b0;
        uses_rs1 = 1'b0;   uses_rs2 = 1'b0;

        case (opcode)
            OP_R: begin
                uses_rs1 = 1'b1;  uses_rs2 = 1'b1;  reg_write = 1'b1;
                case (funct3)
                    3'b000: alu_op = (funct7 == 7'b0100000) ? ALU_SUB : ALU_ADD;
                    3'b111: alu_op = ALU_AND;
                    3'b110: alu_op = ALU_OR;
                    3'b100: alu_op = ALU_XOR;
                    3'b010: alu_op = ALU_SLT;
                    3'b001: alu_op = ALU_SLL;
                    3'b101: alu_op = ALU_SRL;
                    default: begin reg_write = 1'b0; uses_rs1 = 1'b0; uses_rs2 = 1'b0; end
                endcase
            end
            OP_I: begin
                uses_rs1 = 1'b1;  reg_write = 1'b1;  alu_src_imm = 1'b1;  imm = imm_i;
                case (funct3)
                    3'b000: alu_op = ALU_ADD;
                    3'b111: alu_op = ALU_AND;
                    3'b110: alu_op = ALU_OR;
                    3'b100: alu_op = ALU_XOR;
                    3'b010: alu_op = ALU_SLT;
                    3'b001: begin alu_op = ALU_SLL; imm = {27'd0, instr[24:20]}; end
                    3'b101: begin alu_op = ALU_SRL; imm = {27'd0, instr[24:20]}; end
                    default: begin reg_write = 1'b0; uses_rs1 = 1'b0; end
                endcase
            end
            OP_LOAD: if (funct3 == 3'b010) begin
                uses_rs1 = 1'b1;  reg_write = 1'b1;  mem_read = 1'b1;  mem_to_reg = 1'b1;
                alu_src_imm = 1'b1;  imm = imm_i;
            end
            OP_STORE: if (funct3 == 3'b010) begin
                uses_rs1 = 1'b1;  uses_rs2 = 1'b1;  mem_write = 1'b1;
                alu_src_imm = 1'b1;  imm = imm_s;
            end
            OP_BRANCH: if (funct3 == 3'b000 || funct3 == 3'b001) begin
                uses_rs1 = 1'b1;  uses_rs2 = 1'b1;  is_branch = 1'b1;
                branch_ne = funct3[0];  imm = imm_b;
            end
            OP_SYSTEM: if (instr == ECALL) is_halt = 1'b1;
            default: ;
        endcase
    end

endmodule
