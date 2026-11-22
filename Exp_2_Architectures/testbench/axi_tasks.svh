// Race-free AXI-Lite master tasks: drive and sample on negedge, DUT acts on posedge.
int wd_cnt = 0;
always @(posedge clk) begin
    wd_cnt++;
    if (wd_cnt > 5_000_000) begin $display("WATCHDOG: global timeout"); $finish; end
end

task automatic axi_write(input logic [31:0] addr, input logic [31:0] data);
    logic a_hs, w_hs;
    @(negedge clk);
    awaddr = addr; awvalid = 1'b1; wdata = data; wstrb = 4'hF; wvalid = 1'b1; bready = 1'b1;
    while (awvalid || wvalid) begin
        a_hs = awvalid && awready;      // handshake will happen at the next posedge
        w_hs = wvalid  && wready;
        @(negedge clk);
        if (a_hs) awvalid = 1'b0;
        if (w_hs) wvalid  = 1'b0;
    end
    while (!bvalid) @(negedge clk);
    @(negedge clk);                     // B handshake happened at the posedge in between
    bready = 1'b0;
endtask

task automatic axi_read(input logic [31:0] addr, output logic [31:0] data);
    @(negedge clk);
    araddr = addr; arvalid = 1'b1; rready = 1'b1;
    while (!arready) @(negedge clk);
    @(negedge clk);                     // AR handshake happened at the posedge in between
    arvalid = 1'b0;
    while (!rvalid) @(negedge clk);
    data = rdata;
    @(negedge clk);                     // R handshake happens at the posedge before this
    rready = 1'b0;
endtask
