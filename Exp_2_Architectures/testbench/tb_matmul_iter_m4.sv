// Self-checking TB: reads Python-generated vectors, tests both multiplier variants.
module tb_matmul_iter_m4;
    localparam int N = 2, W = 8, ACC = 20, NN = N*N;

    logic clk, rst_n, start;
    logic [NN*W-1:0]   a_flat, b_flat;
    logic              busy0, done0, busy1, done1;
    logic [NN*ACC-1:0] c0, c1;
    logic [15:0]       cyc0, cyc1;

    matmul_iter #(.N(N), .W(W), .ACC(ACC), .MULT(4)) u0 (
        .clk, .rst_n, .start, .a_flat, .b_flat,
        .busy(busy0), .done(done0), .c_flat(c0), .cycles(cyc0));
    matmul_iter #(.N(N), .W(W), .ACC(ACC), .MULT(4)) u1 (
        .clk, .rst_n, .start, .a_flat, .b_flat,
        .busy(busy1), .done(done1), .c_flat(c1), .cycles(cyc1));

    initial clk = 1'b0;
    always #5 clk = ~clk;

    int fd, rc, errors, tests, guard;
    int a0, a1, a2, a3, b0, b1, b2, b3, e0, e1, e2, e3;
    int exp_c [NN];
    logic signed [ACC-1:0] g0, g1;

    initial begin
        errors = 0; tests = 0;
        rst_n = 1'b0; start = 1'b0; a_flat = '0; b_flat = '0;
        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        fd = $fopen("software/vectors/matmul_2x2.txt", "r");
        if (fd == 0) begin
            $display("FAIL: cannot open vector file (run from project root)");
            $finish;
        end

        forever begin
            rc = $fscanf(fd, "%d %d %d %d %d %d %d %d %d %d %d %d\n",
                         a0, a1, a2, a3, b0, b1, b2, b3, e0, e1, e2, e3);
            if (rc != 12) break;

            a_flat = {W'(a3), W'(a2), W'(a1), W'(a0)};
            b_flat = {W'(b3), W'(b2), W'(b1), W'(b0)};
            exp_c[0] = e0; exp_c[1] = e1; exp_c[2] = e2; exp_c[3] = e3;

            @(posedge clk); start <= 1'b1;
            @(posedge clk); start <= 1'b0;
            guard = 0;
            while (!(done0 && done1) && guard < 400) begin
                @(posedge clk); guard++;
            end
            if (guard >= 400) begin errors++; $display("TIMEOUT on vector %0d", tests); end

            for (int x = 0; x < NN; x++) begin
                g0 = c0[x*ACC +: ACC];
                g1 = c1[x*ACC +: ACC];
                if (int'(g0) !== exp_c[x]) begin errors++; $display("STAR  v%0d c%0d got %0d exp %0d", tests, x, int'(g0), exp_c[x]); end
                if (int'(g1) !== exp_c[x]) begin errors++; $display("BOOTH v%0d c%0d got %0d exp %0d", tests, x, int'(g1), exp_c[x]); end
            end
            if (cyc0 !== 16'(80) || cyc1 !== 16'(80)) begin
                errors++; $display("CYCLE MISMATCH v%0d: %0d / %0d", tests, cyc0, cyc1);
            end
            tests++;
            @(posedge clk);
        end

        $display("Vectors run: %0d, measured compute latency: %0d cycles (N^3)", tests, cyc0);
        if (errors == 0) $display("PASS: iterative matmul correct (both multipliers)");
        else             $display("FAIL: %0d errors", errors);
        $finish;
    end
endmodule
