// XMAT custom-0 co-processor for PicoRV32 PCPI
// funct3=000: rs1=A packed, rs2=B packed, run engine, rd=C[0]
// funct3=001: rd=C[funct7[1:0]] (no compute)
module pcpi_matmul #(parameter int ARCH = 1, parameter int MULT = 0) (
    input  logic        clk,
    input  logic        resetn,
    input  logic        pcpi_valid,
    input  logic [31:0] pcpi_insn,
    input  logic [31:0] pcpi_rs1,
    input  logic [31:0] pcpi_rs2,
    output logic        pcpi_wr,
    output logic [31:0] pcpi_rd,
    output logic        pcpi_wait,
    output logic        pcpi_ready
);
    localparam int N = 2, W = 8, ACC = 20, NN = N*N;
    wire is_xmat = pcpi_valid && (pcpi_insn[6:0] == 7'b0001011);
    wire [2:0] f3 = pcpi_insn[14:12];
    wire [6:0] f7 = pcpi_insn[31:25];
    logic start, busy, done;
    logic [NN*ACC-1:0] c_flat;
    logic [15:0] cycles;
    typedef enum logic [1:0] {S_IDLE, S_RUN, S_DRAIN} st_t;
    st_t st;
    if (ARCH == 0) begin : g_e
        matmul_iter #(.N(N), .W(W), .ACC(ACC), .MULT(MULT)) u_eng (.clk(clk), .rst_n(resetn),
            .start(start), .a_flat(pcpi_rs1), .b_flat(pcpi_rs2), .busy(busy), .done(done),
            .c_flat(c_flat), .cycles(cycles));
    end else if (ARCH == 1) begin : g_e
        matmul_par #(.N(N), .W(W), .ACC(ACC), .MULT(MULT)) u_eng (.clk(clk), .rst_n(resetn),
            .start(start), .a_flat(pcpi_rs1), .b_flat(pcpi_rs2), .busy(busy), .done(done),
            .c_flat(c_flat), .cycles(cycles));
    end else begin : g_e
        matmul_systolic #(.N(N), .W(W), .ACC(ACC), .MULT(MULT)) u_eng (.clk(clk), .rst_n(resetn),
            .start(start), .a_flat(pcpi_rs1), .b_flat(pcpi_rs2), .busy(busy), .done(done),
            .c_flat(c_flat), .cycles(cycles));
    end
    assign start     = (st == S_IDLE) && is_xmat && (f3 == 3'b000);
    assign pcpi_wait = is_xmat;
    wire signed [ACC-1:0] c0   = c_flat[0 +: ACC];
    wire signed [ACC-1:0] elem = c_flat[f7[1:0]*ACC +: ACC];
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            st <= S_IDLE; pcpi_ready <= 1'b0; pcpi_wr <= 1'b0; pcpi_rd <= '0;
        end else begin
            pcpi_ready <= 1'b0; pcpi_wr <= 1'b0;
            case (st)
                S_IDLE: if (is_xmat) begin
                    if (f3 == 3'b000) st <= S_RUN;
                    else if (f3 == 3'b001) begin
                        pcpi_rd <= {{(32-ACC){elem[ACC-1]}}, elem};
                        pcpi_wr <= 1'b1; pcpi_ready <= 1'b1; st <= S_DRAIN;
                    end
                end
                S_RUN: if (done) begin
                    pcpi_rd <= {{(32-ACC){c0[ACC-1]}}, c0};
                    pcpi_wr <= 1'b1; pcpi_ready <= 1'b1; st <= S_DRAIN;
                end
                S_DRAIN: if (!pcpi_valid) st <= S_IDLE;
                default: st <= S_IDLE;
            endcase
        end
    end
endmodule
