set R $::env(R); set VCD $::env(VCD); set SC $::env(SCOPE)
read_liberty /apps/vlsi/src/OpenROAD-flow-scripts/flow/platforms/sky130hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
read_verilog $::env(PWD)/top_logic.nl.v
link_design top
read_sdc $R/results/final/sdc/top.sdc
read_spef $R/results/final/spef/top.spef
read_vcd -scope $SC $VCD
report_activity_annotation
report_power
