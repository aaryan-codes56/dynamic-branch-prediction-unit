// =============================================================================
// Module      : branch_target_buffer
// Project     : DBPU - Dynamic Branch Prediction Unit
// Description : Direct-mapped, tagged Branch Target Buffer (BTB).
//
//   Each entry stores { valid, tag, target }.
//       index = pc[INDEX_BITS+1 : 2]
//       tag   = pc[PC_WIDTH-1  : INDEX_BITS+2]
//   Lookup (IF stage, combinational): hit = valid[index] && tag[index]==tag.
//   On a hit, lookup_target is the stored target address.
//   Update (EX stage, rising clock edge): writes {1, tag, target} into the
//   indexed entry, replacing whatever was there (direct-mapped replacement).
//   Unlike the BHT, the BTB is TAGGED, so a lookup never returns the target
//   of a different branch that happens to share the same index.
//   Synchronous active-high reset clears all valid bits (and tag/target
//   fields, for clean waveforms).
// =============================================================================
`timescale 1ns / 1ps

module branch_target_buffer #(
    parameter PC_WIDTH = 32,
    parameter ENTRIES  = 16
) (
    input  wire                clk,
    input  wire                rst,

    // Lookup (IF stage)
    input  wire [PC_WIDTH-1:0] lookup_pc,
    output wire                lookup_hit,
    output wire [PC_WIDTH-1:0] lookup_target,

    // Update (EX stage)
    input  wire                update_en,
    input  wire [PC_WIDTH-1:0] update_pc,
    input  wire [PC_WIDTH-1:0] update_target
);

    localparam INDEX_BITS = $clog2(ENTRIES);
    localparam ALIGN_BITS = 2;
    localparam TAG_BITS   = PC_WIDTH - INDEX_BITS - ALIGN_BITS;

    reg                valid_mem  [0:ENTRIES-1];
    reg [TAG_BITS-1:0] tag_mem    [0:ENTRIES-1];
    reg [PC_WIDTH-1:0] target_mem [0:ENTRIES-1];

    // Field extraction
    wire [INDEX_BITS-1:0] lookup_idx = lookup_pc[INDEX_BITS+ALIGN_BITS-1:ALIGN_BITS];
    wire [TAG_BITS-1:0]   lookup_tag = lookup_pc[PC_WIDTH-1:INDEX_BITS+ALIGN_BITS];
    wire [INDEX_BITS-1:0] update_idx = update_pc[INDEX_BITS+ALIGN_BITS-1:ALIGN_BITS];
    wire [TAG_BITS-1:0]   update_tag = update_pc[PC_WIDTH-1:INDEX_BITS+ALIGN_BITS];

    // Combinational lookup
    assign lookup_hit    = valid_mem[lookup_idx] && (tag_mem[lookup_idx] == lookup_tag);
    assign lookup_target = target_mem[lookup_idx];

    // Synchronous reset / update
    integer i;
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < ENTRIES; i = i + 1) begin
                valid_mem[i]  <= 1'b0;
                tag_mem[i]    <= {TAG_BITS{1'b0}};
                target_mem[i] <= {PC_WIDTH{1'b0}};
            end
        end else if (update_en) begin
            valid_mem[update_idx]  <= 1'b1;
            tag_mem[update_idx]    <= update_tag;
            target_mem[update_idx] <= update_target;
        end
    end

endmodule
