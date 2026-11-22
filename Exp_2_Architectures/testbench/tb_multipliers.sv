// Exhaustive self-checking test: all 65536 signed 8-bit pairs, all 3 multipliers
module tb_multipliers;
    localparam int W = 8;
    logic clk = 0;
    always #5 clk = ~clk;

    logic rst_n, start;
    logic signed [W-1:0]   a, b;
    logic signed [2*W-1:0] p_star, p_booth, p_sa;
    logic busy, done;
    int errors = 0, cycles = 0;

    mult_star     #(W) u_star  (.a, .b, .p(p_star));
    mult_booth    #(W) u_booth (.a, .b, .p(p_booth));
    mult_shiftadd #(W) u_sa    (.clk, .rst_n, .start, .a, .b, .busy, .done, .p(p_sa));

    initial begin
        rst_n = 0; start = 0; a = 0; b = 0;
        repeat (3) @(posedge clk);
        rst_n = 1;
        for (int i = -128; i < 128; i++) begin
            for (int j = -128; j < 128; j++) begin
                a = W'(i); b = W'(j);
                @(posedge clk); start <= 1;
                @(posedge clk); start <= 0;
                cycles = 1;
                @(posedge clk);
                while (!done) begin @(posedge clk); cycles++; end
                if (p_star  !== 16'(i*j)) begin errors++; $display("STAR  %0d*%0d=%0d", i, j, p_star);  end
                if (p_booth !== 16'(i*j)) begin errors++; $display("BOOTH %0d*%0d=%0d", i, j, p_booth); end
                if (p_sa    !== 16'(i*j)) begin errors++; $display("SA    %0d*%0d=%0d", i, j, p_sa);    end
            end
        end
        $display("Shift-add latency (start accepted -> done seen): ~%0d cycles", cycles);
        if (errors == 0) $display("PASS: all multipliers correct for all 65536 pairs");
        else             $display("FAIL: %0d errors", errors);
        $finish;
    end
endmodule
