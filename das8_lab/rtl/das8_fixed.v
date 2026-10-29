// ---------------------------------------------------------------------------
// das8_fixed.v   8-channel delay-and-sum beamformer, FIXED POINT
//
// Reads one sample from each of 8 channels, each at its own delay, multiplies
// by that channel's weight, and adds them all up. That is delay-and-sum.
//
//   bypass = 0   use the correct delay for each channel  -> echoes line up
//   bypass = 1   use the same delay for every channel    -> they do not
//
// Flip that bit and watch the result change. That is the whole experiment.
// ---------------------------------------------------------------------------
`timescale 1ns/1ps

module das8_fixed (
    input  wire               clk,
    input  wire               bypass,      // 1 = do not apply the delays
    output wire signed [31:0] result
);

    wire signed [11:0] sample  [0:7];      // what each channel read
    wire        [5:0]  delay   [0:7];      // when each channel should read
    wire signed [7:0]  weight  [0:7];      // how much each channel counts
    wire signed [19:0] product [0:7];      // 12 bits x 8 bits = 20 bits

    genvar c;
    generate
        for (c = 0; c < 8; c = c + 1) begin : channel
            us_params p (.ch(c[2:0]), .delay(delay[c]), .weight(weight[c]));

            // bypass makes every channel read at channel 0's delay
            wire [5:0] addr = bypass ? delay[0] : delay[c];

            us_rom r (.clk(clk), .ch(c[2:0]), .addr(addr), .q(sample[c]));

            assign product[c] = sample[c] * weight[c];
        end
    endgenerate

    // add the eight products together
    assign result = product[0] + product[1] + product[2] + product[3]
                  + product[4] + product[5] + product[6] + product[7];

endmodule
