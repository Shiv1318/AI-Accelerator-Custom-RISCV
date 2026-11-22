// AXI-Lite slave wrapper around one matmul engine (2x2, 8-bit signed, 20-bit accumulator).
// Offsets: 0x00 CTRL(W) | 0x04 STATUS(R) | 0x08 CYCLES(R) | 0x10-1C A | 0x20-2C B | 0x30-3C C | 0x40 ID
module matmul_axil #(
    parameter int ARCH = 0,     // 0 iterative, 1 parallel, 2 systolic
    parameter int MULT = 0      // 0 '*', 1 Booth
)(
    input  logic        clk,
    input  logic        reset,  // active-high async, same as the SoC
    input  logic [31:0] s_axi_awaddr,
    input  logic        s_axi_awvalid,
    output logic        s_axi_awready,
    input  logic [31:0] s_axi_wdata,
    input  logic [ 3:0] s_axi_wstrb,
    input  logic        s_axi_wvalid,
    output logic        s_axi_wready,
    output logic [ 1:0] s_axi_bresp,
    output logic        s_axi_bvalid,
    input  logic        s_axi_bready,
    input  logic [31:0] s_axi_araddr,
    input  logic        s_axi_arvalid,
    output logic        s_axi_arready,
    output logic [31:0] s_axi_rdata,
    output logic [ 1:0] s_axi_rresp,
    output logic        s_axi_rvalid,
    input  logic        s_axi_rready
);
    localparam int N = 2, W = 8, ACC = 20, NN = N*N;

    logic rst_n;
    assign rst_n = ~reset;

    // ---------------- operand/result storage and engine ----------------
    logic signed [W-1:0]   a_reg [NN];
    logic signed [W-1:0]   b_reg [NN];
    logic [NN*W-1:0]       a_flat, b_flat;
    logic [NN*ACC-1:0]     c_flat;
    logic signed [ACC-1:0] c_el [NN];
    logic                  start_p, eng_busy, eng_done, busy_w, done_s;
    logic [15:0]           cyc;

    always_comb begin
        for (int x = 0; x < NN; x++) begin
            a_flat[x*W +: W] = a_reg[x];
            b_flat[x*W +: W] = b_reg[x];
            c_el[x]          = c_flat[x*ACC +: ACC];
        end
    end

    if (ARCH == 0) begin : g_iter
        matmul_iter #(.N(N), .W(W), .ACC(ACC), .MULT(MULT)) u_eng (
            .clk, .rst_n, .start(start_p), .a_flat, .b_flat,
            .busy(eng_busy), .done(eng_done), .c_flat, .cycles(cyc));
    end else if (ARCH == 1) begin : g_par
        matmul_par #(.N(N), .W(W), .ACC(ACC), .MULT(MULT)) u_eng (
            .clk, .rst_n, .start(start_p), .a_flat, .b_flat,
            .busy(eng_busy), .done(eng_done), .c_flat, .cycles(cyc));
    end else begin : g_sys
        matmul_systolic #(.N(N), .W(W), .ACC(ACC), .MULT(MULT)) u_eng (
            .clk, .rst_n, .start(start_p), .a_flat, .b_flat,
            .busy(eng_busy), .done(eng_done), .c_flat, .cycles(cyc));
    end

    // ---------------- write channel ----------------
    logic        aw_got, w_got, b_vld;
    logic [7:0]  aw_addr;
    logic [31:0] w_data;

    assign s_axi_awready = !aw_got && !b_vld;
    assign s_axi_wready  = !w_got  && !b_vld;
    assign s_axi_bresp   = 2'b00;
    assign s_axi_bvalid  = b_vld;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            aw_got <= 1'b0; w_got <= 1'b0; b_vld <= 1'b0;
            aw_addr <= '0;  w_data <= '0;
            start_p <= 1'b0; busy_w <= 1'b0; done_s <= 1'b0;
            for (int x = 0; x < NN; x++) begin a_reg[x] <= '0; b_reg[x] <= '0; end
        end else begin
            start_p <= 1'b0;
            if (eng_done) begin busy_w <= 1'b0; done_s <= 1'b1; end

            if (s_axi_awvalid && s_axi_awready) begin
                aw_got <= 1'b1; aw_addr <= s_axi_awaddr[7:0];
            end
            if (s_axi_wvalid && s_axi_wready) begin
                w_got <= 1'b1; w_data <= s_axi_wdata;
            end

            if (aw_got && w_got && !b_vld) begin
                aw_got <= 1'b0; w_got <= 1'b0; b_vld <= 1'b1;
                if (aw_addr[7:2] == 6'h00) begin
                    if (w_data[0] && !busy_w) begin
                        start_p <= 1'b1; busy_w <= 1'b1; done_s <= 1'b0;
                    end
                end else if (aw_addr[7:4] == 4'h1) begin
                    a_reg[aw_addr[3:2]] <= w_data[W-1:0];
                end else if (aw_addr[7:4] == 4'h2) begin
                    b_reg[aw_addr[3:2]] <= w_data[W-1:0];
                end
            end

            if (b_vld && s_axi_bready) b_vld <= 1'b0;
        end
    end

    // ---------------- read channel ----------------
    logic        r_vld;
    logic [31:0] r_data, rd_val;
    logic [1:0]  c_idx;

    assign c_idx = s_axi_araddr[3:2];

    always_comb begin
        rd_val = 32'h0;
        if      (s_axi_araddr[7:2] == 6'h01) rd_val = {30'b0, done_s, busy_w};
        else if (s_axi_araddr[7:2] == 6'h02) rd_val = {16'b0, cyc};
        else if (s_axi_araddr[7:4] == 4'h3)  rd_val = {{(32-ACC){c_el[c_idx][ACC-1]}}, c_el[c_idx]};
        else if (s_axi_araddr[7:2] == 6'h10) rd_val = {16'b0, 8'(MULT), 8'(ARCH)};
    end

    assign s_axi_arready = !r_vld;
    assign s_axi_rdata   = r_data;
    assign s_axi_rresp   = 2'b00;
    assign s_axi_rvalid  = r_vld;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            r_vld <= 1'b0; r_data <= '0;
        end else if (r_vld) begin
            if (s_axi_rready) r_vld <= 1'b0;
        end else if (s_axi_arvalid) begin
            r_vld <= 1'b1; r_data <= rd_val;
        end
    end
endmodule
