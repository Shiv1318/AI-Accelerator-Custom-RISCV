#!/bin/bash
# Usage: scripts/synth_arch.sh [clock_period_ns]   (run from project root)
PERIOD=${1:-20}
LIB=/apps/vlsi/src/OpenROAD-flow-scripts/flow/platforms/sky130hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
OUT=results/synthesis/p${PERIOD}ns
rm -rf $OUT; mkdir -p $OUT
CSV=results/synthesis/ppa_${PERIOD}ns.csv
echo "arch,mult,period_ns,cells,area_um2,worst_slack_ns,crit_delay_ns" > $CSV

for TOP in matmul_iter matmul_par matmul_systolic; do
  for M in 0 1; do
    TAG=${TOP}_m${M}
    W=$OUT/work_$TAG; mkdir -p $W
    # copy sources, forcing the default MULT parameter
    for f in mult_star mult_booth systolic_pe matmul_iter matmul_par matmul_systolic; do
      sed -E "s/parameter int MULT = [01]/parameter int MULT = $M/" rtl/$f.sv > $W/$f.sv
    done
    SRC="$W/mult_star.sv $W/mult_booth.sv $W/systolic_pe.sv $W/$TOP.sv"

    yosys -q -l $OUT/$TAG.yslog -p "
      read_verilog -sv $SRC;
      hierarchy -check -top $TOP;
      synth -top $TOP -flatten;
      dfflibmap -liberty $LIB;
      abc -liberty $LIB -D $((PERIOD*1000));
      opt_clean -purge;
      write_verilog -noattr $OUT/$TAG.v;
      tee -o $OUT/$TAG.stat stat -liberty $LIB;
    " > /dev/null 2>&1 || { echo "Yosys failed for $TAG, see $OUT/$TAG.yslog"; continue; }

    cat > $OUT/$TAG.tcl << TCL
read_liberty $LIB
read_verilog $OUT/$TAG.v
link_design $TOP
create_clock -name clk -period $PERIOD [get_ports clk]
set_clock_uncertainty 0.25 [get_clocks clk]
set_input_delay 0 -clock clk [all_inputs]
set_output_delay 0 -clock clk [all_outputs]
report_checks -path_delay max -format full > $OUT/$TAG.timing
report_worst_slack -max > $OUT/$TAG.slack
exit
TCL
    sta -no_init -exit $OUT/$TAG.tcl > $OUT/$TAG.stalog 2>&1

    CELLS=$(grep -m1 -E "^ +[0-9]+ .*cells" $OUT/$TAG.stat | awk '{print $1}')
    AREA=$(grep -m1 "Chip area" $OUT/$TAG.stat | awk '{print $NF}')
    SLACK=$(grep -i "worst slack" $OUT/$TAG.slack | awk '{print $NF}')
    CRIT=$(python3 -c "print(round($PERIOD - ($SLACK) - 0.25, 3))" 2>/dev/null)
    echo "${TOP#matmul_},$([ $M = 0 ] && echo star || echo booth),$PERIOD,$CELLS,$AREA,$SLACK,$CRIT" >> $CSV
  done
done
python3 - << PY
import csv
rows = list(csv.reader(open("$CSV")))
w = [max(len(r[i]) for r in rows) for i in range(len(rows[0]))]
for r in rows: print("  ".join(c.ljust(w[i]) for i, c in enumerate(r)))
PY
