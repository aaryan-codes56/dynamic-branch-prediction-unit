// =============================================================================
// Module      : branch_target_buffer
// Project     : DBPU - Dynamic Branch Prediction Unit
// Description : Direct-mapped, tagged Branch Target Buffer (BTB).
//
//   Each entry stores { valid, tag, target }.
//       index = pc[INDEX_BITS+1 : 2]
//       tag   = pc[PC_WIDTH-1  : INDEX_BITS+ALIGN_BITS]
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

    // Number of PC bits used to select an entry.
    // Clamped to minimum 1 for ENTRIES == 1 (where $clog2(1) == 0) to avoid illegal part-selects.
    localparam INDEX_BITS = (ENTRIES > 1) ? $clog2(ENTRIES) : 1;
    localparam ALIGN_BITS = 2;

    // When ENTRIES == 1, no index bits are used; tag covers PC[PC_WIDTH-1:ALIGN_BITS].
    // Clamped to at least 1 to prevent zero or negative vector widths.
    localparam TAG_BITS_RAW = (ENTRIES > 1) ? (PC_WIDTH - INDEX_BITS - ALIGN_BITS)
                                            : (PC_WIDTH - ALIGN_BITS);
    localparam TAG_BITS     = (TAG_BITS_RAW > 0) ? TAG_BITS_RAW : 1;

    // Storage arrays (sized to exactly ENTRIES)
    reg                valid_mem  [0:ENTRIES-1];
    reg [TAG_BITS-1:0] tag_mem    [0:ENTRIES-1];
    reg [PC_WIDTH-1:0] target_mem [0:ENTRIES-1];

    // Field extraction: for ENTRIES == 1, index is tied to 0, tag covers all non-alignment bits.
    // TAG_LOW is clamped to ALIGN_BITS if index bits exceed PC width to avoid out-of-order part selects during elaboration.
    localparam TAG_LOW = (PC_WIDTH > (INDEX_BITS + ALIGN_BITS)) ? (INDEX_BITS + ALIGN_BITS) : ALIGN_BITS;

    wire [INDEX_BITS-1:0] lookup_idx = (ENTRIES > 1) ? lookup_pc[INDEX_BITS+ALIGN_BITS-1:ALIGN_BITS] : {INDEX_BITS{1'b0}};
    wire [TAG_BITS-1:0]   lookup_tag = (ENTRIES > 1) ? lookup_pc[PC_WIDTH-1:TAG_LOW] : lookup_pc[PC_WIDTH-1:ALIGN_BITS];
    wire [INDEX_BITS-1:0] update_idx = (ENTRIES > 1) ? update_pc[INDEX_BITS+ALIGN_BITS-1:ALIGN_BITS] : {INDEX_BITS{1'b0}};
    wire [TAG_BITS-1:0]   update_tag = (ENTRIES > 1) ? update_pc[PC_WIDTH-1:TAG_LOW] : update_pc[PC_WIDTH-1:ALIGN_BITS];

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
        if (ENTRIES > 1 && (INDEX_BITS + ALIGN_BITS >= PC_WIDTH)) begin
            $display("ERROR: [%m] INDEX_BITS + ALIGN_BITS (%0d) must be strictly less than PC_WIDTH (%0d) to have a valid tag", INDEX_BITS + ALIGN_BITS, PC_WIDTH);
            $finish;
        end
    end
    // synthesis translate_on

endmodule
