`ifndef TB_ARCH
`define TB_ARCH 1
`endif
`ifndef TB_MULT
`define TB_MULT 0
`endif
module tb_pcpi_matmul;
    logic clk, resetn, valid, wr, wt, ready;
    logic [31:0] insn, rs1, rs2, rd;
    pcpi_matmul #(.ARCH(`TB_ARCH), .MULT(`TB_MULT)) dut (.clk, .resetn,
        .pcpi_valid(valid), .pcpi_insn(insn), .pcpi_rs1(rs1), .pcpi_rs2(rs2),
        .pcpi_wr(wr), .pcpi_rd(rd), .pcpi_wait(wt), .pcpi_ready(ready));
    initial clk = 1'b0;
    always #5 clk = ~clk;
    initial begin #50000000; $display("WATCHDOG"); $finish; end

    int errors, tests, fd, rc, cyc, cyc0;
    int a0, a1, a2, a3, b0, b1, b2, b3, e0, e1, e2, e3;
    logic [31:0] got;

    // like the core: hold valid until ready, drop it one edge later, idle a few cycles
    task automatic issue(input logic [31:0] i, input logic [31:0] a, input logic [31:0] b);
        int g;
        @(negedge clk); insn = i; rs1 = a; rs2 = b; valid = 1'b1; cyc = 0; g = 0;
        do begin @(negedge clk); cyc++; g++; end while (!ready && g < 500);
        if (g >= 500) begin errors++; $display("TIMEOUT"); end
        if (!wr) begin errors++; $display("pcpi_wr not set with ready"); end
        got = rd;
        @(posedge clk); #1 valid = 1'b0;
        repeat (3) @(negedge clk);
    endtask
    initial begin
        errors = 0; tests = 0; cyc0 = -1;
        resetn = 1'b0; valid = 1'b0; insn = '0; rs1 = '0; rs2 = '0;
        repeat (3) @(negedge clk);
        resetn = 1'b1;
        repeat (2) @(negedge clk);
        fd = $fopen("software/vectors/matmul_2x2.txt", "r");
        if (fd == 0) begin $display("FAIL: cannot open vector file"); $finish; end
        forever begin
            rc = $fscanf(fd, "%d %d %d %d %d %d %d %d %d %d %d %d\n",
                         a0, a1, a2, a3, b0, b1, b2, b3, e0, e1, e2, e3);
            if (rc != 12) break;
            issue(32'h0000000B, {8'(a3), 8'(a2), 8'(a1), 8'(a0)}, {8'(b3), 8'(b2), 8'(b1), 8'(b0)});
            if (int'(got) !== e0) begin errors++; $display("v%0d c0 got %0d exp %0d", tests, int'(got), e0); end
            if (cyc0 < 0) cyc0 = cyc;
            issue(32'h0000100B | (32'd1 << 25), 32'h0, 32'h0);
            if (int'(got) !== e1) begin errors++; $display("v%0d c1 got %0d exp %0d", tests, int'(got), e1); end
            issue(32'h0000100B | (32'd2 << 25), 32'h0, 32'h0);
            if (int'(got) !== e2) begin errors++; $display("v%0d c2 got %0d exp %0d", tests, int'(got), e2); end
            issue(32'h0000100B | (32'd3 << 25), 32'h0, 32'h0);
            if (int'(got) !== e3) begin errors++; $display("v%0d c3 got %0d exp %0d", tests, int'(got), e3); end
            tests++;
        end
        $display("Vectors run: %0d, core-visible cycles for XMAT.RUN: %0d", tests, cyc0);
        if (tests == 1006 && errors == 0) $display("PASS: XMAT matches golden model");
        else $display("FAIL: %0d errors", errors);
        $finish;
    end
endmodule
