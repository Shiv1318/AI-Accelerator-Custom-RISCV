# AI Accelerator with Custom RISC-V: project report (draft, 14 Nov 2026)

## 1. Objective
Build a small matrix-multiplication accelerator, attach it to a PicoRV32 RISC-V SoC as a memory-mapped AXI-Lite peripheral, and measure it against software multiplication on the CPU. Three experiments: (1) CPU-only vs accelerator, (2) accelerator architectures, (3) multiplication algorithms. Python/NumPy is the numerical reference (MATLAB is not installed in the lab).

## 2. System and frozen specification (Spec v0.1)
- CPU: PicoRV32, ENABLE_MUL=0, ENABLE_FAST_MUL=0 (CPU-only baseline is a software shift-add multiply)
- Integration: AXI-Lite slave 3 at 0x2000_0000 (ROM 0x0000_0000, SRAM 0x0001_0000, UART 0x1000_0000)
- Matrix 2x2; 8-bit signed operands; 16-bit product; 20-bit accumulator, wrap
- Clock 20 ns (50 MHz); reset active-high async at the SoC boundary
- Registers: CTRL 0x00, STATUS 0x04, CYCLES 0x08, A 0x10-1C, B 0x20-2C, C 0x30-3C, ID 0x40
- Architectures: iterative (8 cycles), parallel (2), systolic v2 (5)
- Multipliers: star, Booth radix-4, shift-add, array, Wallace

## 3. Method and fairness rules
- Every design is checked against one independent NumPy golden model (1006 seeded vectors) before any PPA comparison
- Same operand format, clock, liberty and synthesis script for all candidates
- Compute-only cycles (CYCLES register) and end-to-end cycles (rdcycle around the full CPU transaction) are reported separately
- Labels used: confirmed (measured), derived (computed from measured numbers), not verified, not done

## 4. Environment and tool versions
| Tool | Version | Role |
|---|---|---|
| Python 3 + NumPy, Pandas, Matplotlib | venv | golden model, vectors, analysis, plots |
| Verilator | 5.052 | simulation (--binary --timing) |
| Yosys (lab) | 0.64+26 | first-order synthesis |
| OpenSTA | 3.1.0 | static timing on Yosys netlist (ideal wires) |
| OpenLane 1 | commit ff5509f6 (own Yosys 0.30+48, own OpenROAD) | full RTL-to-GDS runs, sky130A |
| RISC-V GCC | 15.2.0 | firmware (no libc, no hardware multiply) |
| Library | sky130_fd_sc_hd__tt_025C_1v80 | typical corner |
Note: OpenLane's internal tools differ from the lab's main tools; physical-design results are tied to the OpenLane 1 versions above.

## 5. Physical design status
Config (OpenLane 1, area-oriented): DIE_AREA 1000x1000 um fixed, FP_CORE_UTIL 35, PL_TARGET_DENSITY 0.65, SYNTH_STRATEGY AREA 3, 20 ns clock.

### 5.1 Baseline SoC (soc_base): complete
| Metric | Value |
|---|---|
| Synthesis cells / area | 18,584 cells, 210,349 um2 |
| Timing (typical, 20 ns) | wns 0, tns 0 |
| DRC / LVS | 0 / 0 errors |
| Antenna | 17 violations (only open check) |
| Power | not measured |

### 5.2 SoC with accelerator (soc_a2m0, ARCH 2 / star): not completed
- Synthesis-only area: 262,297 um2 vs 210,349 um2 baseline (about +25%). This delta also includes a changed ROM program (UART-echo firmware replaced by accelerator firmware), so it is not purely accelerator area.
- Placement and global routing completed (zero overflow); detailed routing did not converge (about 4,157 violations when the session was lost). A second attempt at density 0.40 failed (GPL-0302). A third attempt at density 0.50 is planned last.
- No post-route result is claimed for the accelerator SoC.

