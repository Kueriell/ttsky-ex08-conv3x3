`default_nettype none

// Minimal Verilog testbench for cocotb.
// - Generates clock and reset.
// - Leaves stimulus to cocotb (test/test.py).

module tb;

    reg clk = 0;
    always #5 clk = ~clk;  // 100 MHz equivalent

    reg        rst_n = 0;
    reg        ena   = 1;

    reg  [7:0] ui_in  = 0;
    reg  [7:0] uio_in = 0;

    wire [7:0] uo_out;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;

    tt_um_ex08_conv3x3 dut (
        .ui_in  (ui_in),
        .uo_out (uo_out),
        .uio_in (uio_in),
        .uio_out(uio_out),
        .uio_oe (uio_oe),
        .ena    (ena),
        .clk    (clk),
        .rst_n  (rst_n)
    );

    initial begin
        $dumpfile("tb.fst");
        $dumpvars(0, tb);
        rst_n  = 0;
        ui_in  = 0;
        uio_in = 0;
        repeat (5) @(posedge clk);
        rst_n  = 1;
    end

endmodule

`default_nettype wire
