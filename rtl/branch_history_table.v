// =============================================================================
// Module      : branch_history_table
// Project     : DBPU - Dynamic Branch Prediction Unit
// Description : Parameterized, untagged Branch History Table (BHT).
//
//   * ENTRIES entries, each STATE_BITS wide (1 = 1-bit predictor,
//     2 = 2-bit saturating counter).
//   * Indexed by the low-order bits of the branch PC, ignoring bits [1:0]
//     because RV32I/MIPS instructions are 4-byte aligned:
//         index = pc[INDEX_BITS+1 : 2]
//   * Two asynchronous (combinational) read ports:
//         - lookup port : used by the IF stage to make a prediction
//         - update port : used by the EX stage to read the current state of
//                         the resolving branch (read-modify-write)
//   * One synchronous write port (written on the rising clock edge).
//   * Synchronous active-high reset sets every entry to INIT_STATE.
//
//   The table is UNTAGGED: two branches whose PCs share the same index bits
//   share (alias to) the same entry. This is intentional and is the standard
//   textbook BHT organization; aliasing is demonstrated in the testbench.
//
//   Read-during-write: if the lookup port reads the entry that is being
//   written in the same cycle, it sees the OLD value (the write takes effect
//   at the clock edge).
// =============================================================================
`timescale 1ns / 1ps

module branch_history_table #(
    parameter PC_WIDTH   = 32,             // width of the program counter
    parameter ENTRIES    = 16,             // number of entries (power of 2)
    parameter STATE_BITS = 2,              // bits per entry
    parameter [STATE_BITS-1:0] INIT_STATE = {STATE_BITS{1'b0}} // reset value
) (
    input  wire                  clk,
    input  wire                  rst,            // synchronous, active-high

    // Lookup read port (IF stage)
    input  wire [PC_WIDTH-1:0]   lookup_pc,
    output wire [STATE_BITS-1:0] lookup_state,

    // Update read port (EX stage, read current state before modifying it)
    input  wire [PC_WIDTH-1:0]   update_pc,
    output wire [STATE_BITS-1:0] update_state,

    // Write port (EX stage)
    input  wire                  wr_en,
    input  wire [STATE_BITS-1:0] wr_state
);

    // Number of PC bits used to select an entry.
    // Clamped to minimum 1 for ENTRIES == 1 (where $clog2(1) == 0) to avoid illegal part-selects.
    localparam INDEX_BITS = (ENTRIES > 1) ? $clog2(ENTRIES) : 1;
    // Instructions are word aligned, so PC bits [1:0] are always 00.
    localparam ALIGN_BITS = 2;

    // State storage (sized to exactly ENTRIES)
    reg [STATE_BITS-1:0] table_mem [0:ENTRIES-1];

    // BHT_HIGH clamped to avoid illegal part-selects if index range exceeds PC_WIDTH
    localparam BHT_HIGH = (INDEX_BITS + ALIGN_BITS - 1 < PC_WIDTH) ?
                          (INDEX_BITS + ALIGN_BITS - 1) :
                          ((PC_WIDTH > ALIGN_BITS) ? PC_WIDTH - 1 : ALIGN_BITS);

    // Index calculation: for ENTRIES == 1, index is tied to 0; otherwise extracted from PC.
    wire [INDEX_BITS-1:0] lookup_idx = (ENTRIES > 1) ? lookup_pc[BHT_HIGH:ALIGN_BITS] : {INDEX_BITS{1'b0}};
    wire [INDEX_BITS-1:0] update_idx = (ENTRIES > 1) ? update_pc[BHT_HIGH:ALIGN_BITS] : {INDEX_BITS{1'b0}};

    // Combinational read ports
    assign lookup_state = table_mem[lookup_idx];
    assign update_state = table_mem[update_idx];

    // Synchronous reset / write
    integer i;
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < ENTRIES; i = i + 1)
                table_mem[i] <= INIT_STATE;
        end else if (wr_en) begin
            table_mem[update_idx] <= wr_state;
        end
    end

    // Parameter validation (simulation / formal check)
    // synthesis translate_off
    initial begin
        if (ENTRIES < 1 || (ENTRIES & (ENTRIES - 1)) != 0) begin
            $display("ERROR: [%m] ENTRIES (%0d) must be a power of 2 >= 1 (1, 2, 4, 8, ...)", ENTRIES);
            $finish;
        end
        if (PC_WIDTH <= ALIGN_BITS) begin
            $display("ERROR: [%m] PC_WIDTH (%0d) must be greater than ALIGN_BITS (%0d)", PC_WIDTH, ALIGN_BITS);
            $finish;
        end
        if (INDEX_BITS + ALIGN_BITS > PC_WIDTH) begin
            $display("ERROR: [%m] Table index requires bits [%0d:2], which exceeds PC_WIDTH (%0d)", INDEX_BITS + ALIGN_BITS - 1, PC_WIDTH);
            $finish;
        end
        if (STATE_BITS < 1) begin
            $display("ERROR: [%m] STATE_BITS (%0d) must be >= 1", STATE_BITS);
            $finish;
        end
    end
    // synthesis translate_on

endmodule
