module tb_mult_dadda;
    logic signed [7:0]  a, b;
    logic signed [15:0] p;
    int errors = 0, tests = 0;
    mult_dadda #(.W(8)) dut (.a(a), .b(b), .p(p));
    initial begin
        for (int i = -128; i < 128; i++)
            for (int j = -128; j < 128; j++) begin
                a = i[7:0]; b = j[7:0]; #1; tests++;
                if (p !== 16'(i*j)) begin
                    errors++;
                    if (errors < 5) $display("FAIL a=%0d b=%0d p=%0d exp=%0d", i, j, p, i*j);
                end
            end
        if (errors == 0 && tests == 65536) $display("PASS: mult_dadda correct for all %0d pairs", tests);
        else             $display("FAIL: %0d errors", errors);
        $finish;
    end
endmodule
