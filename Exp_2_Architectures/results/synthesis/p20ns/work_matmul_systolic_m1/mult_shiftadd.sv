// Sequential signed shift-add multiplier. Latency: W cycles after start.
// MSB of the multiplier has negative weight, so the last partial product is subtracted.
module mult_shiftadd #(parameter int W = 8) (
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  start,
    input  logic signed [W-1:0]   a,
    input  logic signed [W-1:0]   b,
    output logic                  busy,
    output logic                  done,   // 1-cycle pulse, p valid
    output logic signed [2*W-1:0] p
);
    logic signed [2*W-1:0] acc, a_sh, a_ext, term, next_acc;
    logic [W-1:0]          b_r;
    logic [$clog2(W)-1:0]  cnt;

    assign a_ext    = a;
    assign term     = b_r[0] ? a_sh : '0;
    assign next_acc = (cnt == W-1) ? (acc - term) : (acc + term);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc <= '0; a_sh <= '0; b_r <= '0; cnt <= '0;
            busy <= 1'b0; done <= 1'b0; p <= '0;
        end else begin
            done <= 1'b0;
            if (!busy) begin
                if (start) begin
                    acc <= '0; a_sh <= a_ext; b_r <= b; cnt <= '0; busy <= 1'b1;
                end
            end else begin
                acc  <= next_acc;
                a_sh <= a_sh <<< 1;
                b_r  <= b_r >> 1;
                cnt  <= cnt + 1'b1;
                if (cnt == W-1) begin
                    busy <= 1'b0; done <= 1'b1; p <= next_acc;
                end
            end
        end
    end
endmodule
