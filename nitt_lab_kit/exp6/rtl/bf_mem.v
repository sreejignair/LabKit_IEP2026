// Channel sample memory and the two small ROMs.
// Synchronous read with one cycle of latency, which is what a block RAM gives you.
`default_nettype none

module chan_mem #(
    parameter integer N_CH = 8, parameter integer IN_W = 12,
    parameter integer ADDR_W = 11, parameter integer DEPTH = 2048,
    parameter INIT = "chan_mem.hex"
)(
    input  wire clk,
    input  wire [$clog2(N_CH)-1:0] ch,
    input  wire [ADDR_W-1:0]       addr,
    output reg  signed [IN_W-1:0]  q
);
    // channel-major, exactly as gen_vectors.py writes it
    reg [IN_W-1:0] mem [0:N_CH*DEPTH-1];
    initial $readmemh(INIT, mem);
    always @(posedge clk) q <= mem[ch*DEPTH + addr];
endmodule


module delay_rom #(
    parameter integer N_CH = 8, parameter integer N_PTS = 64,
    parameter integer ADDR_W = 11, parameter integer FRAC_W = 4,
    parameter INT_INIT = "delay_int.hex", parameter FRAC_INIT = "delay_frac.hex"
)(
    input  wire [$clog2(N_PTS)+$clog2(N_CH)-1:0] idx,
    output wire [ADDR_W-1:0]  d_int,
    output wire [FRAC_W-1:0]  d_frac
);
    reg [15:0]       rint  [0:N_PTS*N_CH-1];
    reg [FRAC_W-1:0] rfrac [0:N_PTS*N_CH-1];
    initial begin $readmemh(INT_INIT, rint); $readmemh(FRAC_INIT, rfrac); end
    assign d_int  = rint[idx][ADDR_W-1:0];
    assign d_frac = rfrac[idx];
endmodule


module apod_rom #(
    parameter integer N_CH = 8, parameter integer W_W = 8,
    parameter INIT = "apod.hex"
)(
    input  wire [$clog2(N_CH)-1:0] idx,
    output wire signed [W_W-1:0]   w
);
    reg [W_W-1:0] rom [0:N_CH-1];
    initial $readmemh(INIT, rom);
    assign w = rom[idx];
endmodule

`default_nettype wire
