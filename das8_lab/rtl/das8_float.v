// ---------------------------------------------------------------------------
// das8_float.v   8-channel delay-and-sum beamformer, FLOATING POINT
//
// Does exactly the same arithmetic as das8_fixed.v, on exactly the same data.
// The ONLY difference is that the multiply and the adds are IEEE-754 single
// precision instead of plain integers.
//
// That is the point of the experiment: same job, same data, same structure,
// and then you compare the two utilisation reports.
//
// NEEDS THREE IP CORES, created from the IP Catalog before this will build:
//     fp_i2f   Floating-point, Fixed-to-float   (12-bit signed in, single out)
//     fp_mul   Floating-point, Multiply          (single)
//     fp_add   Floating-point, Add               (single)
// The lab manual gives the exact dialog settings for each.
// ---------------------------------------------------------------------------
`timescale 1ns/1ps

module das8_float (
    input  wire        clk,
    input  wire        bypass,
    output wire [31:0] result      // IEEE-754 single precision
);

    wire signed [11:0] sample [0:7];
    wire        [5:0]  delay  [0:7];
    wire signed [7:0]  weight [0:7];
    wire        [31:0] s_f    [0:7];   // sample as a float
    wire        [31:0] w_f    [0:7];   // weight as a float
    wire        [31:0] prod   [0:7];

    genvar c;
    generate
        for (c = 0; c < 8; c = c + 1) begin : channel
            us_params p (.ch(c[2:0]), .delay(delay[c]), .weight(weight[c]));
            wire [5:0] addr = bypass ? delay[0] : delay[c];
            us_rom r (.clk(clk), .ch(c[2:0]), .addr(addr), .q(sample[c]));

            // integer -> float, both the sample and the weight
            fp_i2f u_cs (.aclk(clk),
                         .s_axis_a_tvalid(1'b1),
                         .s_axis_a_tdata({{4{sample[c][11]}}, sample[c]}),
                         .m_axis_result_tvalid(), .m_axis_result_tdata(s_f[c]));

            fp_i2f u_cw (.aclk(clk),
                         .s_axis_a_tvalid(1'b1),
                         .s_axis_a_tdata({{8{weight[c][7]}}, weight[c]}),
                         .m_axis_result_tvalid(), .m_axis_result_tdata(w_f[c]));

            fp_mul u_m (.aclk(clk),
                        .s_axis_a_tvalid(1'b1), .s_axis_a_tdata(s_f[c]),
                        .s_axis_b_tvalid(1'b1), .s_axis_b_tdata(w_f[c]),
                        .m_axis_result_tvalid(), .m_axis_result_tdata(prod[c]));
        end
    endgenerate

    // the same adder tree, in floating point: 7 adders in 3 levels
    wire [31:0] a0, a1, a2, a3, b0, b1;

    fp_add t00 (.aclk(clk), .s_axis_a_tvalid(1'b1), .s_axis_a_tdata(prod[0]),
                .s_axis_b_tvalid(1'b1), .s_axis_b_tdata(prod[1]),
                .m_axis_result_tvalid(), .m_axis_result_tdata(a0));
    fp_add t01 (.aclk(clk), .s_axis_a_tvalid(1'b1), .s_axis_a_tdata(prod[2]),
                .s_axis_b_tvalid(1'b1), .s_axis_b_tdata(prod[3]),
                .m_axis_result_tvalid(), .m_axis_result_tdata(a1));
    fp_add t02 (.aclk(clk), .s_axis_a_tvalid(1'b1), .s_axis_a_tdata(prod[4]),
                .s_axis_b_tvalid(1'b1), .s_axis_b_tdata(prod[5]),
                .m_axis_result_tvalid(), .m_axis_result_tdata(a2));
    fp_add t03 (.aclk(clk), .s_axis_a_tvalid(1'b1), .s_axis_a_tdata(prod[6]),
                .s_axis_b_tvalid(1'b1), .s_axis_b_tdata(prod[7]),
                .m_axis_result_tvalid(), .m_axis_result_tdata(a3));
    fp_add t10 (.aclk(clk), .s_axis_a_tvalid(1'b1), .s_axis_a_tdata(a0),
                .s_axis_b_tvalid(1'b1), .s_axis_b_tdata(a1),
                .m_axis_result_tvalid(), .m_axis_result_tdata(b0));
    fp_add t11 (.aclk(clk), .s_axis_a_tvalid(1'b1), .s_axis_a_tdata(a2),
                .s_axis_b_tvalid(1'b1), .s_axis_b_tdata(a3),
                .m_axis_result_tvalid(), .m_axis_result_tdata(b1));
    fp_add t20 (.aclk(clk), .s_axis_a_tvalid(1'b1), .s_axis_a_tdata(b0),
                .s_axis_b_tvalid(1'b1), .s_axis_b_tdata(b1),
                .m_axis_result_tvalid(), .m_axis_result_tdata(result));

endmodule
