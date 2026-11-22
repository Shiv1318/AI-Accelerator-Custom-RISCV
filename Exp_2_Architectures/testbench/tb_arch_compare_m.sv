`ifndef TB_MULT
`define TB_MULT 0
`endif
// Same 1006 Python vectors through all three architectures (inferred '*' multiplier).
module tb_arch_compare;
    localparam int N = 2, W = 8, ACC = 20, NN = N*N;

    logic clk, rst_n, start;
    logic [NN*W-1:0]   a_flat, b_flat;
    logic [NN*ACC-1:0] c_i, c_p, c_s;
    logic              done_i, done_p, done_s, busy_i, busy_p, busy_s;
    logic [15:0]       cyc_i, cyc_p, cyc_s;

    matmul_iter     #(.N(N), .W(W), .ACC(ACC), .MULT(`TB_MULT)) u_i (.clk, .rst_n, .start, .a_flat, .b_flat,
        .busy(busy_i), .done(done_i), .c_flat(c_i), .cycles(cyc_i));
    matmul_par      #(.N(N), .W(W), .ACC(ACC), .MULT(`TB_MULT)) u_p (.clk, .rst_n, .start, .a_flat, .b_flat,
        .busy(busy_p), .done(done_p), .c_flat(c_p), .cycles(cyc_p));
    matmul_systolic #(.N(N), .W(W), .ACC(ACC), .MULT(`TB_MULT)) u_s (.clk, .rst_n, .start, .a_flat, .b_flat,
        .busy(busy_s), .done(done_s), .c_flat(c_s), .cycles(cyc_s));

    initial clk = 1'b0;
    always #5 clk = ~clk;

    int fd, rc, errors, tests, guard;
    int a0, a1, a2, a3, b0, b1, b2, b3, e0, e1, e2, e3;
    int exp_c [NN];
    logic d_i, d_p, d_s;
    logic signed [ACC-1:0] gi, gp, gs;

    initial begin
        errors = 0; tests = 0;
        rst_n = 1'b0; start = 1'b0; a_flat = '0; b_flat = '0;
        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        fd = $fopen("software/vectors/matmul_2x2.txt", "r");
        if (fd == 0) begin $display("FAIL: cannot open vector file (run from project root)"); $finish; end

        forever begin
            rc = $fscanf(fd, "%d %d %d %d %d %d %d %d %d %d %d %d\n",
                         a0, a1, a2, a3, b0, b1, b2, b3, e0, e1, e2, e3);
            if (rc != 12) break;
            a_flat = {W'(a3), W'(a2), W'(a1), W'(a0)};
            b_flat = {W'(b3), W'(b2), W'(b1), W'(b0)};
            exp_c[0] = e0; exp_c[1] = e1; exp_c[2] = e2; exp_c[3] = e3;

            @(posedge clk); start <= 1'b1;
            @(posedge clk); start <= 1'b0;
            d_i = 1'b0; d_p = 1'b0; d_s = 1'b0; guard = 0;
            while (!(d_i && d_p && d_s) && guard < 400) begin
                @(posedge clk);
                if (done_i) d_i = 1'b1;
                if (done_p) d_p = 1'b1;
                if (done_s) d_s = 1'b1;
                guard++;
            end
            if (guard >= 400) begin errors++; $display("TIMEOUT on vector %0d", tests); end

            for (int x = 0; x < NN; x++) begin
                gi = c_i[x*ACC +: ACC]; gp = c_p[x*ACC +: ACC]; gs = c_s[x*ACC +: ACC];
                if (int'(gi) !== exp_c[x]) begin errors++; $display("ITER  v%0d c%0d got %0d exp %0d", tests, x, int'(gi), exp_c[x]); end
                if (int'(gp) !== exp_c[x]) begin errors++; $display("PAR   v%0d c%0d got %0d exp %0d", tests, x, int'(gp), exp_c[x]); end
                if (int'(gs) !== exp_c[x]) begin errors++; $display("SYST  v%0d c%0d got %0d exp %0d", tests, x, int'(gs), exp_c[x]); end
            end
            if (cyc_i !== 16'(N*N*N) || cyc_p !== 16'(N) || cyc_s !== 16'(3*N-1)) begin
                errors++; $display("CYCLE MISMATCH v%0d: iter %0d par %0d sys %0d", tests, cyc_i, cyc_p, cyc_s);
            end
            tests++;
            @(posedge clk);
        end

        $display("Vectors run: %0d", tests);
        $display("Measured compute latency (cycles): iterative=%0d parallel=%0d systolic=%0d", cyc_i, cyc_p, cyc_s);
        if (errors == 0) $display("PASS: all three architectures match the Python golden model");
        else             $display("FAIL: %0d errors", errors);
        $finish;
    end
endmodule
