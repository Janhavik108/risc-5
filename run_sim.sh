#!/usr/bin/env bash
# Assemble the test program and run the self-checking testbench with
# Icarus Verilog. (For ModelSim/Questa, see README.md for the
# equivalent `vlog`/`vsim` commands - the RTL is plain Verilog-2001
# and needs no changes.)
set -e
cd "$(dirname "$0")"

python3 tb/assemble.py tb/program.asm tb/program.hex
cp tb/program.hex rtl/program.hex

iverilog -g2012 -I rtl -o sim/sim.out \
  rtl/pc_reg.v rtl/instr_mem.v rtl/reg_file.v rtl/sign_extend.v \
  rtl/control_unit.v rtl/alu_control.v rtl/alu.v rtl/data_mem.v \
  rtl/hazard_unit.v rtl/forward_unit.v rtl/if_id_reg.v rtl/id_ex_reg.v \
  rtl/ex_mem_reg.v rtl/mem_wb_reg.v rtl/pipeline_top.v \
  tb/tb_pipeline_top.v

cd rtl && vvp ../sim/sim.out
mv pipeline_wave.vcd ../sim/ 2>/dev/null || true
