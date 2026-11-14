# =====================================================================
# Verification program for the 5-stage pipeline
# Section 1: baseline single-instruction correctness
# Section 2: back-to-back RAW hazards (EX/MEM and MEM/WB forwarding)
# Section 3: load-use hazard (must stall exactly one cycle)
# Section 4: branch taken / not taken, including a branch whose
#            operand is produced by the immediately preceding
#            instruction (forwarded into the ID-stage comparator)
# =====================================================================

# ---- Section 1: baseline ----
addi $1, $0, 5          # r1 = 5
addi $2, $0, 10         # r2 = 10

# ---- Section 2: back-to-back ALU RAW hazards ----
add  $3, $1, $2         # r3 = r1+r2 = 15   (EX/MEM -> EX forward on r2)
sub  $4, $3, $1         # r4 = r3-r1 = 10   (EX/MEM -> EX forward on r3, back-to-back)
and  $5, $3, $2         # r5 = 15 & 10 = 10 (MEM/WB -> EX forward on r3)
or   $6, $1, $2         # r6 = 5 | 10 = 15
slt  $7, $1, $2         # r7 = (5<10) = 1

# ---- Section 3: load-use hazard ----
addi $8, $0, 100        # r8 = 100 (byte address, word index 25)
sw   $2, 0($8)          # mem[100] = r2 = 10
lw   $9, 0($8)          # r9 = mem[100] = 10
add  $10, $9, $1        # r10 = r9+r1 = 15  <-- load-use hazard: 1 stall cycle required

# ---- Section 4a: branch NOT taken ----
addi $15, $0, 1
addi $16, $0, 2
beq  $15, $16, SKIP1    # 1 != 2 -> not taken
addi $17, $0, 222       # executed: r17 = 222
SKIP1:
addi $18, $0, 333       # executed regardless: r18 = 333

# ---- Section 4b: branch taken, skips two instructions ----
addi $20, $0, 7
addi $21, $0, 7
beq  $20, $21, SKIP2    # 7 == 7 -> taken, must flush IF/ID
addi $22, $0, 999       # SQUASHED - must never execute
addi $22, $0, 999       # SQUASHED - must never execute
SKIP2:
addi $23, $0, 111       # executed: r23 = 111

# ---- Section 4c: branch depends on immediately preceding ALU result ----
# (tests ID-stage branch forwarding, not just EX-stage forwarding)
addi $24, $0, 50
add  $25, $24, $0       # r25 = 50, produced the cycle before BEQ decodes it
beq  $25, $24, SKIP3    # needs EX/MEM -> ID forward to compare correctly -> taken
addi $26, $0, 888       # SQUASHED - must never execute
SKIP3:
addi $27, $0, 77        # executed: r27 = 77

# ---- drain pipeline ----
addi $0, $0, 0
addi $0, $0, 0
addi $0, $0, 0
addi $0, $0, 0
addi $0, $0, 0
