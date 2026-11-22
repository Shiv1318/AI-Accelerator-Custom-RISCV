`timescale 1ns / 1ps
// 1 master -> 4 slaves (ROM, SRAM, UART, MATMUL). Same behaviour as the 3-slave original.
module axi_lite_interconnect (
    input  logic clk, input logic reset,
    input  logic [31:0] m_axi_awaddr, input logic m_axi_awvalid, output logic m_axi_awready,
    input  logic [31:0] m_axi_wdata, input logic [3:0] m_axi_wstrb, input logic m_axi_wvalid, output logic m_axi_wready,
    output logic [1:0] m_axi_bresp, output logic m_axi_bvalid, input logic m_axi_bready,
    input  logic [31:0] m_axi_araddr, input logic m_axi_arvalid, output logic m_axi_arready,
    output logic [31:0] m_axi_rdata, output logic [1:0] m_axi_rresp, output logic m_axi_rvalid, input logic m_axi_rready,

    output logic [31:0] s0_axi_awaddr, output logic s0_axi_awvalid, input logic s0_axi_awready,
    output logic [31:0] s0_axi_wdata, output logic [3:0] s0_axi_wstrb, output logic s0_axi_wvalid, input logic s0_axi_wready,
    input  logic [1:0] s0_axi_bresp, input logic s0_axi_bvalid, output logic s0_axi_bready,
    output logic [31:0] s0_axi_araddr, output logic s0_axi_arvalid, input logic s0_axi_arready,
    input  logic [31:0] s0_axi_rdata, input logic [1:0] s0_axi_rresp, input logic s0_axi_rvalid, output logic s0_axi_rready,

    output logic [31:0] s1_axi_awaddr, output logic s1_axi_awvalid, input logic s1_axi_awready,
    output logic [31:0] s1_axi_wdata, output logic [3:0] s1_axi_wstrb, output logic s1_axi_wvalid, input logic s1_axi_wready,
    input  logic [1:0] s1_axi_bresp, input logic s1_axi_bvalid, output logic s1_axi_bready,
    output logic [31:0] s1_axi_araddr, output logic s1_axi_arvalid, input logic s1_axi_arready,
    input  logic [31:0] s1_axi_rdata, input logic [1:0] s1_axi_rresp, input logic s1_axi_rvalid, output logic s1_axi_rready,

    output logic [31:0] s2_axi_awaddr, output logic s2_axi_awvalid, input logic s2_axi_awready,
    output logic [31:0] s2_axi_wdata, output logic [3:0] s2_axi_wstrb, output logic s2_axi_wvalid, input logic s2_axi_wready,
    input  logic [1:0] s2_axi_bresp, input logic s2_axi_bvalid, output logic s2_axi_bready,
    output logic [31:0] s2_axi_araddr, output logic s2_axi_arvalid, input logic s2_axi_arready,
    input  logic [31:0] s2_axi_rdata, input logic [1:0] s2_axi_rresp, input logic s2_axi_rvalid, output logic s2_axi_rready,

    output logic [31:0] s3_axi_awaddr, output logic s3_axi_awvalid, input logic s3_axi_awready,
    output logic [31:0] s3_axi_wdata, output logic [3:0] s3_axi_wstrb, output logic s3_axi_wvalid, input logic s3_axi_wready,
    input  logic [1:0] s3_axi_bresp, input logic s3_axi_bvalid, output logic s3_axi_bready,
    output logic [31:0] s3_axi_araddr, output logic s3_axi_arvalid, input logic s3_axi_arready,
    input  logic [31:0] s3_axi_rdata, input logic [1:0] s3_axi_rresp, input logic s3_axi_rvalid, output logic s3_axi_rready
);
    // ---- address decode + per-transaction slave lock (same scheme as the original) ----
    logic [3:0] wr_sel_comb, rd_sel_comb, wr_sel_r, rd_sel_r, wr_sel, rd_sel;
    logic       wr_active, rd_active;

    axi_decoder u_wr_dec (.addr(m_axi_awaddr), .sel(wr_sel_comb));
    axi_decoder u_rd_dec (.addr(m_axi_araddr), .sel(rd_sel_comb));

    assign wr_sel = wr_active ? wr_sel_r : wr_sel_comb;
    assign rd_sel = rd_active ? rd_sel_r : rd_sel_comb;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            wr_sel_r <= 4'b0001; rd_sel_r <= 4'b0001; wr_active <= 1'b0; rd_active <= 1'b0;
        end else begin
            if (!wr_active && m_axi_awvalid) begin wr_sel_r <= wr_sel_comb; wr_active <= 1'b1; end
            if (wr_active && m_axi_bvalid && m_axi_bready) wr_active <= 1'b0;
            if (!rd_active && m_axi_arvalid) begin rd_sel_r <= rd_sel_comb; rd_active <= 1'b1; end
            if (rd_active && m_axi_rvalid && m_axi_rready) rd_active <= 1'b0;
        end
    end

    // ---- master -> slaves ----
    assign s0_axi_awaddr = m_axi_awaddr; assign s0_axi_awvalid = m_axi_awvalid & wr_sel[0];
    assign s0_axi_wdata  = m_axi_wdata;  assign s0_axi_wstrb = m_axi_wstrb; assign s0_axi_wvalid = m_axi_wvalid & wr_sel[0];
    assign s0_axi_bready = m_axi_bready & wr_sel[0];
    assign s0_axi_araddr = m_axi_araddr; assign s0_axi_arvalid = m_axi_arvalid & rd_sel[0];
    assign s0_axi_rready = m_axi_rready & rd_sel[0];

    assign s1_axi_awaddr = m_axi_awaddr; assign s1_axi_awvalid = m_axi_awvalid & wr_sel[1];
    assign s1_axi_wdata  = m_axi_wdata;  assign s1_axi_wstrb = m_axi_wstrb; assign s1_axi_wvalid = m_axi_wvalid & wr_sel[1];
    assign s1_axi_bready = m_axi_bready & wr_sel[1];
    assign s1_axi_araddr = m_axi_araddr; assign s1_axi_arvalid = m_axi_arvalid & rd_sel[1];
    assign s1_axi_rready = m_axi_rready & rd_sel[1];

    assign s2_axi_awaddr = m_axi_awaddr; assign s2_axi_awvalid = m_axi_awvalid & wr_sel[2];
    assign s2_axi_wdata  = m_axi_wdata;  assign s2_axi_wstrb = m_axi_wstrb; assign s2_axi_wvalid = m_axi_wvalid & wr_sel[2];
    assign s2_axi_bready = m_axi_bready & wr_sel[2];
    assign s2_axi_araddr = m_axi_araddr; assign s2_axi_arvalid = m_axi_arvalid & rd_sel[2];
    assign s2_axi_rready = m_axi_rready & rd_sel[2];

    assign s3_axi_awaddr = m_axi_awaddr; assign s3_axi_awvalid = m_axi_awvalid & wr_sel[3];
    assign s3_axi_wdata  = m_axi_wdata;  assign s3_axi_wstrb = m_axi_wstrb; assign s3_axi_wvalid = m_axi_wvalid & wr_sel[3];
    assign s3_axi_bready = m_axi_bready & wr_sel[3];
    assign s3_axi_araddr = m_axi_araddr; assign s3_axi_arvalid = m_axi_arvalid & rd_sel[3];
    assign s3_axi_rready = m_axi_rready & rd_sel[3];

    // ---- slaves -> master (flat vectors, no packed 2-D arrays) ----
    logic [3:0] s_awready, s_wready, s_bvalid, s_arready, s_rvalid;

    assign s_awready = {s3_axi_awready, s2_axi_awready, s1_axi_awready, s0_axi_awready};
    assign s_wready  = {s3_axi_wready,  s2_axi_wready,  s1_axi_wready,  s0_axi_wready};
    assign s_bvalid  = {s3_axi_bvalid,  s2_axi_bvalid,  s1_axi_bvalid,  s0_axi_bvalid};
    assign s_arready = {s3_axi_arready, s2_axi_arready, s1_axi_arready, s0_axi_arready};
    assign s_rvalid  = {s3_axi_rvalid,  s2_axi_rvalid,  s1_axi_rvalid,  s0_axi_rvalid};

    always_comb begin
        m_axi_awready = |(wr_sel & s_awready);
        m_axi_wready  = |(wr_sel & s_wready);
        m_axi_bvalid  = |(wr_sel & s_bvalid);
        m_axi_arready = |(rd_sel & s_arready);
        m_axi_rvalid  = |(rd_sel & s_rvalid);
        m_axi_bresp   = 2'b00;
        m_axi_rresp   = 2'b00;
        m_axi_rdata   = 32'h0000_0013;      // NOP, safe default (as in the original)
        if (wr_sel[0]) m_axi_bresp = s0_axi_bresp;
        if (wr_sel[1]) m_axi_bresp = s1_axi_bresp;
        if (wr_sel[2]) m_axi_bresp = s2_axi_bresp;
        if (wr_sel[3]) m_axi_bresp = s3_axi_bresp;
        if (rd_sel[0]) begin m_axi_rresp = s0_axi_rresp; m_axi_rdata = s0_axi_rdata; end
        if (rd_sel[1]) begin m_axi_rresp = s1_axi_rresp; m_axi_rdata = s1_axi_rdata; end
        if (rd_sel[2]) begin m_axi_rresp = s2_axi_rresp; m_axi_rdata = s2_axi_rdata; end
        if (rd_sel[3]) begin m_axi_rresp = s3_axi_rresp; m_axi_rdata = s3_axi_rdata; end
    end
endmodule
