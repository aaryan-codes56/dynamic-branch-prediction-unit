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
    localparam INDEX_BITS = $clog2(ENTRIES);
    // Instructions are word aligned, so PC bits [1:0] are always 00.
    localparam ALIGN_BITS = 2;

    // State storage
    reg [STATE_BITS-1:0] table_mem [0:ENTRIES-1];

    // Index calculation
    wire [INDEX_BITS-1:0] lookup_idx = lookup_pc[INDEX_BITS+ALIGN_BITS-1:ALIGN_BITS];
    wire [INDEX_BITS-1:0] update_idx = update_pc[INDEX_BITS+ALIGN_BITS-1:ALIGN_BITS];

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

endmodule
