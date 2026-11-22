`timescale 1ns / 1ps
module tb_soc_gl_win;
    logic clk = 1'b0, reset = 1'b1, uart_tx, uart_rx = 1'b1;
    always #10 clk = ~clk;
    top dut (.clk, .reset, .uart_tx, .uart_rx);
    int cyc = 0, on_c = -1, off_c = -1;
    initial begin
        if (!$value$plusargs("on=%d", on_c))  on_c  = -1;
        if (!$value$plusargs("off=%d", off_c)) off_c = -1;
    end
    always @(posedge clk) begin
        cyc++;
        if (cyc == on_c) begin $dumpfile("win.vcd"); $dumpvars(0, dut); end
        if (cyc == off_c) begin $display("window %0d..%0d done", on_c, off_c); $finish; end
    end
    initial begin repeat (10) @(posedge clk); reset <= 1'b0; end
endmodule