## 6. Conclusions (each tied to its experiment section)
1. All designs are functionally correct against NumPy: 5 multipliers on 65,536 pairs; 3 architectures on 1006 vectors; 144 SoC runs with real firmware.
2. End-to-end the accelerator is 1.7x to 11.8x faster (about 8.2x mean) than a simple software shift-add multiply, and is bus-bound at 424 cycles for every architecture.
3. At 2x2, parallel has the lowest compute latency; iterative with Booth is the smallest; registering the systolic feed cut its critical path from 9.90 to 5.87 ns.
4. Booth is the smallest multiplier; star has the best area x delay; shift-add is flop-dominated.

## 7. Limitations
First-order synthesis numbers (ideal wires, abc -D no effect, lpflow cells not excluded); OpenLane 1 tool versions differ from the lab tools; area-oriented config; ROM change in the area delta; N=4/N=8 synthesis-only and unsimulated; baseline CPU is a simple shift-add; power not measured; no post-route result for the accelerator SoC.

## 8. Not claimed
Tapeout readiness, silicon results, 100 MHz operation, power values, that the accelerator SoC is DRC/LVS/timing clean, that systolic scales better than parallel.

## 9. Future work
Post-route accelerator SoC run; PCPI-multiplier CPU baseline; local buffer, burst access or DMA to cut the 424-cycle bus cost; pipelined systolic for back-to-back throughput; Dadda multiplier and 4x4 array (Wallace is done); activity-based power estimation.
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
# Experiment 2: accelerator architectures (N=2, 8-bit signed)

## Setup
- Same 1006 vectors, 20 ns clock, Sky130HD tt liberty, Yosys + OpenSTA script
- Architectures: iterative MAC (8 cycles), parallel MAC (2), systolic v1 (4), systolic v2 with registered feed (5, 3N-1)
- Multipliers: star ('*') and Booth radix-4
- First-order numbers: ideal wires, abc -D has no effect, lpflow cells not excluded

## Results (synthesis + OpenSTA, cycles measured)
| Design | Cells | Area (um2) | Cycles | Crit. path (ns) | Latency ns (DERIVED) | Area x cycles (DERIVED) |
|---|---|---|---|---|---|---|
| Iterative, star | 1178 | 10,590 | 8 | 8.26 | 66.1 | 84,721 |
| Iterative, Booth | 1005 | 9,683 | 8 | 9.63 | 77.0 | 77,464 |
| Parallel, star | 2427 | 19,664 | 2 | 10.09 | 20.2 | 39,328 |
| Parallel, Booth | 1943 | 15,582 | 2 | 9.77 | 19.5 | 31,165 |
| Systolic v1, star | 3140 | 23,724 | 4 | 9.90 | 39.6 | 94,896 |
| Systolic v1, Booth | 2032 | 16,946 | 4 | 10.30 | 41.2 | 67,785 |
| Systolic v2, star | 2530 | 21,195 | 5 | 5.87 | 29.4 | 105,977 |
| Systolic v2, Booth | 2055 | 17,561 | 5 | 8.10 | 40.5 | 87,803 |

All six original designs meet 20 ns timing with at least 9.4 ns slack.

## Winners (N=2)
| Metric | Winner | Basis |
|---|---|---|
| Cycles | Parallel (2) | measured |
| Latency (ns) | Parallel Booth 19.5, star 20.2; systolic v2 star 29.4 next | derived |
| Smallest area | Iterative Booth (9,683 um2) | synthesis |
| Best area x cycles | Parallel Booth (31,165) | derived |
| Worst area x cycles | Systolic v2 star (105,977) | derived |
| Post-route timing | undecided, needs the physical run | not measured |

## Findings
1. Parallel has the lowest latency; about 1.9x the area of iterative for 4x fewer cycles.
2. Systolic v1 is the largest and slower than parallel at 2x2 (fill delay, per-PE registers).
3. Registering the feed (v2) cut the star critical path from 9.90 to 5.87 ns and area by 10.7%, at the cost of one cycle. For Booth, area rose 3.6% and the delay gain was smaller; cause not explained.
4. Booth is 9% (iterative), 21% (parallel) and 29% (systolic v1) smaller than star, but not always faster.
5. On the SoC all architectures give the same end-to-end time (424 cycles, bus-bound).

