# AI Accelerator with Custom RISC-V

2x2 8-bit signed matrix-multiplication accelerator attached to a PicoRV32 SoC (AXI-Lite and a custom XMAT instruction), evaluated on SkyWater SKY130HD with open-source tools.

**Authors:** Shiv Kumar (23118048), Harsh Mishra (23118052)
**Supervisor:** Dr. Rachna Singh, Dept. of ECE, JIIT Noida (B.Tech major project, Nov 2026)

## Layout
| Folder | Question answered |
|---|---|
| `Exp_1_Accelerator_vs_Software/` | How much faster is the CPU with the accelerator? |
| `Exp_2_Architectures/` | Which architecture (iterative / parallel / systolic) is best? |
| `Exp_3_Multipliers/` | Which multiplier algorithm is best? |
| `common/` | Report, golden model, original proposal, shared evidence |

Each experiment has `rtl/`, `testbench/`, `scripts/` and `results/{csv,logs,images}`.

## Headline results (simulation and synthesis level)
- Software shift-add: about 740 to 5,000 cycles. AXI-Lite accelerator: 424 cycles (about 8x). XMAT instruction: 258-264 cycles with packing (about 14x, 18 sets).
- Architectures: iterative 8 cycles, parallel 2, systolic 5; all show 424 cycles through the bus.
- Multipliers: 6 designs, 16 configurations, no single winner.
- Physical run (ARCH 2, star, 50 MHz): 0 routing, 0 Magic DRC, 0 LVS violations, 13.31 ns setup slack.

## Limitations
Typical corner only; 2x2 only; synthesis-level area for XMAT and Dadda; 18 of 24 original data sets recovered; software baseline has no hardware multiplier. Not claimed: silicon, FPGA, tape-out, 100 MHz, formal equivalence.

## Note on scripts
Scripts were run in the original lab layout (`~/AI_ACCELERATOR_RISCV`); paths inside them must be adjusted to run from this folder.

## Integrity
`SHA256SUMS.txt` has a checksum for every file.
