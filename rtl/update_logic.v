// =============================================================================
// Module      : update_logic
// Project     : DBPU - Dynamic Branch Prediction Unit
// Description : Next-state (training) logic for an N-bit saturating counter.
//
//   Purely combinational. Given the current counter value and the actual
//   branch outcome resolved in EX, it produces the value to write back into
//   the Branch History Table.
//
//     actual_taken = 1 : increment, but stop (saturate) at the maximum value
//     actual_taken = 0 : decrement, but stop (saturate) at zero
//
//   STATE_BITS = 2 (2-bit predictor) gives the classic table:
//       taken     : 00->01, 01->10, 10->11, 11->11
//       not taken : 11->10, 10->01, 01->00, 00->00
//
//   STATE_BITS = 1 (1-bit predictor) degenerates to "remember the last
//   outcome":  taken -> 1, not taken -> 0.
//
//   The counter never wraps around (11 + taken stays 11, 00 + not-taken
//   stays 00); this is verified exhaustively in tb_two_bit_predictor.v.
// =============================================================================
`timescale 1ns / 1ps

module update_logic #(
    parameter STATE_BITS = 2
) (
    input  wire [STATE_BITS-1:0] current_state,
    input  wire                  actual_taken,
    output reg  [STATE_BITS-1:0] next_state
);

    localparam [STATE_BITS-1:0] STATE_MAX = {STATE_BITS{1'b1}}; // e.g. 2'b11
    localparam [STATE_BITS-1:0] STATE_MIN = {STATE_BITS{1'b0}}; // e.g. 2'b00

    always @(*) begin
        next_state = current_state;                  // default: hold
        if (actual_taken) begin
            if (current_state != STATE_MAX)
                next_state = current_state + 1'b1;   // move toward taken
        end else begin
            if (current_state != STATE_MIN)
                next_state = current_state - 1'b1;   // move toward not taken
        end
    end

endmodule
