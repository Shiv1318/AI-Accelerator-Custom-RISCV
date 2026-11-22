// Parallel-MAC matrix multiplier: N*N multipliers+accumulators, one k-step per cycle.
// Latency = N cycles.
module matmul_par #(
    parameter int N = 2, parameter int W = 8, parameter int ACC = 20, parameter int MULT = 4
)(
    input  logic                clk,
    input  logic                rst_n,
    input  logic                start,
    input  logic [N*N*W-1:0]    a_flat,
    input  logic [N*N*W-1:0]    b_flat,
    output logic                busy,
    output logic                done,
    output logic [N*N*ACC-1:0]  c_flat,
    output logic [15:0]         cycles
);
    localparam int KW = (N > 1) ? $clog2(N) : 1;
    typedef enum logic {IDLE, RUN} state_t;
    state_t st;

    logic signed [W-1:0]   a_r [N*N];
    logic signed [W-1:0]   b_r [N*N];
    logic signed [ACC-1:0] c_r [N*N];
    logic signed [2*W-1:0] prod [N*N];
    logic [KW-1:0]         k;

    genvar gi, gj;
    for (gi = 0; gi < N; gi++) begin : g_row
        for (gj = 0; gj < N; gj++) begin : g_col
            logic signed [W-1:0] opa, opb;
            assign opa = a_r[gi*N + int'(k)];
            assign opb = b_r[int'(k)*N + gj];
            if (MULT == 0) begin : g_s
                mult_star  #(W) u_mul (.a(opa), .b(opb), .p(prod[gi*N+gj]));
            end else begin : g_b
                mult_sel #(.W(W), .MULT(MULT)) u_mul (.a(opa), .b(opb), .p(prod[gi*N+gj]));
            end
        end
    end

    always_comb begin
        for (int x = 0; x < N*N; x++) c_flat[x*ACC +: ACC] = c_r[x];
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            st <= IDLE; busy <= 1'b0; done <= 1'b0; k <= '0; cycles <= '0;
            for (int x = 0; x < N*N; x++) begin a_r[x] <= '0; b_r[x] <= '0; c_r[x] <= '0; end
        end else begin
            done <= 1'b0;
            case (st)
                IDLE: if (start) begin
                    for (int x = 0; x < N*N; x++) begin
                        a_r[x] <= a_flat[x*W +: W];
                        b_r[x] <= b_flat[x*W +: W];
                        c_r[x] <= '0;
                    end
                    k <= '0; cycles <= '0; busy <= 1'b1; st <= RUN;
                end
                RUN: begin
                    cycles <= cycles + 1'b1;
                    for (int x = 0; x < N*N; x++) c_r[x] <= c_r[x] + ACC'(prod[x]);
                    if (k == KW'(N-1)) begin
                        k <= '0; st <= IDLE; busy <= 1'b0; done <= 1'b1;
                    end else k <= k + 1'b1;
                end
                default: st <= IDLE;
            endcase
        end
    end
endmodule
