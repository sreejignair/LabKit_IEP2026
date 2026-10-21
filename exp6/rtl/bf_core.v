// ---------------------------------------------------------------------------
// bf_core.v   Experiment 6  -  sequential fixed-point delay-and-sum beamformer
//
// One multiplier, one accumulator, reused across channels. For each output
// point it walks the channels, fetches the two neighbouring samples, performs
// linear interpolation in the delay fraction, applies the apodisation weight
// and accumulates.
//
// ARITHMETIC CONTRACT - must match ref/bf_golden.py exactly
//     diff = s1 - s0                     signed, IN_W+1
//     m    = diff * frac                 signed, IN_W+1+FRAC_W,  frac unsigned
//     s    = s0 + (m >>> FRAC_W)         arithmetic shift, truncates toward -inf
//     p    = s * w                       signed
//     acc  = acc + p                     signed ACC_W, saturating
//
// Memory interface is synchronous read with one cycle of latency, which is what
// a block RAM gives you. Change that and the state machine timing changes too.
// ---------------------------------------------------------------------------
`default_nettype none

module bf_core #(
    parameter integer N_CH      = 8,
    parameter integer IN_W      = 12,
    parameter integer W_W       = 8,
    parameter integer FRAC_W    = 4,
    parameter integer ACC_W     = 32,
    parameter integer ADDR_W    = 11,
    parameter integer PT_W      = 6        // enough for N_PTS
) (
    input  wire                     clk,
    input  wire                     rst_n,

    input  wire                     start,      // pulse to begin one output point
    input  wire [PT_W-1:0]          point,      // which output point
    output reg                      busy,
    output reg                      valid,      // one cycle, with result
    output reg  signed [ACC_W-1:0]  result,
    output reg                      ovf,        // sticky: accumulator saturated

    // channel sample memory, synchronous read, 1 cycle latency
    output reg  [$clog2(N_CH)-1:0]  mem_ch,
    output reg  [ADDR_W-1:0]        mem_addr,
    input  wire signed [IN_W-1:0]   mem_q,

    // delay table, combinational read (small ROM)
    output wire [PT_W+$clog2(N_CH)-1:0] dly_idx,
    input  wire [ADDR_W-1:0]        dly_int,
    input  wire [FRAC_W-1:0]        dly_frac,

    // apodisation ROM, combinational read
    output wire [$clog2(N_CH)-1:0]  apod_idx,
    input  wire signed [W_W-1:0]    apod_w
);

    localparam integer CHB = $clog2(N_CH);

    localparam [2:0] S_IDLE = 3'd0,
                     S_RD0  = 3'd1,
                     S_WAIT = 3'd2,
                     S_RD1  = 3'd3,
                     S_MAC  = 3'd4;

    reg [2:0]            state;
    reg [CHB-1:0]        ch;
    reg signed [IN_W-1:0] s0;
    reg signed [ACC_W-1:0] acc;
    reg [PT_W-1:0]       point_r;

    assign dly_idx  = {point_r, ch};
    assign apod_idx = ch;

    // ---- interpolation, combinational, from the registered s0 and the live mem_q
    wire signed [IN_W:0]            diff = mem_q - s0;                // IN_W+1
    wire signed [IN_W+FRAC_W:0]     prod = diff * $signed({1'b0, dly_frac});
    wire signed [IN_W:0]            samp = s0 + (prod >>> FRAC_W);    // truncates toward -inf
    wire signed [IN_W+W_W:0]        wprod = samp * apod_w;

    // ---- saturating accumulate
    wire signed [ACC_W:0] acc_ext = {acc[ACC_W-1], acc} + {{(ACC_W-IN_W-W_W){wprod[IN_W+W_W]}}, wprod};
    wire                  acc_ovf = (acc_ext[ACC_W] != acc_ext[ACC_W-1]);
    wire signed [ACC_W-1:0] acc_sat = acc_ovf
            ? {acc_ext[ACC_W], {(ACC_W-1){~acc_ext[ACC_W]}}}   // +max or -max
            : acc_ext[ACC_W-1:0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= S_IDLE;
            busy     <= 1'b0;
            valid    <= 1'b0;
            ovf      <= 1'b0;
            acc      <= {ACC_W{1'b0}};
            ch       <= {CHB{1'b0}};
            s0       <= {IN_W{1'b0}};
            result   <= {ACC_W{1'b0}};
            mem_ch   <= {CHB{1'b0}};
            mem_addr <= {ADDR_W{1'b0}};
            point_r  <= {PT_W{1'b0}};
        end else begin
            valid <= 1'b0;
            case (state)
                S_IDLE: begin
                    busy <= 1'b0;
                    if (start) begin
                        busy    <= 1'b1;
                        point_r <= point;
                        ch      <= {CHB{1'b0}};
                        acc     <= {ACC_W{1'b0}};
                        state   <= S_RD0;
                    end
                end

                // issue the read of s0
                S_RD0: begin
                    mem_ch   <= ch;
                    mem_addr <= dly_int;
                    state    <= S_WAIT;
                end

                // mem_q is not valid yet; issue the read of s1 next
                S_WAIT: begin
                    mem_addr <= dly_int + {{(ADDR_W-1){1'b0}}, 1'b1};
                    state    <= S_RD1;
                end

                // mem_q now carries s0; capture it. mem_q will carry s1 next cycle.
                S_RD1: begin
                    s0    <= mem_q;
                    state <= S_MAC;
                end

                // mem_q now carries s1; interpolate, weight, accumulate
                S_MAC: begin
                    acc <= acc_sat;
                    if (acc_ovf) ovf <= 1'b1;
                    if (ch == N_CH-1) begin
                        result <= acc_sat;
                        valid  <= 1'b1;
                        busy   <= 1'b0;
                        state  <= S_IDLE;
                    end else begin
                        ch    <= ch + 1'b1;
                        state <= S_RD0;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule

`default_nettype wire
