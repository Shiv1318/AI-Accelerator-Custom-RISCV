// NxN output-stationary systolic array. Row i of A enters at cycle i (skew), column j of B
// at cycle j. PE(i,j) sees A[i][k] and B[k][j] together at cycle i+j+k.
// Latency = 3N-2 cycles (fill + compute). 'cycles' doubles as the feed-time counter.
module matmul_systolic #(
    parameter int N = 4, parameter int W = 8, parameter int ACC = 20, parameter int MULT = 0
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
    typedef enum logic {IDLE, RUN} state_t;
    state_t st;

    logic signed [W-1:0]   a_r [N*N];
    logic signed [W-1:0]   b_r [N*N];
    logic signed [W-1:0]   a_feed [N];
    logic signed [W-1:0]   b_feed [N];
    logic signed [W-1:0]   a_w [N][N+1];
    logic signed [W-1:0]   b_w [N+1][N];
    logic signed [ACC-1:0] acc_w [N][N];
    logic                  clr;

    assign clr = (st == IDLE) && start;

    always_comb begin
        for (int i = 0; i < N; i++) begin
            a_feed[i] = '0;
            b_feed[i] = '0;
            if (st == RUN && int'(cycles) >= i && (int'(cycles) - i) < N) begin
                a_feed[i] = a_r[i*N + (int'(cycles) - i)];
                b_feed[i] = b_r[(int'(cycles) - i)*N + i];
            end
        end
    end

    genvar gi, gj;
    for (gj = 0; gj < N; gj++) begin : g_bfeed
        assign b_w[0][gj] = b_feed[gj];
    end
    for (gi = 0; gi < N; gi++) begin : g_row
        assign a_w[gi][0] = a_feed[gi];
        for (gj = 0; gj < N; gj++) begin : g_col
            systolic_pe #(.W(W), .ACC(ACC), .MULT(MULT)) u_pe (
                .clk, .rst_n, .clr,
                .a_in (a_w[gi][gj]),   .b_in (b_w[gi][gj]),
                .a_out(a_w[gi][gj+1]), .b_out(b_w[gi+1][gj]),
                .acc  (acc_w[gi][gj]));
        end
    end

    always_comb begin
        for (int i = 0; i < N; i++)
            for (int j = 0; j < N; j++)
                c_flat[(i*N+j)*ACC +: ACC] = acc_w[i][j];
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            st <= IDLE; busy <= 1'b0; done <= 1'b0; cycles <= '0;
            for (int x = 0; x < N*N; x++) begin a_r[x] <= '0; b_r[x] <= '0; end
        end else begin
            done <= 1'b0;
            case (st)
                IDLE: if (start) begin
                    for (int x = 0; x < N*N; x++) begin
                        a_r[x] <= a_flat[x*W +: W];
                        b_r[x] <= b_flat[x*W +: W];
                    end
                    cycles <= '0; busy <= 1'b1; st <= RUN;
                end
                RUN: begin
                    cycles <= cycles + 1'b1;
                    if (cycles == 16'(3*N - 3)) begin
                        st <= IDLE; busy <= 1'b0; done <= 1'b1;
                    end
                end
                default: st <= IDLE;
            endcase
        end
    end
endmodule
