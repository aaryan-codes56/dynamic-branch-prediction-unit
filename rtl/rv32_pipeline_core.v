// =============================================================================
// Module      : rv32_pipeline_core
// Project     : DBPU - Dynamic Branch Prediction Unit (Phase II CPU)
// Description : Classic 5-stage in-order RV32I-subset pipeline
//               (IF -> ID -> EX -> MEM -> WB) with the Dynamic Branch
//               Prediction Unit (branch_prediction_top) in the fetch stage.
//
//   Fetch      : every cycle the PC is looked up in the DBPU; the next PC is
//                its pred_next_pc (BTB target if predicted taken and BTB hit,
//                otherwise PC + 4).
//   Resolution : BEQ/BNE are resolved in EX. The prediction made in IF travels
//                with the instruction (IF/ID, ID/EX) and is checked by the
//                DBPU's misprediction unit. On a misprediction `flush` squashes
//                the two younger instructions (in IF/ID and ID/EX) and fetch
//                restarts at ex_correct_pc -> 2-cycle penalty.
//   Data hazards:
//     * forwarding EX/MEM -> EX and MEM/WB -> EX (ALU operands, store data
//       and branch operands)
//     * register file write-through covers WB -> ID
//     * load-use: 1-cycle stall (PC and IF/ID held, bubble into ID/EX)
//   Halt       : ECALL; when it reaches WB the core stops (`halted`).
//
//   Performance counters (stop counting when halted):
//     cycles, instret (instructions retired in WB), branches (resolved in EX),
//     flushes (next-PC mispredictions), dir_mispredicts, stalls (load-use).
//   Cycle accounting identity (checked by the testbench):
//     cycles = instret + 4 + 2*flushes + stalls   (4 = pipeline fill)
// =============================================================================
`timescale 1ns / 1ps

module rv32_pipeline_core #(
    parameter PREDICTOR_TYPE = 2,     // 0 static, 1 one-bit, 2 two-bit
    parameter BHT_ENTRIES    = 16,
    parameter BTB_ENTRIES    = 16,
    parameter IMEM_WORDS     = 256,
    parameter DMEM_WORDS     = 256
) (
    input  wire        clk,
    input  wire        rst,             // synchronous, active-high
    // instruction-memory programming port
    input  wire        prog_we,
    input  wire [31:0] prog_addr,
    input  wire [31:0] prog_data,
    // status and performance counters
    output reg         halted,
    output reg  [31:0] cnt_cycles,
    output reg  [31:0] cnt_instret,
    output reg  [31:0] cnt_branches,
    output reg  [31:0] cnt_flushes,
    output reg  [31:0] cnt_dir_mispredicts,
    output reg  [31:0] cnt_stalls
);

    localparam [31:0] INSTR_BYTES = 32'd4;

    // =========================================================================
    // Pipeline registers
    // =========================================================================
    // IF/ID
    reg        ifid_valid;
    reg [31:0] ifid_pc, ifid_instr, ifid_pred_next_pc;
    reg        ifid_pred_taken;
    // ID/EX
    reg        idex_valid;
    reg [31:0] idex_pc, idex_rs1_val, idex_rs2_val, idex_imm, idex_pred_next_pc;
    reg [4:0]  idex_rs1, idex_rs2, idex_rd;
    reg [3:0]  idex_alu_op;
    reg        idex_alu_src_imm, idex_reg_write, idex_mem_read, idex_mem_write;
    reg        idex_mem_to_reg, idex_is_branch, idex_branch_ne, idex_is_halt;
    reg        idex_pred_taken;
    // EX/MEM
    reg        exmem_valid;
    reg [31:0] exmem_alu, exmem_store_data;
    reg [4:0]  exmem_rd;
    reg        exmem_reg_write, exmem_mem_read, exmem_mem_write, exmem_mem_to_reg;
    reg        exmem_is_halt;
    // MEM/WB
    reg        memwb_valid;
    reg [31:0] memwb_wb_data;
    reg [4:0]  memwb_rd;
    reg        memwb_reg_write, memwb_is_halt;

    reg [31:0] pc;

    // =========================================================================
    // IF stage
    // =========================================================================
    wire [31:0] if_instr;
    rv32_imem #(.WORDS(IMEM_WORDS)) u_imem (
        .clk(clk), .addr(pc), .instr(if_instr),
        .prog_we(prog_we), .prog_addr(prog_addr), .prog_data(prog_data)
    );

    wire        halt_now = memwb_valid & memwb_is_halt;   // ECALL retiring
    wire        active   = ~halted & ~halt_now;            // count / update

    // EX-stage values needed by the DBPU (declared here, driven below)
    wire        ex_branch_valid;
    wire        ex_taken;
    wire [31:0] ex_target;

    wire        pred_valid, pred_taken, pred_target_valid, pred_redirect;
    wire [31:0] pred_target, pred_next_pc, ex_correct_pc;
    wire [1:0]  pred_state;
    wire        ex_dir_mispredict, ex_mispredict, flush;

    branch_prediction_top #(
        .PC_WIDTH(32), .BHT_ENTRIES(BHT_ENTRIES), .BTB_ENTRIES(BTB_ENTRIES),
        .PREDICTOR_TYPE(PREDICTOR_TYPE)
    ) u_dbpu (
        .clk(clk), .rst(rst),
        .if_valid(~halted), .if_pc(pc),
        .pred_valid(pred_valid), .pred_taken(pred_taken),
        .pred_target_valid(pred_target_valid), .pred_target(pred_target),
        .pred_redirect(pred_redirect), .pred_next_pc(pred_next_pc),
        .pred_state(pred_state),
        .ex_valid(ex_branch_valid), .ex_pc(idex_pc),
        .ex_actual_taken(ex_taken), .ex_actual_target(ex_target),
        .ex_pred_taken(idex_pred_taken), .ex_pred_next_pc(idex_pred_next_pc),
        .ex_dir_mispredict(ex_dir_mispredict), .ex_mispredict(ex_mispredict),
        .flush(flush), .ex_correct_pc(ex_correct_pc)
    );

    // =========================================================================
    // ID stage
    // =========================================================================
    wire [4:0]  id_rd, id_rs1, id_rs2;
    wire [31:0] id_imm;
    wire [3:0]  id_alu_op;
    wire        id_alu_src_imm, id_reg_write, id_mem_read, id_mem_write, id_mem_to_reg;
    wire        id_is_branch, id_branch_ne, id_is_halt, id_uses_rs1, id_uses_rs2;

    rv32_decoder u_dec (
        .instr(ifid_instr),
        .rd(id_rd), .rs1(id_rs1), .rs2(id_rs2), .imm(id_imm),
        .alu_op(id_alu_op), .alu_src_imm(id_alu_src_imm),
        .reg_write(id_reg_write), .mem_read(id_mem_read), .mem_write(id_mem_write),
        .mem_to_reg(id_mem_to_reg), .is_branch(id_is_branch), .branch_ne(id_branch_ne),
        .is_halt(id_is_halt), .uses_rs1(id_uses_rs1), .uses_rs2(id_uses_rs2)
    );

    wire [31:0] id_rs1_val, id_rs2_val;
    wire        wb_we = memwb_valid & memwb_reg_write & ~halted;
    rv32_regfile u_rf (
        .clk(clk), .rst(rst),
        .ra1(id_rs1), .ra2(id_rs2), .rd1(id_rs1_val), .rd2(id_rs2_val),
        .we(wb_we), .wa(memwb_rd), .wd(memwb_wb_data)
    );

    // Load-use hazard: a load in EX produces a register the ID instruction reads
    wire load_use = ifid_valid & idex_valid & idex_mem_read & (idex_rd != 5'd0) &
                    ((id_uses_rs1 & (idex_rd == id_rs1)) | (id_uses_rs2 & (idex_rd == id_rs2)));
    wire stall = load_use & ~flush;          // a flush squashes the ID instruction anyway

    // =========================================================================
    // EX stage (forwarding, ALU, branch resolution)
    // =========================================================================
    wire fwd_a_mem = exmem_valid & exmem_reg_write & (exmem_rd != 5'd0) & (exmem_rd == idex_rs1);
    wire fwd_a_wb  = memwb_valid & memwb_reg_write & (memwb_rd != 5'd0) & (memwb_rd == idex_rs1);
    wire fwd_b_mem = exmem_valid & exmem_reg_write & (exmem_rd != 5'd0) & (exmem_rd == idex_rs2);
    wire fwd_b_wb  = memwb_valid & memwb_reg_write & (memwb_rd != 5'd0) & (memwb_rd == idex_rs2);

    wire [31:0] ex_a = fwd_a_mem ? exmem_alu : fwd_a_wb ? memwb_wb_data : idex_rs1_val;
    wire [31:0] ex_b = fwd_b_mem ? exmem_alu : fwd_b_wb ? memwb_wb_data : idex_rs2_val;

    wire [31:0] ex_alu_y;
    rv32_alu u_alu (
        .alu_op(idex_alu_op), .a(ex_a), .b(idex_alu_src_imm ? idex_imm : ex_b), .y(ex_alu_y)
    );

    wire ex_equal = (ex_a == ex_b);
    assign ex_branch_valid = idex_valid & idex_is_branch & active;
    assign ex_taken        = idex_branch_ne ? ~ex_equal : ex_equal;
    assign ex_target       = idex_pc + idex_imm;

    // =========================================================================
    // MEM stage
    // =========================================================================
    wire [31:0] mem_rdata;
    rv32_dmem #(.WORDS(DMEM_WORDS)) u_dmem (
        .clk(clk), .addr(exmem_alu), .rdata(mem_rdata),
        .we(exmem_valid & exmem_mem_write & active), .wdata(exmem_store_data)
    );

    // =========================================================================
    // Sequential: PC and pipeline registers
    // =========================================================================
    always @(posedge clk) begin
        if (rst) begin
            pc          <= 32'd0;
            ifid_valid  <= 1'b0;  ifid_pc <= 32'd0;  ifid_instr <= 32'd0;
            ifid_pred_taken <= 1'b0;  ifid_pred_next_pc <= 32'd0;
            idex_valid  <= 1'b0;
            idex_reg_write <= 1'b0;  idex_mem_read <= 1'b0;  idex_mem_write <= 1'b0;
            idex_is_branch <= 1'b0;  idex_is_halt <= 1'b0;
            exmem_valid <= 1'b0;
            exmem_reg_write <= 1'b0;  exmem_mem_write <= 1'b0;  exmem_mem_read <= 1'b0;
            exmem_is_halt <= 1'b0;
            memwb_valid <= 1'b0;  memwb_reg_write <= 1'b0;  memwb_is_halt <= 1'b0;
        end else if (!halted) begin
            // ---------------- PC ----------------
            if (flush)       pc <= ex_correct_pc;
            else if (!stall) pc <= pred_next_pc;

            // ---------------- IF/ID ----------------
            if (flush) begin
                ifid_valid <= 1'b0;
            end else if (!stall) begin
                ifid_valid        <= 1'b1;
                ifid_pc           <= pc;
                ifid_instr        <= if_instr;
                ifid_pred_taken   <= pred_taken;
                ifid_pred_next_pc <= pred_next_pc;
            end

            // ---------------- ID/EX ----------------
            if (flush || stall || !ifid_valid) begin
                idex_valid     <= 1'b0;          // bubble
                idex_reg_write <= 1'b0;  idex_mem_read <= 1'b0;  idex_mem_write <= 1'b0;
                idex_is_branch <= 1'b0;  idex_is_halt  <= 1'b0;
            end else begin
                idex_valid        <= 1'b1;
                idex_pc           <= ifid_pc;
                idex_rs1_val      <= id_rs1_val;
                idex_rs2_val      <= id_rs2_val;
                idex_imm          <= id_imm;
                idex_rs1          <= id_rs1;
                idex_rs2          <= id_rs2;
                idex_rd           <= id_rd;
                idex_alu_op       <= id_alu_op;
                idex_alu_src_imm  <= id_alu_src_imm;
                idex_reg_write    <= id_reg_write;
                idex_mem_read     <= id_mem_read;
                idex_mem_write    <= id_mem_write;
                idex_mem_to_reg   <= id_mem_to_reg;
                idex_is_branch    <= id_is_branch;
                idex_branch_ne    <= id_branch_ne;
                idex_is_halt      <= id_is_halt;
                idex_pred_taken   <= ifid_pred_taken;
                idex_pred_next_pc <= ifid_pred_next_pc;
            end

            // ---------------- EX/MEM ----------------
            exmem_valid      <= idex_valid;
            exmem_alu        <= ex_alu_y;
            exmem_store_data <= ex_b;
            exmem_rd         <= idex_rd;
            exmem_reg_write  <= idex_valid & idex_reg_write;
            exmem_mem_read   <= idex_valid & idex_mem_read;
            exmem_mem_write  <= idex_valid & idex_mem_write;
            exmem_mem_to_reg <= idex_mem_to_reg;
            exmem_is_halt    <= idex_valid & idex_is_halt;

            // ---------------- MEM/WB ----------------
            memwb_valid     <= exmem_valid;
            memwb_wb_data   <= exmem_mem_to_reg ? mem_rdata : exmem_alu;
            memwb_rd        <= exmem_rd;
            memwb_reg_write <= exmem_valid & exmem_reg_write;
            memwb_is_halt   <= exmem_valid & exmem_is_halt;
        end
    end

    // =========================================================================
    // Halt and performance counters
    // =========================================================================
    always @(posedge clk) begin
        if (rst) begin
            halted <= 1'b0;
            cnt_cycles <= 32'd0;  cnt_instret <= 32'd0;  cnt_branches <= 32'd0;
            cnt_flushes <= 32'd0;  cnt_dir_mispredicts <= 32'd0;  cnt_stalls <= 32'd0;
        end else if (!halted) begin
            cnt_cycles  <= cnt_cycles + 32'd1;
            cnt_instret <= cnt_instret + {31'd0, memwb_valid};
            if (active) begin
                cnt_branches        <= cnt_branches        + {31'd0, ex_branch_valid};
                cnt_flushes         <= cnt_flushes         + {31'd0, flush};
                cnt_dir_mispredicts <= cnt_dir_mispredicts + {31'd0, ex_dir_mispredict};
                cnt_stalls          <= cnt_stalls          + {31'd0, stall};
            end
            if (halt_now) halted <= 1'b1;
        end
    end

endmodule
