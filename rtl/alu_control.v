// =============================================================
// alu_control.v - Generates the exact ALU opcode (EX stage)
// =============================================================
`include "defines.vh"

module alu_control (
    input  wire [1:0] alu_op,
    input  wire [5:0] funct,
    output reg  [2:0] alu_ctrl
);
    always @(*) begin
        case (alu_op)
            `ALUOP_LOADSTORE: alu_ctrl = `ALU_ADD;   // lw/sw/addi
            `ALUOP_BRANCH:    alu_ctrl = `ALU_SUB;   // beq
            `ALUOP_RTYPE: begin
                case (funct)
                    `FUNCT_ADD: alu_ctrl = `ALU_ADD;
                    `FUNCT_SUB: alu_ctrl = `ALU_SUB;
                    `FUNCT_AND: alu_ctrl = `ALU_AND;
                    `FUNCT_OR:  alu_ctrl = `ALU_OR;
                    `FUNCT_SLT: alu_ctrl = `ALU_SLT;
                    default:    alu_ctrl = `ALU_ADD;
                endcase
            end
            default: alu_ctrl = `ALU_ADD;
        endcase
    end
endmodule
