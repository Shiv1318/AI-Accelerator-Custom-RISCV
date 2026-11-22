// Iterative matrix multiplier: ONE multiplier + accumulator reused for N^3 cycles.
// Latency (start accepted -> done) = N^3 cycles. 'cycles' holds the measured count.
module matmul_iter #(
    parameter int N    = 2,
    parameter int W    = 8,
    parameter int ACC  = 20,
    parameter int MULT = 3          // 0 '*', 1 Booth, 2 Wallace, 3 Array, 4 shift-add
)(
    input  logic                clk,
    input  logic                rst_n,       // active-low async assert
    input  logic                start,
    input  logic [N*N*W-1:0]    a_flat,      // row-major, element x at [x*W +: W]
    input  logic [N*N*W-1:0]    b_flat,
    output logic                busy,
    output logic                done,        // 1-cycle pulse; c_flat valid
    output logic [N*N*ACC-1:0]  c_flat,
    output logic [15:0]         cycles
);
    localparam int IW = (N > 1) ? $clog2(N) : 1;
    localparam logic [IW-1:0] LAST = IW'(N - 1);

    typedef enum logic {IDLE, RUN} state_t;
    state_t st;

    logic signed [W-1:0]   a_r [N*N];
    logic signed [W-1:0]   b_r [N*N];
    logic signed [ACC-1:0] c_r [N*N];
    logic signed [ACC-1:0] acc, acc_base, acc_next;
    logic [IW-1:0]         i, j, k;

    logic signed [W-1:0]   opa, opb;
    logic signed [2*W-1:0] prod;

    assign opa = a_r[int'(i)*N + int'(k)];
    assign opb = b_r[int'(k)*N + int'(j)];

    logic step;
    if (MULT == 4) begin : g_sa
        logic sm_start, sm_busy, sm_done;
        logic signed [2*W-1:0] sm_p;
        mult_shiftadd #(W) u_mul (.clk(clk), .rst_n(rst_n), .start(sm_start),
            .a(opa), .b(opb), .busy(sm_busy), .done(sm_done), .p(sm_p));
        assign sm_start = (st == RUN) && !sm_busy && !sm_done;
        assign step = sm_done;
        assign prod = sm_p;
    end else begin : g_comb
        if (MULT == 0) begin : g_star
            mult_star #(W) u_mul (.a(opa), .b(opb), .p(prod));
        end else begin : g_sel
            mult_sel #(.W(W), .MULT(MULT)) u_mul (.a(opa), .b(opb), .p(prod));
        end
        assign step = 1'b1;
    end

    assign acc_base = (k == '0) ? '0 : acc;
    assign acc_next = acc_base + ACC'(prod);

    always_comb begin
        for (int x = 0; x < N*N; x++) c_flat[x*ACC +: ACC] = c_r[x];
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            st <= IDLE; busy <= 1'b0; done <= 1'b0;
            i <= '0; j <= '0; k <= '0; acc <= '0; cycles <= '0;
            for (int x = 0; x < N*N; x++) begin
                a_r[x] <= '0; b_r[x] <= '0; c_r[x] <= '0;
            end
        end else begin
            done <= 1'b0;
            case (st)
                IDLE: if (start) begin
                    for (int x = 0; x < N*N; x++) begin
                        a_r[x] <= a_flat[x*W +: W];
                        b_r[x] <= b_flat[x*W +: W];
                    end
                    i <= '0; j <= '0; k <= '0; cycles <= '0;
                    busy <= 1'b1; st <= RUN;
                end
                RUN: begin
                    cycles <= cycles + 1'b1;
                    if (step) begin
                    acc    <= acc_next;
                    if (k == LAST) begin
                        c_r[int'(i)*N + int'(j)] <= acc_next;
                        k <= '0;
                        if (j == LAST) begin
                            j <= '0;
                            if (i == LAST) begin
                                st <= IDLE; busy <= 1'b0; done <= 1'b1;
                            end else i <= i + 1'b1;
                        end else j <= j + 1'b1;
                    end else k <= k + 1'b1;
                    end
                end
                default: st <= IDLE;
            endcase
        end
    end
endmodule
