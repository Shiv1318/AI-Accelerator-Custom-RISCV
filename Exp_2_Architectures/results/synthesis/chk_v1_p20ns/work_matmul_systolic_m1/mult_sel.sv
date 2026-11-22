// Selects a combinational multiplier: 1 Booth, 2 Wallace, 3 Array
module mult_sel #(parameter int W = 8, parameter int MULT = 1) (
    input  logic signed [W-1:0]   a,
    input  logic signed [W-1:0]   b,
    output logic signed [2*W-1:0] p
);
    if (MULT == 1) begin : g_booth
        mult_booth   #(W) u (.a(a), .b(b), .p(p));
    end else if (MULT == 2) begin : g_wal
        mult_wallace #(W) u (.a(a), .b(b), .p(p));
    end else begin : g_arr
        mult_array   #(W) u (.a(a), .b(b), .p(p));
    end
endmodule
