// ---------------------------------------------------------------------------
// das8_fixed.v   8-channel delay-and-sum, fixed point, fully parallel
//
// One output point per clock once the pipeline fills. All eight channels run in
// parallel: delay-line read, linear interpolation, apodisation multiply, tree.
//
// ARITHMETIC CONTRACT - must match ref/das8_model.py exactly
//   diff = s1 - s0                   signed, IN_W+1
//   m    = diff * frac               signed, frac unsigned FRAC_W
//   samp = s0 + (m >>> FRAC_W)       arithmetic shift, truncates toward -inf
//   prod = samp * w                  signed
//   acc  = balanced adder tree over the 8 products, signed ACC_W
//
// Pipeline: 1 address, 2 memory, 3 interpolate, 4 multiply, 5-7 tree.
// ---------------------------------------------------------------------------
`default_nettype none
`include "das8_pkg.vh"

module das8_fixed #(
    parameter CHAN_INIT = "chan_fixed.hex",
    parameter APOD_INIT = "apod_fixed.hex",
    parameter DINT_INIT = "delay_int.hex",
    parameter DFRC_INIT = "delay_frac.hex"
) (
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire                     in_valid,
    input  wire [`PT_W-1:0]         point,
    output wire                     out_valid,
    output wire signed [`ACC_W-1:0] result
);
    localparam N      = `N_CH;
    localparam PROD_W = `IN_W + `W_W + 1;          // 21 bits

    (* rom_style = "distributed" *) reg [15:0]        d_int [0:`N_PTS*N-1];
    (* rom_style = "distributed" *) reg [`FRAC_W-1:0] d_frc [0:`N_PTS*N-1];
    (* rom_style = "distributed" *) reg [`W_W-1:0]    apod  [0:N-1];
    initial begin
        $readmemh(DINT_INIT, d_int);
        $readmemh(DFRC_INIT, d_frc);
        $readmemh(APOD_INIT, apod);
    end

    // ---- stage 1: address generation
    reg [`ADDR_W-1:0] addr_s1 [0:N-1];
    reg [`FRAC_W-1:0] frc_s1  [0:N-1];
    reg               v_s1;
    integer k;
    always @(posedge clk) begin
        if (!rst_n) v_s1 <= 1'b0;
        else begin
            v_s1 <= in_valid;
            for (k = 0; k < N; k = k + 1) begin
                addr_s1[k] <= d_int[point*N + k][`ADDR_W-1:0];
                frc_s1 [k] <= d_frc[point*N + k];
            end
        end
    end

    // ---- per-channel datapath
    wire signed [PROD_W-1:0] prod [0:N-1];
    genvar c;
    generate
        for (c = 0; c < N; c = c + 1) begin : ch
            (* ram_style = "block" *) reg [`IN_W-1:0] mem [0:`DEPTH-1];
            initial $readmemh(CHAN_INIT, mem, c*`DEPTH, (c+1)*`DEPTH-1);

            reg signed [`IN_W-1:0] s0_s2, s1_s2;
            reg [`FRAC_W-1:0]      frc_s2;
            always @(posedge clk) begin
                s0_s2  <= mem[addr_s1[c]];
                s1_s2  <= mem[addr_s1[c] + 1'b1];
                frc_s2 <= frc_s1[c];
            end

            wire signed [`IN_W:0]         diff = s1_s2 - s0_s2;
            wire signed [`IN_W+`FRAC_W:0] m    = diff * $signed({1'b0, frc_s2});
            reg  signed [`IN_W-1:0]       samp_s3;
            always @(posedge clk) samp_s3 <= s0_s2 + (m >>> `FRAC_W);

            reg signed [PROD_W-1:0] prod_s4;
            always @(posedge clk) prod_s4 <= samp_s3 * $signed(apod[c]);
            assign prod[c] = prod_s4;
        end
    endgenerate

    // ---- stages 5-7: balanced adder tree
    reg signed [PROD_W+1:0] l1_0, l1_1, l1_2, l1_3;
    reg signed [PROD_W+2:0] l2_0, l2_1;
    reg signed [`ACC_W-1:0] l3;
    reg [5:0] vpipe;

    always @(posedge clk) begin
        if (!rst_n) begin
            vpipe <= 6'b0; l3 <= {`ACC_W{1'b0}};
        end else begin
            vpipe <= {vpipe[4:0], v_s1};
            l1_0 <= prod[0] + prod[1];
            l1_1 <= prod[2] + prod[3];
            l1_2 <= prod[4] + prod[5];
            l1_3 <= prod[6] + prod[7];
            l2_0 <= l1_0 + l1_1;
            l2_1 <= l1_2 + l1_3;
            l3   <= l2_0 + l2_1;
        end
    end

    assign result    = l3;
    assign out_valid = vpipe[5];
endmodule

`default_nettype wire
