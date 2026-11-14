// =============================================================
// hazard_unit.v - Hazard Detection Unit
//
// Detects the ONE case that cannot be solved by forwarding alone:
// a load in EX (i.e. sitting in ID/EX) whose destination register
// is needed by the instruction currently in ID. Because the loaded
// value isn't available until the end of MEM, the dependent
// instruction must stall for exactly one cycle (bubble in ID/EX)
// while the PC and IF/ID register are frozen.
//
// All other RAW hazards (ALU-to-ALU back-to-back, etc.) are
// resolved with zero stall cycles by the Forwarding Unit.
// =============================================================
module hazard_unit (
    input  wire        id_ex_mem_read,     // instruction in EX is a load
    input  wire [4:0]  id_ex_rt,           // its destination register
    input  wire [4:0]  if_id_rs,           // source regs of instr in ID
    input  wire [4:0]  if_id_rt,

    output wire        stall_pc,           // freeze PC
    output wire        stall_if_id,        // freeze IF/ID register
    output wire        bubble_id_ex        // force ID/EX control = 0 (NOP)
);

    wire load_use_hazard = id_ex_mem_read &&
                            ((id_ex_rt == if_id_rs) || (id_ex_rt == if_id_rt)) &&
                            (id_ex_rt != 5'd0);

    assign stall_pc    = load_use_hazard;
    assign stall_if_id = load_use_hazard;
    assign bubble_id_ex = load_use_hazard;

endmodule
