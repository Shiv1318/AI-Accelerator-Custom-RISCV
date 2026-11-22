read_liberty /apps/vlsi/src/OpenROAD-flow-scripts/flow/platforms/sky130hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
read_verilog results/synthesis/soc_xmat_a2m0/top.v
link_design top
create_clock -name clk -period 20 [get_ports clk]
set_clock_uncertainty 0.25 [get_clocks clk]
report_worst_slack -max > results/synthesis/soc_xmat_a2m0/slack.txt
exit
