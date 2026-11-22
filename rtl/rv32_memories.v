// =============================================================================
// Modules     : rv32_imem, rv32_dmem
// Project     : DBPU - Dynamic Branch Prediction Unit (Phase II CPU)
// Description : Harvard-style word memories for rv32_pipeline_core.
//   rv32_imem : instruction memory, combinational read by the IF stage, plus a
//               synchronous programming (write) port used to load a program.
//   rv32_dmem : data memory, combinational read and synchronous write in MEM.
//   Both are word addressed (byte address bits [1:0] ignored) and wrap around
//   modulo WORDS.
// =============================================================================
`timescale 1ns / 1ps

module rv32_imem #(
    parameter WORDS = 256
) (
    input  wire        clk,
    input  wire [31:0] addr,
    output wire [31:0] instr,
    input  wire        prog_we,
    input  wire [31:0] prog_addr,
    input  wire [31:0] prog_data
);
    localparam AW = $clog2(WORDS);
    reg [31:0] mem [0:WORDS-1];

    assign instr = mem[addr[AW+1:2]];

    always @(posedge clk)
        if (prog_we) mem[prog_addr[AW+1:2]] <= prog_data;
endmodule


module rv32_dmem #(
    parameter WORDS = 256
) (
    input  wire        clk,
    input  wire [31:0] addr,
    output wire [31:0] rdata,
    input  wire        we,
    input  wire [31:0] wdata
);
    localparam AW = $clog2(WORDS);
    reg [31:0] mem [0:WORDS-1];

    assign rdata = mem[addr[AW+1:2]];

    always @(posedge clk)
        if (we) mem[addr[AW+1:2]] <= wdata;
endmodule
