// Single-vector debug test with tracing and a watchdog.
module tb_axil_dbg #(parameter int ARCH = 0);
    localparam logic [31:0] BASE = 32'h2000_0000;
    logic clk, reset;
    logic [31:0] awaddr, wdata, araddr, rdata;
    logic [3:0]  wstrb;
    logic [1:0]  bresp, rresp;
    logic awvalid, awready, wvalid, wready, bvalid, bready, arvalid, arready, rvalid, rready;

    matmul_axil #(.ARCH(ARCH), .MULT(0)) dut (
        .clk, .reset,
        .s_axi_awaddr(awaddr), .s_axi_awvalid(awvalid), .s_axi_awready(awready),
        .s_axi_wdata(wdata), .s_axi_wstrb(wstrb), .s_axi_wvalid(wvalid), .s_axi_wready(wready),
        .s_axi_bresp(bresp), .s_axi_bvalid(bvalid), .s_axi_bready(bready),
        .s_axi_araddr(araddr), .s_axi_arvalid(arvalid), .s_axi_arready(arready),
        .s_axi_rdata(rdata), .s_axi_rresp(rresp), .s_axi_rvalid(rvalid), .s_axi_rready(rready));

    initial clk = 1'b0;
    always #5 clk = ~clk;
    `include "axi_tasks.svh"

    int cc = 0;
    string step = "init";
    always @(posedge clk) begin
        cc++;
        if (cc > 3000) begin
            $display("WATCHDOG: stuck at step '%s' (awready=%b wready=%b bvalid=%b arready=%b rvalid=%b)",
                     step, awready, wready, bvalid, arready, rvalid);
            $finish;
        end
    end

    logic [31:0] rd;
    initial begin
        reset = 1'b1; awvalid = 0; wvalid = 0; arvalid = 0; bready = 0; rready = 0;
        awaddr = 0; wdata = 0; wstrb = 0; araddr = 0;
        repeat (4) @(posedge clk);
        reset <= 1'b0;
        repeat (2) @(posedge clk);

        step = "read ID";  axi_read(BASE + 32'h40, rd);  $display("ID = 0x%0h (cyc %0d)", rd, cc);
        step = "write A0"; axi_write(BASE + 32'h10, 32'd1);  $display("wrote A0 (cyc %0d)", cc);
        step = "write A1"; axi_write(BASE + 32'h14, 32'd2);
        step = "write A2"; axi_write(BASE + 32'h18, 32'd3);
        step = "write A3"; axi_write(BASE + 32'h1C, 32'd4);
        step = "write B0"; axi_write(BASE + 32'h20, 32'd5);
        step = "write B1"; axi_write(BASE + 32'h24, 32'd6);
        step = "write B2"; axi_write(BASE + 32'h28, 32'd7);
        step = "write B3"; axi_write(BASE + 32'h2C, 32'd8);
        step = "START";    axi_write(BASE + 32'h00, 32'd1); $display("START written (cyc %0d)", cc);
        for (int p = 0; p < 12; p++) begin
            step = "poll STATUS"; axi_read(BASE + 32'h04, rd);
            $display("poll %0d: STATUS = %0d (cyc %0d)", p, rd, cc);
            if (rd[1]) break;
        end
        step = "read CYCLES"; axi_read(BASE + 32'h08, rd); $display("CYCLES = %0d", rd);
        for (int x = 0; x < 4; x++) begin
            step = "read C"; axi_read(BASE + 32'h30 + 32'(4*x), rd);
            $display("C%0d = %0d", x, $signed(rd));
        end
        $display("expected C = 19 22 43 50");
        $finish;
    end
endmodule
