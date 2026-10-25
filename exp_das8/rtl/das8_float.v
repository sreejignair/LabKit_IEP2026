// ---------------------------------------------------------------------------
// das8_float.v   8-channel delay-and-sum, IEEE-754 single precision
//
// Structurally identical to das8_fixed.v so the synthesis comparison is fair:
// same channel count, same memory depth, same delay tables, same adder tree
// shape. Only the arithmetic is different.
//
// The multipliers and adders are AMD Floating-Point Operator IP cores, created
// by tcl/create_fp_ip.tcl. They are NOT free-running combinational logic - each
// has its own latency, which is why the pipeline here is deeper.
//
// Interpolation is done in floating point too: samp = s0 + (s1-s0)*frac,
// with frac supplied already converted to float.
// ---------------------------------------------------------------------------
`default_nettype none
`include "das8_pkg.vh"

module das8_float #(
    parameter CHAN_INIT = "chan_float.hex",
    parameter APOD_INIT = "apod_float.hex",
    parameter DINT_INIT = "delay_int.hex",
    parameter DFRC_INIT = "delay_frac.hex",
    parameter FP_LAT_MUL = 3,          // must match the IP configuration
    parameter FP_LAT_ADD = 3,
    parameter FP_LAT_SUB = 3
) (
    input  wire            clk,
    input  wire            rst_n,
    input  wire            in_valid,
    input  wire [`PT_W-1:0] point,
    output wire            out_valid,
    output wire [31:0]     result        // IEEE-754 single
);
    localparam N = `N_CH;

    (* rom_style = "distributed" *) reg [15:0]        d_int [0:`N_PTS*N-1];
    (* rom_style = "distributed" *) reg [`FRAC_W-1:0] d_frc [0:`N_PTS*N-1];
    (* rom_style = "distributed" *) reg [31:0]        apod  [0:N-1];
    initial begin
        $readmemh(DINT_INIT, d_int);
        $readmemh(DFRC_INIT, d_frc);
        $readmemh(APOD_INIT, apod);
    end

    // frac is 0..15; convert to float by a small lookup rather than an IP core
    (* rom_style = "distributed" *) reg [31:0] frac2f [0:15];
    initial begin
        frac2f[0]=32'h00000000; frac2f[1]=32'h3D800000; frac2f[2]=32'h3E000000;
        frac2f[3]=32'h3E400000; frac2f[4]=32'h3E800000; frac2f[5]=32'h3EA00000;
        frac2f[6]=32'h3EC00000; frac2f[7]=32'h3EE00000; frac2f[8]=32'h3F000000;
        frac2f[9]=32'h3F100000; frac2f[10]=32'h3F200000; frac2f[11]=32'h3F300000;
        frac2f[12]=32'h3F400000; frac2f[13]=32'h3F500000; frac2f[14]=32'h3F600000;
        frac2f[15]=32'h3F700000;
    end

    reg [`ADDR_W-1:0] addr_s1 [0:N-1];
    reg [31:0]        fracf_s1[0:N-1];
    reg               v_s1;
    integer k;
    always @(posedge clk) begin
        if (!rst_n) v_s1 <= 1'b0;
        else begin
            v_s1 <= in_valid;
            for (k = 0; k < N; k = k + 1) begin
                addr_s1[k]  <= d_int[point*N + k][`ADDR_W-1:0];
                fracf_s1[k] <= frac2f[d_frc[point*N + k]];
            end
        end
    end

    wire [31:0] prod [0:N-1];
    genvar c;
    generate
        for (c = 0; c < N; c = c + 1) begin : ch
            (* ram_style = "block" *) reg [31:0] mem [0:`DEPTH-1];
            initial $readmemh(CHAN_INIT, mem, c*`DEPTH, (c+1)*`DEPTH-1);

            reg [31:0] s0_s2, s1_s2, fracf_s2;
            always @(posedge clk) begin
                s0_s2    <= mem[addr_s1[c]];
                s1_s2    <= mem[addr_s1[c] + 1'b1];
                fracf_s2 <= fracf_s1[c];
            end

            // samp = s0 + (s1 - s0) * frac    three IP cores deep
            wire [31:0] diff, scaled, samp;
            fp_sub u_sub (.aclk(clk), .s_axis_a_tvalid(1'b1), .s_axis_a_tdata(s1_s2),
                          .s_axis_b_tvalid(1'b1), .s_axis_b_tdata(s0_s2),
                          .m_axis_result_tvalid(), .m_axis_result_tdata(diff));

            reg [31:0] s0_d [0:FP_LAT_SUB-1];
            reg [31:0] fr_d [0:FP_LAT_SUB-1];
            integer j;
            always @(posedge clk) begin
                s0_d[0] <= s0_s2; fr_d[0] <= fracf_s2;
                for (j = 1; j < FP_LAT_SUB; j = j + 1) begin
                    s0_d[j] <= s0_d[j-1]; fr_d[j] <= fr_d[j-1];
                end
            end

            fp_mul u_mul_frac (.aclk(clk), .s_axis_a_tvalid(1'b1), .s_axis_a_tdata(diff),
                               .s_axis_b_tvalid(1'b1), .s_axis_b_tdata(fr_d[FP_LAT_SUB-1]),
                               .m_axis_result_tvalid(), .m_axis_result_tdata(scaled));

            reg [31:0] s0_d2 [0:FP_LAT_MUL-1];
            always @(posedge clk) begin
                s0_d2[0] <= s0_d[FP_LAT_SUB-1];
                for (j = 1; j < FP_LAT_MUL; j = j + 1) s0_d2[j] <= s0_d2[j-1];
            end

            fp_add u_add_interp (.aclk(clk), .s_axis_a_tvalid(1'b1), .s_axis_a_tdata(s0_d2[FP_LAT_MUL-1]),
                                 .s_axis_b_tvalid(1'b1), .s_axis_b_tdata(scaled),
                                 .m_axis_result_tvalid(), .m_axis_result_tdata(samp));

            fp_mul u_mul_apod (.aclk(clk), .s_axis_a_tvalid(1'b1), .s_axis_a_tdata(samp),
                               .s_axis_b_tvalid(1'b1), .s_axis_b_tdata(apod[c]),
                               .m_axis_result_tvalid(), .m_axis_result_tdata(prod[c]));
        end
    endgenerate

    // ---- floating-point adder tree: 7 adders in 3 levels
    wire [31:0] l1_0,l1_1,l1_2,l1_3,l2_0,l2_1,l3_0;
    fp_add a10 (.aclk(clk), .s_axis_a_tvalid(1'b1), .s_axis_a_tdata(prod[0]),
                .s_axis_b_tvalid(1'b1), .s_axis_b_tdata(prod[1]),
                .m_axis_result_tvalid(), .m_axis_result_tdata(l1_0));
    fp_add a11 (.aclk(clk), .s_axis_a_tvalid(1'b1), .s_axis_a_tdata(prod[2]),
                .s_axis_b_tvalid(1'b1), .s_axis_b_tdata(prod[3]),
                .m_axis_result_tvalid(), .m_axis_result_tdata(l1_1));
    fp_add a12 (.aclk(clk), .s_axis_a_tvalid(1'b1), .s_axis_a_tdata(prod[4]),
                .s_axis_b_tvalid(1'b1), .s_axis_b_tdata(prod[5]),
                .m_axis_result_tvalid(), .m_axis_result_tdata(l1_2));
    fp_add a13 (.aclk(clk), .s_axis_a_tvalid(1'b1), .s_axis_a_tdata(prod[6]),
                .s_axis_b_tvalid(1'b1), .s_axis_b_tdata(prod[7]),
                .m_axis_result_tvalid(), .m_axis_result_tdata(l1_3));
    fp_add a20 (.aclk(clk), .s_axis_a_tvalid(1'b1), .s_axis_a_tdata(l1_0),
                .s_axis_b_tvalid(1'b1), .s_axis_b_tdata(l1_1),
                .m_axis_result_tvalid(), .m_axis_result_tdata(l2_0));
    fp_add a21 (.aclk(clk), .s_axis_a_tvalid(1'b1), .s_axis_a_tdata(l1_2),
                .s_axis_b_tvalid(1'b1), .s_axis_b_tdata(l1_3),
                .m_axis_result_tvalid(), .m_axis_result_tdata(l2_1));
    fp_add a30 (.aclk(clk), .s_axis_a_tvalid(1'b1), .s_axis_a_tdata(l2_0),
                .s_axis_b_tvalid(1'b1), .s_axis_b_tdata(l2_1),
                .m_axis_result_tvalid(), .m_axis_result_tdata(l3_0));

    // valid pipeline: 1 addr + 1 mem + sub + mul + add + mul + 3 tree adds
    localparam TOTAL_LAT = 2 + FP_LAT_SUB + FP_LAT_MUL + FP_LAT_ADD + FP_LAT_MUL + 3*FP_LAT_ADD;
    reg [TOTAL_LAT-1:0] vsr;
    always @(posedge clk) begin
        if (!rst_n) vsr <= {TOTAL_LAT{1'b0}};
        else        vsr <= {vsr[TOTAL_LAT-2:0], v_s1};
    end

    assign result    = l3_0;
    assign out_valid = vsr[TOTAL_LAT-1];
endmodule

`default_nettype wire
