read_liberty /apps/vlsi/src/OpenROAD-flow-scripts/flow/platforms/sky130hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
read_verilog results/synthesis/dadda_acc_p20ns/matmul_iter.v
link_design matmul_iter
create_clock -name clk -period 20 [get_ports clk]
set_clock_uncertainty 0.25 [get_clocks clk]
set_input_delay 0 -clock clk [all_inputs]
set_output_delay 0 -clock clk [all_outputs]
report_worst_slack -max > results/synthesis/dadda_acc_p20ns/matmul_iter.slack
exit
