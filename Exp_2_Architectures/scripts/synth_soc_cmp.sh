#!/bin/bash
# usage: scripts/synth_soc_cmp.sh <soc_dir> <ARCH> <MULT> <tag>
D=$1; A=$2; M=$3; T=$4
LIB=/apps/vlsi/src/OpenROAD-flow-scripts/flow/platforms/sky130hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
O=results/synthesis/soc_$T; rm -rf $O; mkdir -p $O
SRC="$(ls $D/src/*.v $D/src/*.sv | tr '\n' ' ') $(ls rtl/mult_*.sv | tr '\n' ' ') rtl/matmul_iter.sv rtl/matmul_par.sv rtl/systolic_pe.sv rtl/matmul_systolic.sv rtl/matmul_axil.sv rtl/pcpi_matmul.sv"
timeout 1500 yosys -q -l $O/y.log -p "read_verilog -sv -DSYNTHESIS -DACC_ARCH=$A -DACC_MULT=$M $SRC; hierarchy -check -top top; synth -top top -flatten; dfflibmap -liberty $LIB; abc -liberty $LIB -D 20000; opt_clean -purge; write_verilog -noattr $O/top.v; tee -o $O/top.stat stat -liberty $LIB" > /dev/null 2>&1 || { echo "yosys failed"; tail -5 $O/y.log; exit 1; }
printf 'read_liberty %s\nread_verilog %s/top.v\nlink_design top\ncreate_clock -name clk -period 20 [get_ports clk]\nset_clock_uncertainty 0.25 [get_clocks clk]\nreport_worst_slack -max > %s/slack.txt\nexit\n' $LIB $O $O > $O/s.tcl
sta -no_init -exit $O/s.tcl > $O/sta.log 2>&1
echo "$T cells=$(grep -m1 -E '^ +[0-9]+ .*cells' $O/top.stat | awk '{print $1}') area=$(grep -m1 'Chip area' $O/top.stat | awk '{print $NF}') slack=$(grep -i 'worst slack' $O/slack.txt | awk '{print $NF}')"
