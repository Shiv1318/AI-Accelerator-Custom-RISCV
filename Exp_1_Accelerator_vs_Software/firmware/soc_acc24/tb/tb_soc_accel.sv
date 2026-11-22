`timescale 1ns / 1ps
// Full-SoC test: PicoRV32 runs the firmware, this TB decodes the UART TX line and prints it.
module tb_soc_accel;
    localparam int BIT = 434;                 // 50 MHz / 115200 baud
    logic clk = 1'b0, reset = 1'b1, uart_tx, uart_rx = 1'b1;
    always #10 clk = ~clk;                    // 50 MHz

    top dut (.clk, .reset, .uart_tx, .uart_rx);

    int cyc = 0;
    always @(posedge clk) begin
        cyc++;
        if (cyc > 8_000_000) begin $display("TIMEOUT: no END line from firmware"); $finish; end
    end

    initial begin repeat (10) @(posedge clk); reset <= 1'b0; end

    string ln = "";
    logic [7:0] sh;
    initial begin
        wait (!reset);
        forever begin
            @(negedge uart_tx);                         // start bit
            repeat (BIT + BIT/2) @(posedge clk);        // middle of bit 0
            for (int i = 0; i < 8; i++) begin
                sh[i] = uart_tx;
                repeat (BIT) @(posedge clk);
            end
            if (sh == 8'h0A) begin
                $display("[UART] %s", ln);
                if (ln == "END") begin $display("simulated %0d cycles", cyc); $finish; end
                ln = "";
            end else ln = {ln, $sformatf("%c", sh)};
        end
    end
endmodule
