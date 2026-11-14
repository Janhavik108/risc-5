// =============================================================
// defines.vh - ISA encoding & shared parameters for the
// 5-stage pipelined RISC processor
// =============================================================
`ifndef DEFINES_VH
`define DEFINES_VH

// ---------------- Opcodes (bits [31:26]) ----------------------
`define OP_RTYPE   6'b000000   // funct field selects ALU op
`define OP_ADDI    6'b001000
`define OP_LW      6'b100011
`define OP_SW      6'b101011
`define OP_BEQ     6'b000100

// ---------------- Funct codes for R-type -----------------------
`define FUNCT_ADD  6'b100000
`define FUNCT_SUB  6'b100010
`define FUNCT_AND  6'b100100
`define FUNCT_OR   6'b100101
`define FUNCT_SLT  6'b101010

// ---------------- ALU control (internal encoding) ---------------
`define ALU_ADD    3'b000
`define ALU_SUB    3'b001
`define ALU_AND    3'b010
`define ALU_OR     3'b011
`define ALU_SLT    3'b100

// ---------------- ALUOp (from main control to ALU control) -----
`define ALUOP_LOADSTORE 2'b00  // force ADD (address calc)
`define ALUOP_BRANCH    2'b01  // force SUB (compare)
`define ALUOP_RTYPE     2'b10  // look at funct field

// ---------------- Forwarding-mux select encodings ---------------
`define FWD_NONE   2'b00   // use value from ID/EX register file read
`define FWD_EX_MEM 2'b01   // forward from EX/MEM stage (ALU result)
`define FWD_MEM_WB 2'b10   // forward from MEM/WB stage (writeback value)
`define FWD_EX_ALU 2'b11   // ID-stage only: forward raw (unlatched) EX ALU
                            // output, for a branch that depends on the
                            // instruction immediately preceding it

// ---------------- Misc ------------------------------------------
`define WORD        31:0
`define REGBITS      4:0
`define NOP_INSTR   32'h00000000

`endif
