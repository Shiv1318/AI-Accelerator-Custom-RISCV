# Experiment 1: CPU-only vs accelerator-assisted

## Setup
- PicoRV32 (ENABLE_MUL=0, ENABLE_FAST_MUL=0) at 50 MHz; CPU-only path is a software shift-add multiply
- Accelerator path: write 8 operands, START, poll DONE, read CYCLES, read 4 results
- 24 data sets x 6 configs (3 architectures x 2 multipliers) = 144 SoC runs
- Data sets: S1, S2, identity x2, zeros x2, all-ones, worst case (-128 x -128), 16 random (xorshift32, seed 0x2545F491)
- Correctness: all 144 runs ok=1; CPU result = accelerator result = NumPy (16 random sets re-computed in Python, 0 mismatches)

## Results (CONFIRMED, measured with rdcycle)
Accelerator end-to-end: 424 cycles (8.5 us) for every data set and every configuration.

| Group | Sets | CPU cycles mean (min-max) | End-to-end speedup mean (min-max) |
|---|---|---|---|
| Random | 16 | 3816 (3253-4261) | 9.00x (7.67-10.05) |
| Standard S1, S2 | 2 | 3692 (2619-4765) | 8.71x (6.18-11.24) |
| Identity | 2 | 2435 (1113-3757) | 5.74x (2.62-8.86) |
| Zeros | 2 | 1680 (737-2623) | 3.97x (1.74-6.19) |
| All ones | 1 | 1485 | 3.50x |
| Worst case positive | 1 | 5013 | 11.82x |
| All 24 | 24 | 3465 (737-5013) | about 8.2x (range 1.74x-11.82x) |

## Compute-only speedup (DERIVED: mean CPU cycles / CYCLES register)
| Architecture | hw cycles | Speedup |
|---|---|---|
| Iterative | 8 | 433x |
| Parallel | 2 | 1,733x |
| Systolic v2 | 5 | 693x |

## Findings
1. End-to-end speedup is 1.7x to 11.8x (about 8.2x mean) against a simple software shift-add baseline.
2. End-to-end time is the same (424 cycles) for all architectures: the PicoRV32-to-AXI bridge needs many cycles per access (about 17 transfers), so the 2x2 accelerator is bus-bound. Architecture choice does not change CPU-visible time at this size.
3. CPU time varies (737 to 5013 cycles) because software shift-add exits early for small or zero multipliers; accelerator time is constant, so speedup depends on the data. Minimum 1.74x occurs on the zero-multiplicand set.
4. Compute-only speedups (433x to 1,733x) ignore bus time and must not be quoted as system speedups.

## Limitations
- Baseline is a simple software shift-add multiply; a PCPI multiplier or optimized routine would lower every speedup.
- Always quote a speedup with its data set and baseline.
- A local buffer, burst access or DMA would reduce the 424 end-to-end cycles (not implemented, not measured).
- Plots: soc_speedup_e2e.png, soc_speedup_compute.png. Data: soc_cpu_vs_accel_v3.csv, soc_cpu_summary_v3.csv.
