# Architecture decisions

1. CPU: PicoRV32 kept (ENABLE_MUL=0) rather than a custom 5-stage core: smaller scope, and the CPU-only baseline uses software shift-add multiply.
2. Integration: AXI-Lite memory-mapped slave 3 at 0x2000_0000. No CPU decode changes. Custom instruction (XMAT) is a proposal only, not implemented.
3. Format: 8-bit signed, 16-bit product, 20-bit accumulator, wrap. 20 bits is sufficient up to N=16.
4. Clock: 20 ns (50 MHz) to match top.sdc. 100 MHz not supported by timing results.
5. Reset: active-high async at the SoC boundary; new engines use active-low rst_n internally, wrapper inverts.
6. Simulator: Verilator (Icarus failed on uart_axi.v and the synth.v netlist).
7. Systolic v2: feed registered (a_q/b_q). Critical path 9.90 -> 5.87 ns (star) at the cost of 1 cycle (3N-1 = 5). v1 kept in rtl/matmul_systolic_v1_backup.sv.
8. Async reset and synchronous clear split in the systolic PE (Yosys rejects 'if (!rst_n || clr)').
9. Physical flow: OpenLane 1 (area-oriented config) for SoC runs; Yosys+OpenSTA for first-order PPA only.
10. OpenLane Yosys 0.30 lacks int'( casts and packed 2-D arrays: interconnect flattened and converted to Verilog (*_conv.v) by lab Yosys 0.64.

## Retracted / not claimed
- N=4 and N=8 critical-path numbers (unbuffered high-fanout net artifact)
- "Systolic scales better than parallel"
- Power values; 100 MHz operation; tapeout readiness
