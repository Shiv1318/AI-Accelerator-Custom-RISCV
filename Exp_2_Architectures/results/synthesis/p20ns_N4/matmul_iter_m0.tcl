read_liberty /apps/vlsi/src/OpenROAD-flow-scripts/flow/platforms/sky130hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
read_verilog results/synthesis/p20ns_N4/matmul_iter_m0.v
link_design matmul_iter
create_clock -name clk -period 20 [get_ports clk]
set_clock_uncertainty 0.25 [get_clocks clk]
set_input_delay 0 -clock clk [all_inputs]
set_output_delay 0 -clock clk [all_outputs]
report_checks -path_delay max -format full > results/synthesis/p20ns_N4/matmul_iter_m0.timing
report_worst_slack -max > results/synthesis/p20ns_N4/matmul_iter_m0.slack
exit
