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

## Key findings

- **Compute-only and end-to-end speedups are very different.** The engine alone is 433× to 1,733× faster than software, but the CPU sees only about 8× because the AXI-Lite bridge, not the engine, sets the time.
- **A custom instruction removes most of the bus cost.** XMAT is about 1.6× faster than AXI-Lite even with packing. Packing the eight operands into two registers takes 220 cycles (83% to 85% of the XMAT time), so pre-packed operands would be the next improvement.
- **No single multiplier wins every metric.** Dadda gives the smallest area, Wallace the lowest latency and best area × delay.
- **Energy saving comes from run time only.** There is no clock gating, and about 95% of SoC power is clock and sequential power.

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

**XMAT:** `XMAT.RUN` (custom-0, funct3 `000`) takes A and B packed into rs1/rs2, runs the engine and returns C[0]; `XMAT.GET` (funct3 `001`, funct7 = index) returns C[index]. Three `GET` instructions are needed after `RUN` to read all four results.

## Results in detail

### Speedup over software (AXI-Lite, 24 data sets)

The AXI-Lite path takes a constant 424 cycles (8.5 µs at 50 MHz); the software time depends on the data.

| Data-set group | Sets | End-to-end speedup, mean (min–max) |
|---|---|---|
| Random | 16 | 9.00× (7.67–10.05) |
| Standard S1, S2 | 2 | 8.71× (6.18–11.24) |
| Identity | 2 | 5.74× (2.62–8.86) |
| Zeros | 2 | 3.97× (1.74–6.19) |
| All ones | 1 | 3.50× |
| Worst case (−128 × −128) | 1 | 11.82× |

### Energy per 2×2 multiply (ARCH 2 / inferred multiplier, whole SoC)

| Path | Data set | Cycles | Power | Energy | CPU / accel. |
|---|---|---|---|---|---|
| CPU software multiply | S1 | 2,619 | 19.3 mW | 1.011 µJ | |
| Accelerator (end-to-end) | S1 | 424 | 19.3 mW | 0.164 µJ | 6.2× |
| CPU software multiply | S2 | 4,765 | 19.4 mW | 1.849 µJ | |
| Accelerator (end-to-end) | S2 | 424 | 19.4 mW | 0.165 µJ | 11.2× |

### Architectures and multipliers: 16 configurations

N = 2, Yosys + OpenSTA, SKY130HD typical corner, ideal wires, 20 ns clock. Latency = cycles × critical delay (compute only, no bus).

| Architecture | Multiplier | Area (µm²) | Crit. path (ns) | Cycles | Latency (ns) |
|---|---|---|---|---|---|
| Iterative | Inferred `*` | 10,593.9 | 7.54 | 8 | 60.3 |
| Iterative | Booth | 9,665.5 | 9.35 | 8 | 74.8 |
| Iterative | Wallace | 9,649.3 | 7.92 | 8 | 63.4 |
| Iterative | Array | 10,161.0 | 9.30 | 8 | 74.4 |
| Iterative | Shift-add | 10,413.7 | 5.87 | 80 | 469.6 |
| Iterative | Dadda | **9,389.0** | 9.12 | 8 | 73.0 |
| Parallel | Inferred `*` | 19,497.4 | 9.47 | 2 | 18.9 |
| Parallel | Booth | 15,727.6 | 10.59 | 2 | 21.2 |
| Parallel | Wallace | 16,379.5 | 9.13 | 2 | **18.3** |
| Parallel | Array | 18,502.7 | 10.49 | 2 | 21.0 |
| Parallel | Dadda | 15,621.2 | 10.24 | 2 | 20.5 |
| Systolic v2 | Inferred `*` | 21,284.2 | 6.06 | 5 | 30.3 |
| Systolic v2 | Booth | 17,564.3 | 8.21 | 5 | 41.1 |
| Systolic v2 | Wallace | 17,830.9 | 7.85 | 5 | 39.2 |
| Systolic v2 | Array | 19,806.5 | 7.79 | 5 | 39.0 |
| Systolic v2 | Dadda | 17,301.6 | 7.49 | 5 | 37.5 |

Five configurations are Pareto-optimal in area vs latency: iterative inferred, Wallace and Dadda, and parallel Wallace and Dadda. Because every configuration shows 424 cycles at SoC level, this front matters only if the bus cost is reduced.

### Standalone multipliers (8×8)

| Multiplier | Area (µm²) | Delay | Area × delay |
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

OpenLane 1 on sky130A, 1000 × 1000 µm die, 35% utilisation, ARCH 2 with the inferred multiplier: 24,863 synthesised cells, 0 detailed-routing violations, 0 Magic DRC, 0 LVS errors, worst setup slack 13.31 ns, 12 antenna violations remain. Activity-based power uses OpenSTA 3.1.0 with SPEF parasitics (about 95% is clock and sequential power).

## Verification

Independent Python/NumPy golden model (MATLAB was not available in the lab), self-checking SystemVerilog testbenches in Verilator 5.052, real bare-metal firmware on the CPU, equivalence of converted Verilog-2005 sources, and a zero-delay gate-level simulation of the post-route netlist. Testbenches fail if the number of vectors run is not the expected count.

## Tools

Verilator 5.052, Yosys 0.64 (0.30 inside OpenLane), OpenSTA 3.1.0, OpenLane 1 / OpenROAD, Magic, KLayout, RISC-V GCC 15.2.0, Python 3 (NumPy, Pandas, Matplotlib).


```
