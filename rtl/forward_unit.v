// =============================================================
// forward_unit.v - Forwarding (Bypass) Unit
//
// Resolves RAW data hazards with ZERO stall cycles for ALU
// operations by forwarding the most recent value:
//
//   EX/MEM  -> EX   ("EX-to-EX" forwarding: result is one cycle old,
//                     highest priority)
//   MEM/WB  -> EX   ("MEM-to-EX" forwarding: result is two cycles old)
//
// A second, independent pair of forwarding paths feeds the
// ID-stage branch comparator (branch is resolved in ID to
// minimize branch penalty), so a BEQ that depends on the
// immediately preceding ALU result still reads the correct,
// up-to-date operand instead of a stale register-file value.
// =============================================================
`include "defines.vh"

module forward_unit (
    // ---- EX-stage ALU operand forwarding ----
    input  wire [4:0] id_ex_rs,
    input  wire [4:0] id_ex_rt,

    input  wire        ex_mem_reg_write,
    input  wire [4:0]  ex_mem_rd,

    input  wire        mem_wb_reg_write,
    input  wire [4:0]  mem_wb_rd,

    output reg  [1:0]  forward_a,   // selects ALU input A source
    output reg  [1:0]  forward_b,   // selects ALU input B source

    // ---- ID-stage branch comparator forwarding ----
    input  wire [4:0]  if_id_rs,
    input  wire [4:0]  if_id_rt,
    // instruction currently in EX (one stage ahead of the branch in ID);
    // its result is still combinational and hasn't reached EX/MEM yet
    input  wire        id_ex_reg_write,
    input  wire [4:0]  id_ex_write_reg,
    output reg  [1:0]  forward_branch_a,
    output reg  [1:0]  forward_branch_b
);

    // ------------------- EX/ALU forwarding -------------------
    always @(*) begin
        // Operand A (rs)
        if (ex_mem_reg_write && (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rs))
            forward_a = `FWD_EX_MEM;
        else if (mem_wb_reg_write && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rs))
            forward_a = `FWD_MEM_WB;
        else
            forward_a = `FWD_NONE;

        // Operand B (rt)
        if (ex_mem_reg_write && (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rt))
            forward_b = `FWD_EX_MEM;
        else if (mem_wb_reg_write && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rt))
            forward_b = `FWD_MEM_WB;
        else
            forward_b = `FWD_NONE;
    end

    // ------------------- ID/branch forwarding -----------------
    // Three-way priority: the instruction immediately preceding the
    // branch (still combinational in EX) beats EX/MEM, which beats
    // MEM/WB. Without the EX_ALU tap, a branch back-to-back with the
    // instruction that produces its operand would read a stale
    // register-file value, since that result hasn't reached the
    // EX/MEM latch yet.
    always @(*) begin
        if (id_ex_reg_write && (id_ex_write_reg != 5'd0) && (id_ex_write_reg == if_id_rs))
            forward_branch_a = `FWD_EX_ALU;
        else if (ex_mem_reg_write && (ex_mem_rd != 5'd0) && (ex_mem_rd == if_id_rs))
            forward_branch_a = `FWD_EX_MEM;
        else if (mem_wb_reg_write && (mem_wb_rd != 5'd0) && (mem_wb_rd == if_id_rs))
            forward_branch_a = `FWD_MEM_WB;
        else
            forward_branch_a = `FWD_NONE;

        if (id_ex_reg_write && (id_ex_write_reg != 5'd0) && (id_ex_write_reg == if_id_rt))
            forward_branch_b = `FWD_EX_ALU;
        else if (ex_mem_reg_write && (ex_mem_rd != 5'd0) && (ex_mem_rd == if_id_rt))
            forward_branch_b = `FWD_EX_MEM;
        else if (mem_wb_reg_write && (mem_wb_rd != 5'd0) && (mem_wb_rd == if_id_rt))
            forward_branch_b = `FWD_MEM_WB;
        else
            forward_branch_b = `FWD_NONE;
    end

endmodule
