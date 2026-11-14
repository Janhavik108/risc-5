# 5-Stage Pipelined RISC Processor (Verilog)

A synthesizable 5-stage pipelined RISC datapath (MIPS-style encoding) in plain Verilog-2001, with a forwarding unit, a load-use hazard unit, decode-stage branch resolution, and a self-checking testbench. Verified with Icarus Verilog and ModelSim; the RTL compiles with 0 errors and 0 warnings.

## Pipeline

```
IF -> ID -> EX -> MEM -> WB
```

| Feature | Implementation |
|---|---|
| ISA | R-type (`add`, `sub`, `and`, `or`, `slt`), `addi`, `lw`, `sw`, `beq` |
| ALU forwarding | EX/MEM -> EX and MEM/WB -> EX for both operands; back-to-back ALU dependences run with zero stalls |
| Branch operand forwarding | EX-ALU -> ID, EX/MEM -> ID and MEM/WB -> ID feed the decode-stage comparator |
| Load-use hazard | Load in EX with a dependent instruction in ID: PC and IF/ID freeze, ID/EX gets a bubble (1 cycle) |
| Load-to-branch hazard | A `beq` in ID whose operand comes from a load still in MEM waits one extra cycle, because `EX/MEM.alu_result` holds the address, not the data |
| Branch handling | Resolved in ID; a taken branch squashes exactly one fetched instruction by flushing IF/ID |
| Register file | Write-through, so a WB write and an ID read of the same register in one cycle return the new value; `r0` is hardwired to 0 |

## File layout

```
rtl/
  defines.vh         opcode / funct / ALU-op encodings, forwarding-select constants
  pc_reg.v           program counter (stall / branch-target mux)
  instr_mem.v        instruction memory ($readmemh from program.hex)
  reg_file.v         32x32 register file, write-through, r0 = 0
  sign_extend.v      16 -> 32 bit sign extension
  control_unit.v     main decoder (ID stage)
  alu_control.v      ALU op decoder (EX stage)
  alu.v              ALU (add / sub / and / or / signed slt, zero flag)
  data_mem.v         data memory (MEM stage)
  hazard_unit.v      load-use and load-to-branch stall detection
  forward_unit.v     EX/MEM->EX, MEM/WB->EX and ID-branch forwarding muxes
  if_id_reg.v  id_ex_reg.v  ex_mem_reg.v  mem_wb_reg.v    pipeline registers
  pipeline_top.v     top-level wiring
tb/
  program.asm        base test program          assemble.py   2-pass assembler -> program.hex
  tb_pipeline_top.v  base self-checking testbench (26 checks)
  program_ext.asm    extension tests T-A ... T-K
  tb_ext.v           extension testbench
tools/
  mutation_runner.py injects 17 hand-written bugs and reports which tests catch them
run_sim.sh           assemble + compile + run (Icarus)
```

## Running

### Icarus Verilog (Linux / macOS / WSL)

```bash
mkdir -p sim
./run_sim.sh
```

Expected tail:

```
RESULT: ALL 26 CHECKS PASSED
```

### Extension tests

```bash
python3 tb/assemble.py tb/program_ext.asm rtl/program.hex
iverilog -g2012 -I rtl -o sim/ext.out rtl/*.v tb/tb_ext.v
cd rtl && vvp ../sim/ext.out
```

Expected: `stalls=6 flushes=2 errors=0`.

### ModelSim / Questa (run from the repo root, not from `rtl/`)

```tcl
vlib work
vlog +incdir+rtl rtl/*.v tb/tb_pipeline_top.v
file copy -force tb/program.hex program.hex
vsim -c work.tb_pipeline_top -do "run -all; quit"
```

`instr_mem.v` reads `program.hex` by a relative path, so launch `vsim` from the folder that contains it.

### Windows PowerShell

Use `git apply -p1 patchfile` (the `<` redirect operator is not available), and install the Windows build of Icarus Verilog (bleyer.org) if you want `iverilog` / `vvp`.

## What the tests verify

**Base suite (`tb_pipeline_top.v`, 26 checks = 23 register/memory value checks + 3 counter conditions)**

1. Single-cycle correctness: one instruction of each type.
2. Back-to-back RAW hazards through EX/MEM and MEM/WB forwarding, with `stall_pc` never asserting.
3. Load-use hazard: correct value and exactly one stall cycle.
4. Branches: not taken, taken (wrong-path instruction squashed), and operand produced by the previous instruction. Also checks that a squashed instruction never commits a write (`saw_bad_write == 0`).

**Extension suite (`tb_ext.v`, tests T-A to T-K)** adds: two in-flight writers to one register (forwarding priority), `r0` guards, `lw` then `addi` on the same register, `lw` result consumed on `rt`, same-cycle write-through, sign extension, signed `slt`, store-data forwarding, `lw -> beq`, and a stall/flush collision.

## Verification results

- Base suite: 26 / 26 pass.
- Mutation testing: 17 injected bugs. The base suite alone catches 8 (47 %); the extension suite catches the other 9, so all 17 are killed. Re-run with `python3 tools/mutation_runner.py`.
- Two real bugs were found this way and fixed (below).

## Bugs found and fixed

| # | Symptom | Root cause | Fix |
|---|---|---|---|
| 1 | `lw` followed by `beq` that uses the loaded value branches on a wrong operand | The EX/MEM -> ID forward carries `alu_result`, which for a load is the effective address; the loaded data only exists later in MEM. The hazard unit only watched a load in EX | `hazard_unit.v`: added `branch_load_hazard` (branch in ID, load in MEM) and an extra stall cycle |
| 2 | A taken `beq` disappears when a stall and a flush coincide | `if_id_reg` gave flush priority over stall, so the held `beq` was cleared | `pipeline_top.v`: stall now wins, so the branch survives the stall |
| 3 | Unnecessary stall on `lw` followed by an instruction that only reads `rs` | Hazard unit compared `rt` even when the consumer does not read it | `hazard_unit.v`: `id_uses_rt` qualifier |

## Design note: why only IF/ID is flushed on a taken branch

`beq` resolves combinationally in ID, so only one wrong-path instruction has been fetched when the outcome is known, and it is the one about to latch into IF/ID. Flushing IF/ID costs exactly one cycle. The instruction already in ID/EX is the one before the branch and must not be squashed.

## Synthesis notes

- `data_mem.v` uses an asynchronous read for simulation simplicity. For block-RAM mapping on an FPGA, use a registered read port and adjust MEM-stage timing.
- Critical-path claims (EX stage chained into the ID-stage branch comparator) are structural estimates until you run synthesis and read the timing report.
- Everything else is plain Verilog-2001 and should synthesize as-is in Vivado, Quartus or Yosys.
