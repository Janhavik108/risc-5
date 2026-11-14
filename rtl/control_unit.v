// =============================================================
// control_unit.v - Main Control Unit (ID stage)
// Decodes the opcode field into datapath control signals.
// =============================================================
`include "defines.vh"

module control_unit (
    input  wire [5:0] opcode,

    output reg        reg_dst,     // 1: write reg = rd (R-type), 0: rt (I-type)
    output reg        alu_src,     // 1: ALU B input = sign-ext immediate
    output reg        mem_to_reg,  // 1: write-back data = memory read data
    output reg        reg_write,   // 1: enable register file write
    output reg        mem_read,    // 1: data memory read enable
    output reg        mem_write,   // 1: data memory write enable
    output reg        branch,      // 1: instruction is a branch (BEQ)
    output reg  [1:0] alu_op       // to ALU control
);

    always @(*) begin
        // Defaults (safe values -> behave like a NOP if opcode unrecognized)
        reg_dst    = 1'b0;
        alu_src    = 1'b0;
        mem_to_reg = 1'b0;
        reg_write  = 1'b0;
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        branch     = 1'b0;
        alu_op     = `ALUOP_RTYPE;

        case (opcode)
            `OP_RTYPE: begin
                reg_dst    = 1'b1;
                alu_src    = 1'b0;
                mem_to_reg = 1'b0;
                reg_write  = 1'b1;
                alu_op     = `ALUOP_RTYPE;
            end
            `OP_ADDI: begin
                reg_dst    = 1'b0;
                alu_src    = 1'b1;
                mem_to_reg = 1'b0;
                reg_write  = 1'b1;
                alu_op     = `ALUOP_LOADSTORE; // ADD
            end
            `OP_LW: begin
                reg_dst    = 1'b0;
                alu_src    = 1'b1;
                mem_to_reg = 1'b1;
                reg_write  = 1'b1;
                mem_read   = 1'b1;
                alu_op     = `ALUOP_LOADSTORE; // ADD (address calc)
            end
            `OP_SW: begin
                alu_src    = 1'b1;
                mem_write  = 1'b1;
                alu_op     = `ALUOP_LOADSTORE; // ADD (address calc)
            end
            `OP_BEQ: begin
                alu_src    = 1'b0;
                branch     = 1'b1;
                alu_op     = `ALUOP_BRANCH;    // SUB (compare)
            end
            default: ; // NOP / unrecognized -> all-zero control
        endcase
    end

endmodule
