# AI Accelerator with Custom RISC-V

A 2x2, 8-bit signed matrix-multiplication accelerator attached to a **PicoRV32** RISC-V SoC, studied end to end on the open **SkyWater SKY130HD** platform: RTL, verification, synthesis, place and route, sign-off checks, gate-level simulation and power.

**Authors:** Shiv Kumar (23118048), Harsh Mishra (23118052)
**Supervisor:** Dr. Rachna Singh, Dept. of ECE, JIIT Noida (B.Tech major project, Nov 2026)

## The question

For identical 2x2 matrices, how much faster and more energy-efficient is a CPU that offloads the multiplication to a hardware accelerator than the same CPU multiplying in software? Which accelerator architecture and which multiplier give the best trade-off between cycles, area and critical path?

| Experiment | Folder |
|---|---|
| 1. CPU-only vs accelerator-assisted | `Exp_1_Accelerator_vs_Software/` |
| 2. Which architecture is best (iterative / parallel / systolic) | `Exp_2_Architectures/` |
| 3. Which multiplier algorithm is best | `Exp_3_Multipliers/` |
| Report, golden model, shared logs and scripts | `common/` |

Each experiment has `rtl/`, `testbench/`, `scripts/` and `results/{csv,logs,images}`.

## Headline results

| Topic | Result |
|---|---|
| Correctness | CPU, accelerator and NumPy agree in all **144 SoC runs** (24 data sets x 6 configurations); 1,006 vectors per design; all 65,536 input pairs per multiplier |
| Speedup (AXI-Lite) | **1.74x to 11.82x**, mean about **8.2x** over software shift-add (737 to 5,013 CPU cycles vs a constant 424) |
| Bottleneck | The AXI-Lite bridge (about 17 transfers) dominates, not the 2 to 8 compute cycles, so architecture choice is invisible at SoC level |
| Custom instruction (XMAT) | About 258 to 264 cycles with operand packing (about 14x, 18 data sets) |
| Architectures (N=2) | Iterative 8 cycles, parallel 2, systolic v2 5. Parallel is fastest, iterative Booth smallest, systolic v2 has the shortest clock path (5.87 ns) |
| Multipliers | Wallace tree has the best area x delay among single-cycle designs, Booth is smallest, the inferred `*` is a strong baseline |
| Physical (50 MHz) | 0 routing, 0 Magic DRC, 0 LVS violations, worst setup slack 13.31 ns; post-route gate-level simulation matches RTL |
| Power | About 19.3 mW in both paths; energy per multiply falls 6.2x to 11.2x because the run is shorter, not because power drops |

## Design

```
 PicoRV32 (RV32I, no HW multiply)
        |  AXI-Lite master
 AXI-Lite interconnect (1 master, 4 slaves)
   |         |        |         |
  ROM      SRAM     UART    Accelerator (slave 3, 0x2000_0000)
                              wrapper -> engine (ARCH 0/1/2) + multiplier (MULT)

 Optional: PicoRV32 PCPI port -> pcpi_matmul (XMAT custom-0 instruction)
```

The accelerator is added **without changing the CPU**. Spec v0.1: 8-bit signed operands, 16-bit product, 20-bit accumulator, 20 ns clock, ROM `0x0000_0000`, SRAM `0x0001_0000`, UART `0x1000_0000`.

**Registers** (offset from `0x2000_0000`): `0x00` CTRL (START), `0x04` STATUS (BUSY, DONE), `0x08` CYCLES, `0x10-0x1C` A[0..3], `0x20-0x2C` B[0..3], `0x30-0x3C` C[0..3], `0x40` ID.

**XMAT:** `XMAT.RUN` (custom-0, funct3 000) takes A and B packed into `rs1`/`rs2`, runs the engine and returns C[0]; `XMAT.GET` (funct3 001, funct7 = index) returns C[index].

### Architectures and multipliers (N = 2, Yosys + OpenSTA, typical corner, ideal wires)

| Architecture | Cycles | Area (um2, star / Booth) | Critical path (ns, star) |
|---|---|---|---|
| Iterative (1 MAC) | 8 | 10,590 / 9,683 | 8.26 |
| Parallel (4 MACs) | 2 | 19,664 / 15,582 | 10.09 |
| Systolic v2 (2x2 PEs) | 5 | 21,195 / 17,561 | 5.87 |

| Multiplier | Area (um2) | Delay | Area x delay |
|---|---|---|---|
| Inferred `*` | 2,345 | 3.47 ns | 8,136 |
| Radix-4 Booth | 1,913 | 4.59 ns | 8,781 |
| Array | 2,395 | 3.74 ns | 8,957 |
| Wallace tree | 1,959 | 3.46 ns | 6,779 |
| Shift-add (8 cycles) | 2,937 | 5.76 ns/cycle | n/a |

A systolic array does not finish a matrix multiplication in one cycle; for a single 2x2 operation it does not pay off.

## Physical implementation

OpenLane 1 on sky130A, 1000 x 1000 um die, 35% utilisation, ARCH 2 with the inferred multiplier: 24,863 synthesised cells, 0 detailed-routing violations, 0 Magic DRC, 0 LVS errors, 12 antenna violations remain. Activity-based power uses OpenSTA 3.1.0 with SPEF parasitics (about 95% is clock and sequential power).

## Verification

Independent Python/NumPy golden model (MATLAB was not available in the lab), self-checking SystemVerilog testbenches in Verilator 5.052, real bare-metal firmware on the CPU, equivalence of converted Verilog-2005 sources, and a zero-delay gate-level simulation of the post-route netlist. Testbenches fail if the number of vectors run is not the expected count.

## Tools

Verilator 5.052, Yosys 0.64 (0.30 inside OpenLane), OpenSTA 3.1.0, OpenLane 1 / OpenROAD, Magic, RISC-V GCC 15.2.0, Python 3 (NumPy, Pandas, Matplotlib).

## Reproduce

Scripts were run in the original lab layout (`~/AI_ACCELERATOR_RISCV`); paths inside them must be adjusted to run from this folder.

```bash
python software/reference/gen_vectors.py     # 1,006 test vectors
scripts/synth_arch.sh 20                     # architecture synthesis and timing
scripts/synth_mult.sh 20                     # multiplier synthesis and timing
scripts/soc_run.sh <ARCH> <MULT>             # full SoC with firmware
sha256sum -c SHA256SUMS.txt                  # integrity check
```