## Scaling (synthesis-only, star, systolic v1)
| N | Iterative area | Parallel area | Systolic v1 area |
|---|---|---|---|
| 2 | 10,590 | 19,664 | 23,724 |
| 4 | 27,483 | 78,102 | 91,877 |
| 8 | 93,873 | 299,012 | 353,159 |
Parallel and systolic area grow about 4x per doubling of N; systolic v1 is 15-24% larger than parallel at every N.

## Limitations (do not claim)
- N=4/N=8 critical-path numbers are retracted (unbuffered high-fanout net artifact); no claim that systolic scales better.
- N=4/N=8 never functionally simulated; scaling used v1, not v2.
- Area x cycles is single-operation and ignores back-to-back systolic throughput (pipelined version not built).
- Post-route timing and power not measured.
- Files: architecture_ppa_20ns_v2.csv, architecture_summary_v2.csv, architecture_v2.png, scaling_all.csv (area only), scaling.png (area only)
# Experiment 3: multiplication algorithms (8-bit signed)

## Setup
- Five multipliers: star (inferred '*'), Booth radix-4, array (chain of shifted partial products), sequential shift-add, Wallace tree (Baugh-Wooley partial products, 3:2 and 2:2 compressors, final adder; generated by software/gen_wallace.py)
- Correctness: all 65,536 signed operand pairs PASS for each (tb_multipliers, tb_mult_array, tb_mult_wallace)
- PPA: Yosys + OpenSTA, Sky130HD tt_025C_1v80, ideal wires; combinational blocks timed input to output against a virtual clock
- First-order numbers; abc -D has no effect (20, 10 and 5 ns runs identical), so one data point per design

## Results (synthesis + OpenSTA)
| Multiplier | Cells | Area (um2) | Delay (ns) | Cycles | Latency (ns) | Area x delay (DERIVED) |
|---|---|---|---|---|---|---|
| star (*) | 319 | 2,345 | 3.47 | 1 | 3.47 | 8,136 |
| Booth radix-4 | 272 | 1,913 | 4.59 | 1 | 4.59 | 8,781 |
| array (chain) | 338 | 2,395 | 3.74 | 1 | 3.74 | 8,957 |
| shift-add (seq.) | 293 | 2,937 | 5.76 per cycle | 8 | 46.08 | n/a |
| Wallace tree | 272 | 1,959 | 3.46 | 1 | 3.46 | 6,779 |

## Findings
1. Booth is the smallest: about 18% smaller than star and 20% smaller than array, but about 32% slower than star.
2. Wallace has the best area x delay (about 6,779, DERIVED) among the single-cycle designs; star is next (8,136). Wallace is about 16% smaller than star at the same delay, and about 25% faster than Booth at 2.4% more area.
3. Array gives no gain over star (2% larger, 8% slower).
4. Shift-add is worst on every metric. 61 dfrtp_1 flops take 1,530 um2, 52% of its 2,937 um2, so registers cost more than the adder logic at 8 bits.

## Limitations (do not claim)
- Do not claim Yosys maps '*' to the same structure as the array multiplier; not verified.
- Wallace tree implemented and tested (all 65,536 pairs PASS); Dadda not implemented. The final carry-propagate add is a plain '+' mapped by Yosys/ABC, so part of the Wallace gain may come from ABC and not from the tree alone.
- Wallace is standalone only: it is not selectable through the accelerator MULT parameter (0 = star, 1 = Booth), same as array and shift-add.
- Ideal wires, lpflow cells not excluded: absolute numbers slightly optimistic; compare designs with each other only.
- Files: multiplier_comparison.csv, multiplier_comparison.png
