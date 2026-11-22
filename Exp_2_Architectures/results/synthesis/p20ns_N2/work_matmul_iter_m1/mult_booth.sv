// Combinational radix-4 modified Booth signed multiplier (W must be even)
module mult_booth #(parameter int W = 8) (
    input  logic signed [W-1:0]   a,
    input  logic signed [W-1:0]   b,
    output logic signed [2*W-1:0] p
);
    logic signed [2*W-1:0] a_ext, pp, sum;
    logic [W:0] bx;

    assign a_ext = a;
    assign bx    = {b, 1'b0};

    always_comb begin
        sum = '0;
        for (int i = 0; i < W/2; i++) begin
            case (bx[2*i +: 3])
                3'b001, 3'b010: pp =  a_ext;
                3'b011:         pp =  a_ext <<< 1;
                3'b100:         pp = -(a_ext <<< 1);
                3'b101, 3'b110: pp = -a_ext;
                default:        pp = '0;
            endcase
            sum = sum + (pp <<< (2*i));
        end
        p = sum;
    end
endmodule
