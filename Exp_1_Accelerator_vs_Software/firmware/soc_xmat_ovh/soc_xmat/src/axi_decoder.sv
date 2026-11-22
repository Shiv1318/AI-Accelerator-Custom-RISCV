`timescale 1ns / 1ps
// 1-of-4 one-hot decoder. 0:ROM 1:SRAM 2:UART 3:MATMUL accelerator. Unmapped -> ROM.
module axi_decoder (
    input  logic [31:0] addr,
    output logic [3:0]  sel
);
    always_comb begin
        casez (addr)
            32'h0000_????: sel = 4'b0001;
            32'h0001_????: sel = 4'b0010;
            32'h1000_000?: sel = 4'b0100;
            32'h2000_00??: sel = 4'b1000;
            default:       sel = 4'b0001;
        endcase
    end
endmodule
