// Output-stationary systolic PE: passes A right, B down (1 register delay), accumulates a*b.
module systolic_pe #(
    parameter int W = 8, parameter int ACC = 20, parameter int MULT = 2
)(
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  clr,       // synchronous clear (start of a new operation)
    input  logic signed [W-1:0]   a_in,
    input  logic signed [W-1:0]   b_in,
    output logic signed [W-1:0]   a_out,
    output logic signed [W-1:0]   b_out,
    output logic signed [ACC-1:0] acc
);
    logic signed [2*W-1:0] prod;
    if (MULT == 0) begin : g_s
        mult_star  #(W) u_mul (.a(a_in), .b(b_in), .p(prod));
    end else begin : g_b
        mult_sel #(.W(W), .MULT(MULT)) u_mul (.a(a_in), .b(b_in), .p(prod));
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_out <= '0; b_out <= '0; acc <= '0;
        end else if (clr) begin
            a_out <= '0; b_out <= '0; acc <= '0;
        end else begin
            a_out <= a_in; b_out <= b_in; acc <= acc + ACC'(prod);
        end
    end
endmodule
