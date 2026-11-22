#!/bin/bash
# Usage: scripts/synth_mult.sh [clock_period_ns]   (run from project root)
PERIOD=${1:-20}
LIB=/apps/vlsi/src/OpenROAD-flow-scripts/flow/platforms/sky130hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
OUT=results/synthesis/mult_dadda_p${PERIOD}ns
rm -rf $OUT; mkdir -p $OUT
CSV=results/synthesis/mult_dadda_ppa_${PERIOD}ns.csv
echo "mult,period_ns,cells,area_um2,worst_slack_ns,crit_delay_ns,cycles,latency_ns" > $CSV

for TOP in mult_dadda; do
  yosys -q -l $OUT/$TOP.yslog -p "
    read_verilog -sv rtl_dadda/$TOP.sv;
    hierarchy -check -top $TOP;
    synth -top $TOP -flatten;
    dfflibmap -liberty $LIB;
    abc -liberty $LIB -D $((PERIOD*1000));
    opt_clean -purge;
    write_verilog -noattr $OUT/$TOP.v;
    tee -o $OUT/$TOP.stat stat -liberty $LIB;
  " > /dev/null 2>&1 || { echo "Yosys failed for $TOP, see $OUT/$TOP.yslog"; continue; }

  if [ $TOP = mult_shiftadd ]; then
    CLK="create_clock -name clk -period $PERIOD [get_ports clk]"; CYC=8
  else
    CLK="create_clock -name clk -period $PERIOD"; CYC=1
  fi
  cat > $OUT/$TOP.tcl << TCL
read_liberty $LIB
read_verilog $OUT/$TOP.v
link_design $TOP
$CLK
set_input_delay 0 -clock clk [all_inputs]
set_output_delay 0 -clock clk [all_outputs]
report_checks -path_delay max -format full > $OUT/$TOP.timing
report_worst_slack -max > $OUT/$TOP.slack
exit
TCL
  sta -no_init -exit $OUT/$TOP.tcl > $OUT/$TOP.stalog 2>&1

  CELLS=$(grep -m1 -E "^ +[0-9]+ .*cells" $OUT/$TOP.stat | awk '{print $1}')
  AREA=$(grep -m1 "Chip area" $OUT/$TOP.stat | awk '{print $NF}')
  SLACK=$(grep -i "worst slack" $OUT/$TOP.slack | awk '{print $NF}')
  CRIT=$(python3 -c "print(round($PERIOD - ($SLACK), 3))" 2>/dev/null)
  LAT=$(python3 -c "print(round($CYC * ($CRIT), 3))" 2>/dev/null)
  echo "${TOP#mult_},$PERIOD,$CELLS,$AREA,$SLACK,$CRIT,$CYC,$LAT" >> $CSV
done
python3 - << PY
import csv
rows = list(csv.reader(open("$CSV")))
w = [max(len(r[i]) for r in rows) for i in range(len(rows[0]))]
for r in rows: print("  ".join(c.ljust(w[i]) for i, c in enumerate(r)))
PY
