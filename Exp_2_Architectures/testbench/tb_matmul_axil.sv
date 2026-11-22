// AXI-Lite level test: drives the register map like firmware will, checks all Python vectors.
module tb_matmul_axil #(parameter int ARCH = 0);
    localparam int NN = 4;
    localparam logic [31:0] BASE = 32'h2000_0000;

    logic clk, reset;
    logic [31:0] awaddr, wdata, araddr, rdata;
    logic [3:0]  wstrb;
    logic [1:0]  bresp, rresp;
    logic awvalid, awready, wvalid, wready, bvalid, bready, arvalid, arready, rvalid, rready;

    matmul_axil #(.ARCH(ARCH), .MULT(0)) dut (
        .clk, .reset,
        .s_axi_awaddr(awaddr), .s_axi_awvalid(awvalid), .s_axi_awready(awready),
        .s_axi_wdata(wdata),   .s_axi_wstrb(wstrb), .s_axi_wvalid(wvalid), .s_axi_wready(wready),
        .s_axi_bresp(bresp),   .s_axi_bvalid(bvalid), .s_axi_bready(bready),
        .s_axi_araddr(araddr), .s_axi_arvalid(arvalid), .s_axi_arready(arready),
        .s_axi_rdata(rdata),   .s_axi_rresp(rresp), .s_axi_rvalid(rvalid), .s_axi_rready(rready));

    initial clk = 1'b0;
    always #5 clk = ~clk;
    `include "axi_tasks.svh"

    int fd, rc, errors, tests, guard, exp_cyc;
    int a0, a1, a2, a3, b0, b1, b2, b3, e0, e1, e2, e3;
    int av [NN]; int bv [NN]; int ev [NN];
    logic [31:0] rd;

    initial begin
        errors = 0; tests = 0;
        exp_cyc = (ARCH == 0) ? 8 : (ARCH == 1) ? 2 : 5;
        reset = 1'b1; awvalid = 0; wvalid = 0; arvalid = 0; bready = 0; rready = 0;
        awaddr = 0; wdata = 0; wstrb = 0; araddr = 0;
        repeat (4) @(posedge clk);
        reset <= 1'b0;
        repeat (2) @(posedge clk);

        axi_read(BASE + 32'h40, rd);
        $display("ID register: ARCH=%0d MULT=%0d", rd[7:0], rd[15:8]);

        fd = $fopen("software/vectors/matmul_2x2.txt", "r");
        if (fd == 0) begin $display("FAIL: cannot open vector file (run from project root)"); $finish; end

        forever begin
            rc = $fscanf(fd, "%d %d %d %d %d %d %d %d %d %d %d %d\n",
                         a0, a1, a2, a3, b0, b1, b2, b3, e0, e1, e2, e3);
            if (rc != 12) break;
            av[0]=a0; av[1]=a1; av[2]=a2; av[3]=a3;
            bv[0]=b0; bv[1]=b1; bv[2]=b2; bv[3]=b3;
            ev[0]=e0; ev[1]=e1; ev[2]=e2; ev[3]=e3;

            for (int x = 0; x < NN; x++) axi_write(BASE + 32'h10 + 32'(4*x), 32'(av[x]));
            for (int x = 0; x < NN; x++) axi_write(BASE + 32'h20 + 32'(4*x), 32'(bv[x]));
            axi_write(BASE + 32'h00, 32'h1);

            guard = 0;
            do begin axi_read(BASE + 32'h04, rd); guard++; end while (!rd[1] && guard < 1000);
            if (guard >= 1000) begin errors++; $display("TIMEOUT v%0d", tests); end

            axi_read(BASE + 32'h08, rd);
            if (int'(rd) != exp_cyc) begin errors++; $display("CYCLES v%0d got %0d exp %0d", tests, int'(rd), exp_cyc); end

            for (int x = 0; x < NN; x++) begin
                axi_read(BASE + 32'h30 + 32'(4*x), rd);
                if ($signed(rd) !== ev[x]) begin
                    errors++; $display("C v%0d c%0d got %0d exp %0d", tests, x, $signed(rd), ev[x]);
                end
            end
            tests++;
        end

        $display("ARCH=%0d: %0d vectors via AXI-Lite, CYCLES register = %0d", ARCH, tests, exp_cyc);
        if (errors == 0) $display("PASS: AXI-Lite accelerator ARCH=%0d matches Python golden model", ARCH);
        else             $display("FAIL: %0d errors", errors);
        $finish;
    end
endmodule
