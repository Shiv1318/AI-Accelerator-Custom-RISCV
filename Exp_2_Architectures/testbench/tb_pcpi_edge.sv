`ifndef TB_ARCH
`define TB_ARCH 1
`endif
`ifndef TB_MULT
`define TB_MULT 0
`endif
module tb_pcpi_edge;
    logic clk, resetn, valid, wr, wt, ready;
    logic [31:0] insn, rs1, rs2, rd, got;
    pcpi_matmul #(.ARCH(`TB_ARCH), .MULT(`TB_MULT)) dut (.clk, .resetn,
        .pcpi_valid(valid), .pcpi_insn(insn), .pcpi_rs1(rs1), .pcpi_rs2(rs2),
        .pcpi_wr(wr), .pcpi_rd(rd), .pcpi_wait(wt), .pcpi_ready(ready));
    initial clk = 1'b0;
    always #5 clk = ~clk;
    initial begin #50000000; $display("WATCHDOG"); $finish; end
    int errors, tests, fd, rc, spur, nr;
    int a0, a1, a2, a3, b0, b1, b2, b3, e0, e1, e2, e3;
    // back-to-back: valid is low for exactly one sampled clock edge between instructions
    task automatic fast(input logic [31:0] ins, input logic [31:0] a, input logic [31:0] b);
        int g;
        @(negedge clk); insn = ins; rs1 = a; rs2 = b; valid = 1'b1; g = 0;
        do begin @(negedge clk); g++; end while (!ready && g < 500);
        if (g >= 500) begin errors++; $display("TIMEOUT"); end
        if (!wr) begin errors++; $display("wr not set with ready"); end
        got = rd;
        @(posedge clk); #1 valid = 1'b0;
        @(posedge clk);
    endtask
    task automatic getchk(input int idx, input int exp);
        fast(32'h0000100B | (32'(idx) << 25), 32'h0, 32'h0);
        if (int'(got) !== exp) begin errors++; $display("GET%0d got %0d exp %0d", idx, int'(got), exp); end
    endtask
    task automatic t_b2b;
        fd = $fopen("software/vectors/matmul_2x2.txt", "r");
        if (fd == 0) begin $display("FAIL: cannot open vector file"); $finish; end
        tests = 0;
        while (tests < 50) begin
            rc = $fscanf(fd, "%d %d %d %d %d %d %d %d %d %d %d %d\n", a0, a1, a2, a3, b0, b1, b2, b3, e0, e1, e2, e3);
            if (rc != 12) break;
            fast(32'h0000000B, {8'(a3), 8'(a2), 8'(a1), 8'(a0)}, {8'(b3), 8'(b2), 8'(b1), 8'(b0)});
            if (int'(got) !== e0) begin errors++; $display("b2b v%0d c0 got %0d exp %0d", tests, int'(got), e0); end
            getchk(1, e1); getchk(2, e2); getchk(3, e3);
            tests++;
        end
        $fclose(fd);
        $display("B2B: %0d vectors RUN->GET->GET->GET->RUN back-to-back", tests);
    endtask
    task automatic t_reset;
        int d;
        spur = 0; nr = 0;
        for (d = 1; d <= 9; d++) begin
            @(negedge clk); insn = 32'h0000000B; rs1 = 32'h02010403; rs2 = 32'h08070605; valid = 1'b1;
            repeat (d) @(negedge clk);
            resetn = 1'b0; valid = 1'b0;
            repeat (2) @(negedge clk);
            resetn = 1'b1;
            repeat (20) begin @(negedge clk); if (ready || wr) spur++; end
            fast(32'h0000000B, 32'h04030201, 32'h08070605);
            if (int'(got) !== 19) begin errors++; $display("after reset d=%0d c0 got %0d exp 19", d, int'(got)); end
            getchk(1, 22); getchk(2, 43); getchk(3, 50);
            nr++;
        end
        if (spur != 0) errors++;
        $display("RESET: %0d resets mid-RUN (async, negedge), spurious ready/wr after reset: %0d", nr, spur);
    endtask
    task automatic t_unknown;
        int r, w;
        r = 0; w = 0;
        @(negedge clk); insn = 32'h0000200B; rs1 = 0; rs2 = 0; valid = 1'b1;
        repeat (100) begin @(negedge clk); if (ready) r++; if (wt) w++; end
        $display("UNKNOWN funct3=010: ready in %0d/100 cycles, wait high in %0d/100", r, w);
        valid = 1'b0; repeat (3) @(negedge clk);
        fast(32'h0000000B, 32'h04030201, 32'h08070605);
        if (int'(got) !== 19) begin errors++; $display("recovery after unknown: got %0d exp 19", int'(got)); end
        insn = 32'h00000033; valid = 1'b1; r = 0; w = 0;
        repeat (5) begin @(negedge clk); if (ready) r++; if (wt) w++; end
        valid = 1'b0; repeat (2) @(negedge clk);
        $display("NONXMAT (ADD): ready %0d/5, wait %0d/5 (both should be 0)", r, w);
        if (r != 0 || w != 0) errors++;
    endtask
    initial begin
        errors = 0; tests = 0; spur = 0; nr = 0;
        resetn = 1'b0; valid = 1'b0; insn = '0; rs1 = '0; rs2 = '0;
        repeat (3) @(negedge clk); resetn = 1'b1; repeat (2) @(negedge clk);
        t_b2b; t_reset; t_unknown;
        $display("EDGE SUMMARY: b2b=%0d resets=%0d errors=%0d", tests, nr, errors);
        if (tests == 50 && nr == 9 && errors == 0) $display("PASS: edge tests");
        else $display("FAIL: edge tests");
        $finish;
    end
endmodule
