// Self-checking testbench for das8_fixed.
// Drives all 64 points and compares every result against sim/golden_fixed.hex.
`timescale 1ns/1ps
`include "das8_pkg.vh"

module tb_das8_fixed;
    reg clk = 0, rst_n = 0, in_valid = 0;
    reg  [`PT_W-1:0] point = 0;
    wire out_valid;
    wire signed [`ACC_W-1:0] result;

    integer golden [0:`N_PTS-1];
    integer errors = 0, got = 0, i;

    always #5 clk = ~clk;                       // 100 MHz

    das8_fixed dut (.clk(clk), .rst_n(rst_n), .in_valid(in_valid),
                    .point(point), .out_valid(out_valid), .result(result));

    initial begin
        $readmemh("golden_fixed.hex", golden);
        repeat (5) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);
        for (i = 0; i < `N_PTS; i = i + 1) begin
            @(posedge clk);
            in_valid <= 1'b1;
            point    <= i[`PT_W-1:0];
        end
        @(posedge clk) in_valid <= 1'b0;
        repeat (40) @(posedge clk);             // let the pipeline drain

        if (got != `N_PTS)
            $display("FAIL: expected %0d results, captured %0d", `N_PTS, got);
        else if (errors == 0)
            $display("PASS: all %0d points bit-exact against the golden model", `N_PTS);
        else
            $display("FAIL: %0d of %0d points differ", errors, `N_PTS);
        $finish;
    end

    always @(posedge clk) begin
        if (out_valid) begin
            if (result !== golden[got]) begin
                errors = errors + 1;
                if (errors <= 5)
                    $display("  point %0d: got %0d, expected %0d", got, result, golden[got]);
            end
            got = got + 1;
        end
    end

    initial begin
        #200000; $display("FAIL: timeout"); $finish;
    end
endmodule
