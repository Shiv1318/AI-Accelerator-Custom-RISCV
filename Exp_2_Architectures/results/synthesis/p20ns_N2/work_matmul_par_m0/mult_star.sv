// Combinational signed multiplier using the inferred '*' operator
module mult_star #(parameter int W = 8) (
    input  logic signed [W-1:0]   a,
    input  logic signed [W-1:0]   b,
    output logic signed [2*W-1:0] p
);
    assign p = a * b;
endmodule
