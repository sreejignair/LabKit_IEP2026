// Wires the core to its memories and sweeps every output point.
`default_nettype none

module bf_top #(
    parameter integer N_CH = 8,  parameter integer IN_W  = 12,
    parameter integer W_W  = 8,  parameter integer FRAC_W = 4,
    parameter integer ACC_W = 32, parameter integer N_PTS = 64,
    parameter integer DEPTH = 2048, parameter integer ADDR_W = 11
)(
    input  wire clk, input  wire rst_n, input  wire start,
    output reg  done,
    output wire valid,
    output wire signed [ACC_W-1:0] result,
    output wire [$clog2(N_PTS)-1:0] point_out,
    output wire ovf
);
    localparam integer PT_W = $clog2(N_PTS);

    reg  [PT_W-1:0] point;
    reg             go, running;
    wire            busy;

    wire [$clog2(N_CH)-1:0] mem_ch;
    wire [ADDR_W-1:0]       mem_addr;
    wire signed [IN_W-1:0]  mem_q;
    wire [PT_W+$clog2(N_CH)-1:0] dly_idx;
    wire [ADDR_W-1:0]       dly_int;
    wire [FRAC_W-1:0]       dly_frac;
    wire [$clog2(N_CH)-1:0] apod_idx;
    wire signed [W_W-1:0]   apod_w;

    assign point_out = point;

    chan_mem  #(.N_CH(N_CH),.IN_W(IN_W),.ADDR_W(ADDR_W),.DEPTH(DEPTH))
        u_mem  (.clk(clk), .ch(mem_ch), .addr(mem_addr), .q(mem_q));
    delay_rom #(.N_CH(N_CH),.N_PTS(N_PTS),.ADDR_W(ADDR_W),.FRAC_W(FRAC_W))
        u_dly  (.idx(dly_idx), .d_int(dly_int), .d_frac(dly_frac));
    apod_rom  #(.N_CH(N_CH),.W_W(W_W))
        u_apod (.idx(apod_idx), .w(apod_w));

    bf_core #(.N_CH(N_CH),.IN_W(IN_W),.W_W(W_W),.FRAC_W(FRAC_W),
              .ACC_W(ACC_W),.ADDR_W(ADDR_W),.PT_W(PT_W))
        u_core (.clk(clk), .rst_n(rst_n), .start(go), .point(point),
                .busy(busy), .valid(valid), .result(result), .ovf(ovf),
                .mem_ch(mem_ch), .mem_addr(mem_addr), .mem_q(mem_q),
                .dly_idx(dly_idx), .dly_int(dly_int), .dly_frac(dly_frac),
                .apod_idx(apod_idx), .apod_w(apod_w));

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            point <= 0; go <= 1'b0; running <= 1'b0; done <= 1'b0;
        end else begin
            go <= 1'b0; done <= 1'b0;
            if (start && !running) begin
                point <= 0; running <= 1'b1; go <= 1'b1;
            end else if (running && valid) begin
                if (point == N_PTS-1) begin
                    running <= 1'b0; done <= 1'b1;
                end else begin
                    point <= point + 1'b1; go <= 1'b1;
                end
            end
        end
    end
endmodule

`default_nettype wire
