# AI Accelerator with Custom RISC-V

A 2×2, 8-bit signed matrix-multiplication accelerator attached to a PicoRV32 RISC-V SoC, studied end to end on the open SkyWater SKY130HD platform: RTL, verification, synthesis, place and route, sign-off checks, gate-level simulation and power.

**Authors:** Shiv Kumar (23118048), Harsh Mishra (23118052)
**Supervisor:** Dr. Rachna Singh, Dept. of ECE, JIIT Noida (B.Tech major project, Nov 2026)

## The question

For identical 2×2 matrices, how much faster and more energy-efficient is a CPU that offloads the multiplication to a hardware accelerator than the same CPU multiplying in software? Which accelerator architecture and which multiplier give the best trade-off between cycles, area and critical path?

| Experiment | Folder |
|---|---|
| 1. CPU-only vs accelerator-assisted (AXI-Lite and XMAT) | `Exp_1_Accelerator_vs_Software/` |
| 2. Which architecture is best (iterative / parallel / systolic) | `Exp_2_Architectures/` |
| 3. Which multiplier algorithm is best | `Exp_3_Multipliers/` |
| Report, golden model, shared logs and scripts | `common/` |

Each experiment has `rtl/`, `testbench/`, `scripts/` and `results/{csv,logs,images}`.

## Headline results

| Topic | Result |
|---|---|
| Correctness | CPU, accelerator and NumPy agree in all 144 SoC runs (24 data sets × 6 configurations); 1,006 vectors per design; all 65,536 input pairs per multiplier |
| Speedup (AXI-Lite) | 1.74× to 11.82×, mean about 8.2× over software shift-add (737 to 5,013 CPU cycles vs a constant 424) |
| Bottleneck | At least 15 AXI-Lite transfers (about 25 to 28 cycles each) dominate the 424 cycles, not the 2 to 8 compute cycles, so architecture choice is invisible at SoC level |
| Custom instruction (XMAT) | 258 to 264 cycles including 220 cycles of operand packing: 14.4× to 14.7× over software on 18 data sets (AXI-Lite: 8.97× on the same sets), or 38 to 44 cycles with pre-packed operands. Costs +7.3% to +12.8% SoC cell area (synthesis only) |
| Architectures (N = 2) | Iterative 8 cycles, parallel 2, systolic v2 5. Parallel is fastest; iterative is smallest; systolic v2 does not pay off for a single 2×2 operation |
| Multipliers | Dadda is smallest in all three engines; Wallace has the lowest compute latency (18.3 ns, parallel engine) and the best standalone area × delay; the inferred `*` is a strong baseline |
| Physical (50 MHz, typical corner) | 0 routing, 0 Magic DRC, 0 LVS violations, worst setup slack 13.31 ns; post-route gate-level simulation matches RTL |
| Power | About 19.3 mW in both paths; energy per multiply falls 6.2× to 11.2× (data sets S1 and S2) because the run is shorter, not because power drops |

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

The accelerator is added without changing the CPU. Spec v0.1: 8-bit signed operands, 16-bit product, 20-bit accumulator, 20 ns clock, ROM `0x0000_0000`, SRAM `0x0001_0000`, UART `0x1000_0000`.

**Registers** (offset from `0x2000_0000`): `0x00` CTRL (START), `0x04` STATUS (BUSY, DONE), `0x08` CYCLES, `0x10-0x1C` A[0..3], `0x20-0x2C` B[0..3], `0x30-0x3C` C[0..3], `0x40` ID.

**XMAT:** `XMAT.RUN` (custom-0, funct3 `000`) takes A and B packed into rs1/rs2, runs the engine and returns C[0]; `XMAT.GET` (funct3 `001`, funct7 = index) returns C[index].

## Architectures and multipliers

N = 2, Yosys + OpenSTA, SKY130HD typical corner, ideal wires, 20 ns clock.

