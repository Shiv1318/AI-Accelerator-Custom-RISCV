// Combinational signed array-style multiplier: W shifted partial products summed
// in a ripple chain. The MSB of b has negative weight, so its term is subtracted.
module mult_array #(parameter int W = 8) (
    input  logic signed [W-1:0]   a,
    input  logic signed [W-1:0]   b,
    output logic signed [2*W-1:0] p
);
    logic signed [2*W-1:0] a_ext, pp, sum;
    assign a_ext = a;
    always_comb begin
        sum = '0;
        for (int i = 0; i < W; i++) begin
            pp  = b[i] ? (a_ext <<< i) : '0;
            sum = (i == W-1) ? (sum - pp) : (sum + pp);
        end
        p = sum;
    end
endmodule
