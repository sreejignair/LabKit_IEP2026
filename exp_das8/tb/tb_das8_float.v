// Self-checking testbench for das8_float.
// Floating point is compared with a tolerance, not bit-exactly: the IP core
// rounds per IEEE-754 and the adder tree order fixes the result, but the
// double-precision reference does not round the same way at every step.
`timescale 1ns/1ps
`include "das8_pkg.vh"

module tb_das8_float;
    reg clk = 0, rst_n = 0, in_valid = 0;
    reg [`PT_W-1:0] point = 0;
    wire out_valid;
    wire [31:0] result;

    reg [31:0] golden [0:`N_PTS-1];
    integer got = 0, errors = 0, i;
    real r_got, r_exp, tol;

    always #5 clk = ~clk;

    das8_float dut (.clk(clk), .rst_n(rst_n), .in_valid(in_valid),
                    .point(point), .out_valid(out_valid), .result(result));

    function real f32_to_real(input [31:0] b);
        begin f32_to_real = $bitstoshortreal(b); end
    endfunction

    initial begin
        $readmemh("golden_float.hex", golden);
        repeat (5) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);
        for (i = 0; i < `N_PTS; i = i + 1) begin
            @(posedge clk);
            in_valid <= 1'b1;
            point    <= i[`PT_W-1:0];
        end
        @(posedge clk) in_valid <= 1'b0;
        repeat (120) @(posedge clk);

        if (got != `N_PTS) $display("FAIL: expected %0d, got %0d", `N_PTS, got);
        else if (errors == 0) $display("PASS: all %0d points within tolerance", `N_PTS);
        else $display("FAIL: %0d of %0d points outside tolerance", errors, `N_PTS);
        $finish;
    end

    always @(posedge clk) begin
        if (out_valid) begin
            r_got = f32_to_real(result);
            r_exp = f32_to_real(golden[got]);
            tol   = (r_exp < 0 ? -r_exp : r_exp) * 1.0e-5 + 1.0e-6;
            if ((r_got - r_exp) > tol || (r_exp - r_got) > tol) begin
                errors = errors + 1;
                if (errors <= 5)
                    $display("  point %0d: got %f, expected %f", got, r_got, r_exp);
            end
            got = got + 1;
        end
    end

    initial begin #400000; $display("FAIL: timeout"); $finish; end
endmodule
