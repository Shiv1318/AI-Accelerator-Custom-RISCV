#!/bin/bash
# Usage (from project root): scripts/soc_run.sh <ARCH 0|1|2> <MULT 0|1>
ARCH=${1:-0}; MULT=${2:-0}
export PATH=$PATH:/apps/vlsi/tools/riscv/bin
cd soc_xmat || exit 1
(cd fw && \
 riscv32-unknown-elf-gcc -march=rv32i_zicsr -mabi=ilp32 -O2 -Wall -nostdlib -nostartfiles \
   -ffreestanding -fno-builtin -fno-tree-loop-distribute-patterns -T link.ld crt0.S main_xmat.c -o fw.elf && \
 riscv32-unknown-elf-objcopy -O binary fw.elf fw.bin && \
 python3 bin2hex.py fw.bin ../build/rom.hex && \
 riscv32-unknown-elf-size fw.elf) || { echo "firmware build failed"; exit 1; }

OBJ=build/obj_${ARCH}_${MULT}
verilator --binary --timing --timescale 1ns/1ps -Wno-fatal -Wno-lint -Wno-style \
  -DACC_ARCH=$ARCH -DACC_MULT=$MULT --top-module tb_soc_accel -Mdir $OBJ \
  src/picorv32.v src/rom.v src/sram.v src/uart_axi.v src/uart_tx.v src/uart_rx.v src/top.v \
  src/axi_decoder.sv src/axi_lite_interconnect.sv \
  ../rtl_dadda_acc/mult_star.sv ../rtl_dadda_acc/mult_booth.sv ../rtl_dadda_acc/mult_sel.sv ../rtl_dadda_acc/mult_dadda.sv ../rtl_dadda_acc/mult_wallace.sv ../rtl_dadda_acc/mult_array.sv ../rtl_dadda_acc/mult_shiftadd.sv ../rtl_dadda_acc/matmul_iter.sv ../rtl_dadda_acc/matmul_par.sv \
  ../rtl_dadda_acc/systolic_pe.sv ../rtl_dadda_acc/matmul_systolic.sv ../rtl_dadda_acc/matmul_axil.sv ../rtl_dadda_acc/pcpi_matmul.sv tb/tb_soc_accel.sv \
  > build/vl_${ARCH}_${MULT}.log 2>&1
grep -m5 "%Error" build/vl_${ARCH}_${MULT}.log
timeout 600 $OBJ/Vtb_soc_accel +romhex=build/rom.hex | tee build/run_${ARCH}_${MULT}.log
