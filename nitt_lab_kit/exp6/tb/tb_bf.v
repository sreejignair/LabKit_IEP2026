// Self-checking testbench. Compares every output point against golden_acc.txt.
// A single mismatch fails the run and prints the point, so the fault is localised.
`timescale 1ns/1ps

module tb_bf;
    localparam N_PTS = 64, ACC_W = 32;

    reg clk = 0, rst_n = 0, start = 0;
    wire done, valid, ovf;
    wire signed [ACC_W-1:0] result;
    wire [5:0] point_out;

    integer golden [0:N_PTS-1];
    integer errors = 0, checked = 0;

    always #5 clk = ~clk;

    bf_top dut (.clk(clk), .rst_n(rst_n), .start(start), .done(done),
                .valid(valid), .result(result), .point_out(point_out), .ovf(ovf));

    initial begin
        $readmemh("golden_acc_hex.txt", golden);   // see note in README
        repeat (4) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);
        start = 1; @(posedge clk); start = 0;
        wait (done);
        repeat (2) @(posedge clk);
        if (checked != N_PTS)
            $display("FAIL: expected %0d results, captured %0d", N_PTS, checked);
        else if (errors == 0)
            $display("PASS: all %0d points bit-exact against the golden model", N_PTS);
        else
            $display("FAIL: %0d of %0d points differ", errors, N_PTS);
        if (ovf) $display("NOTE: accumulator saturated at least once");
        $finish;
    end

    always @(posedge clk) begin
        if (valid) begin
            checked = checked + 1;
            if (result !== golden[point_out]) begin
                errors = errors + 1;
                if (errors <= 5)
                    $display("  point %0d: got %0d, expected %0d",
                             point_out, result, golden[point_out]);
            end
        end
    end

    initial begin
        #200000;
        $display("FAIL: timeout - the state machine never reached done");
        $finish;
    end
endmodule
