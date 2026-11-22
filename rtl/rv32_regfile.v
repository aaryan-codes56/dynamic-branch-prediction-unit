// =============================================================================
// Module      : rv32_regfile
// Project     : DBPU - Dynamic Branch Prediction Unit (Phase II CPU)
// Description : 32 x 32-bit register file, x0 hard-wired to zero.
//               Two combinational read ports with write-through bypass: an ID
//               stage read of the register being written by WB in the same
//               cycle returns the new value. One synchronous write port.
//               Synchronous active-high reset clears all registers.
// =============================================================================
`timescale 1ns / 1ps

module rv32_regfile (
    input  wire        clk,
    input  wire        rst,
    input  wire [4:0]  ra1,
    input  wire [4:0]  ra2,
    output wire [31:0] rd1,
    output wire [31:0] rd2,
    input  wire        we,
    input  wire [4:0]  wa,
    input  wire [31:0] wd
);

    reg [31:0] regs [0:31];

    assign rd1 = (ra1 == 5'd0) ? 32'd0 : (we && wa == ra1) ? wd : regs[ra1];
    assign rd2 = (ra2 == 5'd0) ? 32'd0 : (we && wa == ra2) ? wd : regs[ra2];

    integer i;
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1)
                regs[i] <= 32'd0;
        end else if (we && wa != 5'd0) begin
            regs[wa] <= wd;
        end
    end

endmodule
