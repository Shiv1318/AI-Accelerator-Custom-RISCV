read_liberty /apps/vlsi/src/OpenROAD-flow-scripts/flow/platforms/sky130hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
read_verilog results/synthesis/mult_p10ns/mult_shiftadd.v
link_design mult_shiftadd
create_clock -name clk -period 10 [get_ports clk]
set_input_delay 0 -clock clk [all_inputs]
set_output_delay 0 -clock clk [all_outputs]
report_checks -path_delay max -format full > results/synthesis/mult_p10ns/mult_shiftadd.timing
report_worst_slack -max > results/synthesis/mult_p10ns/mult_shiftadd.slack
exit
