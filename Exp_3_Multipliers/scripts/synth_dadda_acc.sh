#!/bin/bash
PERIOD=${1:-20}
LIB=/apps/vlsi/src/OpenROAD-flow-scripts/flow/platforms/sky130hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
OUT=results/synthesis/dadda_acc_p${PERIOD}ns
rm -rf $OUT; mkdir -p $OUT
CSV=results/synthesis/ppa_${PERIOD}ns_dadda_acc.csv
echo "arch,mult,period_ns,cells,area_um2,worst_slack_ns,crit_delay_ns" > $CSV
for TOP in matmul_iter matmul_par matmul_systolic; do
  W=$OUT/work_$TOP; mkdir -p $W
  cp rtl_dadda_acc/mult_sel.sv rtl_dadda_acc/mult_wallace.sv rtl_dadda_acc/mult_array.sv rtl_dadda_acc/mult_shiftadd.sv rtl_dadda_acc/mult_dadda.sv $W/
  for f in mult_star mult_booth systolic_pe matmul_iter matmul_par matmul_systolic; do
    sed -E "s/parameter int MULT = [0-9]/parameter int MULT = 5/" rtl_dadda_acc/$f.sv > $W/$f.sv
  done
  SRC="$W/mult_star.sv $W/mult_booth.sv $W/mult_sel.sv $W/mult_wallace.sv $W/mult_array.sv $W/mult_shiftadd.sv $W/mult_dadda.sv $W/systolic_pe.sv $W/$TOP.sv"
  yosys -q -l $OUT/$TOP.yslog -p "
    read_verilog -sv $SRC;
    hierarchy -check -top $TOP;
    synth -top $TOP -flatten;
    dfflibmap -liberty $LIB;
    abc -liberty $LIB -D $((PERIOD*1000));
    opt_clean -purge;
    write_verilog -noattr $OUT/$TOP.v;
    tee -o $OUT/$TOP.stat stat -liberty $LIB;
  " > /dev/null 2>&1 || { echo "Yosys failed for $TOP"; continue; }
  cat > $OUT/$TOP.tcl << TCL
read_liberty $LIB
read_verilog $OUT/$TOP.v
link_design $TOP
create_clock -name clk -period $PERIOD [get_ports clk]
set_clock_uncertainty 0.25 [get_clocks clk]
set_input_delay 0 -clock clk [all_inputs]
set_output_delay 0 -clock clk [all_outputs]
report_worst_slack -max > $OUT/$TOP.slack
exit
TCL
  sta -no_init -exit $OUT/$TOP.tcl > $OUT/$TOP.stalog 2>&1
  CELLS=$(grep -m1 -E "^ +[0-9]+ .*cells" $OUT/$TOP.stat | awk '{print $1}')
  AREA=$(grep -m1 "Chip area" $OUT/$TOP.stat | awk '{print $NF}')
  SLACK=$(grep -i "worst slack" $OUT/$TOP.slack | awk '{print $NF}')
  CRIT=$(python3 -c "print(round($PERIOD - ($SLACK) - 0.25, 2))")
  echo "${TOP#matmul_},dadda,$PERIOD,$CELLS,$AREA,$SLACK,$CRIT" >> $CSV
done
cat $CSV