| Architecture | Cycles | Area (µm², star / Booth) | Critical path (ns, star) |
|---|---|---|---|
| Iterative (1 MAC) | 8 | 10,594 / 9,666 | 7.54 |
| Parallel (4 MACs) | 2 | 19,497 / 15,728 | 9.47 |
| Systolic v2 (2×2 PEs) | 5 | 21,284 / 17,564 | 6.06 |

The full 16-configuration table (six multipliers in the iterative engine, five in the parallel and systolic engines) is in `Exp_2_Architectures/results/csv/`.

| Multiplier (standalone 8×8) | Area (µm²) | Delay | Area × delay |
|---|---|---|---|
| Inferred `*` | 2,345 | 3.47 ns | 8,136 |
| Radix-4 Booth | 1,913 | 4.59 ns | 8,781 |
| Array | 2,395 | 3.74 ns | 8,957 |
| Wallace tree | 1,959 | 3.46 ns | **6,779** |
| Dadda tree | **1,809** | 5.24 ns | 9,480 |
| Shift-add (8 cycles) | 2,937 | 5.76 ns/cycle | n/a |

Notes:
- Two independent synthesis runs of the same designs differed by up to 0.93% in area and 8.7% in critical delay (cause not determined), so differences below about 1% in area or 9% in critical delay are within the run-to-run spread.
- Wallace and Dadda end in a plain `+` mapped by Yosys/ABC, so part of their results may come from the tool and not from the tree alone.
- A systolic array does not finish a matrix multiplication in one cycle; for a single 2×2 operation it does not pay off.

## Physical implementation

OpenLane 1 on sky130A, 1000 × 1000 µm die, 35% utilisation, ARCH 2 with the inferred multiplier: 24,863 synthesised cells, 0 detailed-routing violations, 0 Magic DRC, 0 LVS errors, 12 antenna violations remain. Activity-based power uses OpenSTA 3.1.0 with SPEF parasitics (about 95% is clock and sequential power).

## Verification

Independent Python/NumPy golden model (MATLAB was not available in the lab), self-checking SystemVerilog testbenches in Verilator 5.052, real bare-metal firmware on the CPU, equivalence of converted Verilog-2005 sources, and a zero-delay gate-level simulation of the post-route netlist. Testbenches fail if the number of vectors run is not the expected count.

## Scope and limitations

- No silicon, FPGA or tape-out result is claimed. All results are simulation, synthesis and layout level.
- Speedup and energy figures are against a simple software shift-add baseline (`ENABLE_MUL = 0`); a stronger baseline would reduce them. Every figure names its data set.
- Post-route, gate-level and power results cover **ARCH 2 with the inferred multiplier only**. XMAT and Dadda have synthesis-level results only. Power is a whole-SoC value from zero-delay activity, for data sets S1 and S2.
- XMAT and Dadda-through-AXI runs cover 18 of the 24 data sets.
- Typical corner and 50 MHz only. Min/max corners, KLayout DRC, formal equivalence and SDF gate-level simulation were not run. 12 antenna violations remain.
- Only 2×2 matrices are supported.
- The custom five-stage CPU, full MATMUL instruction, DMA, dual-port SRAM and 4×4 array of the original synopsis were not implemented.

## Tools

Verilator 5.052, Yosys 0.64 (0.30 inside OpenLane), OpenSTA 3.1.0, OpenLane 1 / OpenROAD, Magic, KLayout, RISC-V GCC 15.2.0, Python 3 (NumPy, Pandas, Matplotlib).

## Reproduce

Scripts were run in the original lab layout (`~/AI_ACCELERATOR_RISCV`); paths inside them must be adjusted to run from this folder. Scripts for the XMAT, Dadda and 16-configuration studies are in `Exp_1/scripts`, `Exp_2/scripts` and `Exp_3/scripts`.

```bash
python software/reference/gen_vectors.py     # 1,006 test vectors
scripts/synth_arch.sh 20                     # architecture synthesis and timing
scripts/synth_mult.sh 20                     # multiplier synthesis and timing
scripts/soc_run.sh <ARCH> <MULT>             # full SoC with firmware
sha256sum -c SHA256SUMS.txt                  # integrity check
```
