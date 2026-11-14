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
    input  wire        id_uses_rt,         // instr in ID actually reads rt
    input  wire        id_is_branch,       // instr in ID is a BEQ
    input  wire        ex_mem_mem_read,    // load currently in MEM
    input  wire [4:0]  ex_mem_rd,          // its destination register

    output wire        stall_pc,           // freeze PC
    output wire        stall_if_id,        // freeze IF/ID register
    output wire        bubble_id_ex        // force ID/EX control = 0 (NOP)
);

    // (1) classic load-use: load in EX, consumer in ID (rt only counts if
    //     the consumer really reads rt -> no false stall on lw;addi same rt)
    wire load_use_hazard = id_ex_mem_read &&
                            ((id_ex_rt == if_id_rs) || (id_uses_rt && id_ex_rt == if_id_rt)) &&
                            (id_ex_rt != 5'd0);
    // (2) branch-in-ID needs its operand one cycle EARLIER than EX would
    //     provide it: load in MEM has only the address in EX/MEM.alu_result
    wire branch_load_hazard = id_is_branch && ex_mem_mem_read &&
                            ((ex_mem_rd == if_id_rs) || (ex_mem_rd == if_id_rt)) &&
                            (ex_mem_rd != 5'd0);
    wire any_stall = load_use_hazard | branch_load_hazard;

    assign stall_pc    = any_stall;
    assign stall_if_id = any_stall;
    assign bubble_id_ex = any_stall;

endmodule
