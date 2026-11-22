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
