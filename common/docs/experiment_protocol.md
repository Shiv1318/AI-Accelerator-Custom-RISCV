# Experiment protocol

## Fairness rules
- Same matrices, 8-bit signed operands, 20-bit accumulator (wrap), 20 ns clock for every candidate
- Same Sky130HD tt_025C_1v80 liberty and same Yosys/abc script for all synthesis runs
- Correctness first: every design is checked against the NumPy golden model (1006 vectors) before any PPA comparison
- Report compute-only cycles (CYCLES register) and end-to-end cycles (rdcycle around the full CPU transaction) separately

## Reproduce
cd ~/AI_ACCELERATOR_RISCV && source venv/bin/activate
python software/reference/gen_vectors.py
verilator --binary --timing -Wall -Wno-fatal --top-module tb_arch_compare -Mdir results/simulation/obj_arch2 rtl/mult_star.sv rtl/mult_booth.sv rtl/matmul_iter.sv rtl/matmul_par.sv rtl/systolic_pe.sv rtl/matmul_systolic.sv tb/tb_arch_compare.sv
./results/simulation/obj_arch2/Vtb_arch_compare | tail -5   # expect 8 / 2 / 5 and PASS
scripts/synth_arch.sh 20      # overwrites results/synthesis/ppa_20ns.csv
scripts/synth_mult.sh 20
scripts/synth_scale.sh 20 4
for A in 0 1 2; do for M in 0 1; do scripts/soc_run.sh $A $M | grep UART; done; done
python software/analysis/parse_soc_v3.py
python software/analysis/plot_soc_v3.py
python software/analysis/plot_arch_v2.py

## Measurement definitions
- Compute latency = CYCLES register, start accepted to DONE
- End-to-end = rdcycle around: write 8 operands, START, poll DONE, read CYCLES, read 4 results
- Derived latency (ns) = cycles x critical delay (first-order, ideal wires)
- Speedup = CPU cycles / accelerator cycles, always stated with data set and baseline
