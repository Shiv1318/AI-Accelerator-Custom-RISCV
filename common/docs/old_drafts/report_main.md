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

Equivalence check: the Yosys-converted soc_a2m0 sources (axi_lite_interconnect_conv.v, matmul_axil_conv.v) were simulated with the same testbench and rom.hex. Result identical to the RTL run (S1 cpu=2619, S2 cpu=4765, e2e=424, hw=5, ok=1). Log: results/simulation/soc_a2m0_converted_equiv.log
