// =============================================================
// pipeline_top.v - Top-level 5-stage pipelined RISC datapath
//
//   IF  ->  ID  ->  EX  ->  MEM  ->  WB
//
// Features:
//   - R-type ALU ops (ADD/SUB/AND/OR/SLT), ADDI, LW, SW, BEQ
//   - EX-to-EX and MEM-to-EX forwarding -> zero-stall ALU RAW hazards
//   - Load-use hazard -> single-cycle stall (bubble in ID/EX)
//   - BEQ resolved in ID stage (with its own forwarding paths)
//     -> only a single wrong-path instruction is ever fetched,
//        squashed by flushing IF/ID
// =============================================================
`include "defines.vh"

module pipeline_top #(
    parameter IMEM_WORDS = 256,
    parameter DMEM_WORDS = 256,
    parameter IMEM_FILE  = "program.hex"
) (
    input  wire clk,
    input  wire rst
);

    // =========================================================
    // IF STAGE
    // =========================================================
    wire [31:0] pc_current;
    wire [31:0] pc_plus4_if = pc_current + 32'd4;
    wire [31:0] instr_if;

    wire        stall_pc, stall_if_id, bubble_id_ex, branch_flush_if_id, pc_src;
    wire [31:0] branch_target;

    pc_reg u_pc (
        .clk(clk), .rst(rst),
        .stall(stall_pc),
        .pc_src(pc_src),
        .branch_target(branch_target),
        .pc(pc_current)
    );

    instr_mem #(.MEM_WORDS(IMEM_WORDS), .INIT_FILE(IMEM_FILE)) u_imem (
        .addr(pc_current),
        .instr(instr_if)
    );

    // =========================================================
    // IF/ID REGISTER
    // =========================================================
    wire [31:0] if_id_pc, if_id_pc_plus4, if_id_instr;

    if_id_reg u_if_id (
        .clk(clk), .rst(rst),
        .stall(stall_if_id),
        .flush(branch_flush_if_id),
        .pc_in(pc_current), .pc_plus4_in(pc_plus4_if), .instr_in(instr_if),
        .pc_out(if_id_pc), .pc_plus4_out(if_id_pc_plus4), .instr_out(if_id_instr)
    );

    // =========================================================
    // ID STAGE
    // =========================================================
    wire [5:0] opcode   = if_id_instr[31:26];
    wire [4:0] id_rs     = if_id_instr[25:21];
    wire [4:0] id_rt     = if_id_instr[20:16];
    wire [4:0] id_rd     = if_id_instr[15:11];
    wire [15:0] id_imm16 = if_id_instr[15:0];
    wire [5:0] id_funct  = if_id_instr[5:0];

    wire        reg_dst, alu_src, mem_to_reg, reg_write, mem_read, mem_write, branch_ctrl;
    wire [1:0]  alu_op;

    control_unit u_ctrl (
        .opcode(opcode),
        .reg_dst(reg_dst), .alu_src(alu_src), .mem_to_reg(mem_to_reg),
        .reg_write(reg_write), .mem_read(mem_read), .mem_write(mem_write),
        .branch(branch_ctrl), .alu_op(alu_op)
    );

    wire [31:0] id_rdata1, id_rdata2;

    // Register-file write port driven by WB stage (declared later)
    wire        wb_reg_write;
    wire [4:0]  wb_write_reg;
    wire [31:0] wb_write_data;

    reg_file u_regfile (
        .clk(clk), .rst(rst),
        .we(wb_reg_write), .waddr(wb_write_reg), .wdata(wb_write_data),
        .raddr1(id_rs), .raddr2(id_rt),
        .rdata1(id_rdata1), .rdata2(id_rdata2)
    );

    wire [31:0] id_imm32;
    sign_extend u_sext (.imm16(id_imm16), .imm32(id_imm32));

    assign branch_target = if_id_pc_plus4 + (id_imm32 << 2);

    // ---- Hazard detection (load-use) ----
    wire        idex_mem_read;   // forward-declared from ID/EX reg below
    wire [4:0]  idex_rt;

    hazard_unit u_hazard (
        .id_ex_mem_read(idex_mem_read),
        .id_ex_rt(idex_rt),
        .if_id_rs(id_rs),
        .if_id_rt(id_rt),
        .stall_pc(stall_pc),
        .stall_if_id(stall_if_id),
        .bubble_id_ex(bubble_id_ex)
    );

    // ---- ID-stage branch forwarding & resolution ----
    wire [1:0] fwd_branch_a, fwd_branch_b;
    wire [31:0] exmem_alu_result_w; // forward-declared from EX/MEM reg below
    wire        exmem_reg_write_w;
    wire [4:0]  exmem_write_reg_w;
    wire        memwb_reg_write_w;  // == wb_reg_write
    wire [4:0]  memwb_write_reg_w;  // == wb_write_reg
    wire [31:0] memwb_write_data_w; // == wb_write_data

    reg [31:0] branch_op_a, branch_op_b;
    always @(*) begin
        case (fwd_branch_a)
            `FWD_EX_ALU: branch_op_a = alu_result;         // immediately preceding instr
            `FWD_EX_MEM: branch_op_a = exmem_alu_result_w;
            `FWD_MEM_WB: branch_op_a = memwb_write_data_w;
            default:     branch_op_a = id_rdata1;
        endcase
        case (fwd_branch_b)
            `FWD_EX_ALU: branch_op_b = alu_result;         // immediately preceding instr
            `FWD_EX_MEM: branch_op_b = exmem_alu_result_w;
            `FWD_MEM_WB: branch_op_b = memwb_write_data_w;
            default:     branch_op_b = id_rdata2;
        endcase
    end

    wire branch_taken = branch_ctrl && (branch_op_a == branch_op_b);
    assign pc_src = branch_taken;
    assign branch_flush_if_id = branch_taken;

    // =========================================================
    // ID/EX REGISTER
    // =========================================================
    wire        idex_reg_dst, idex_alu_src, idex_mem_to_reg, idex_reg_write, idex_mem_write, idex_branch;
    wire [1:0]  idex_alu_op;
    wire [31:0] idex_pc_plus4, idex_rdata1, idex_rdata2, idex_imm32;
    wire [4:0]  idex_rs, idex_rd;
    wire [5:0]  idex_funct;

    id_ex_reg u_id_ex (
        .clk(clk), .rst(rst),
        .bubble(bubble_id_ex),
        .reg_dst_in(reg_dst), .alu_src_in(alu_src), .mem_to_reg_in(mem_to_reg),
        .reg_write_in(reg_write), .mem_read_in(mem_read), .mem_write_in(mem_write),
        .branch_in(branch_ctrl), .alu_op_in(alu_op),
        .pc_plus4_in(if_id_pc_plus4), .rdata1_in(id_rdata1), .rdata2_in(id_rdata2),
        .imm32_in(id_imm32), .rs_in(id_rs), .rt_in(id_rt), .rd_in(id_rd), .funct_in(id_funct),

        .reg_dst_out(idex_reg_dst), .alu_src_out(idex_alu_src), .mem_to_reg_out(idex_mem_to_reg),
        .reg_write_out(idex_reg_write), .mem_read_out(idex_mem_read), .mem_write_out(idex_mem_write),
        .branch_out(idex_branch), .alu_op_out(idex_alu_op),
        .pc_plus4_out(idex_pc_plus4), .rdata1_out(idex_rdata1), .rdata2_out(idex_rdata2),
        .imm32_out(idex_imm32), .rs_out(idex_rs), .rt_out(idex_rt), .rd_out(idex_rd), .funct_out(idex_funct)
    );

    // =========================================================
    // EX STAGE
    // =========================================================
    wire [2:0] alu_ctrl;
    alu_control u_alu_ctrl (.alu_op(idex_alu_op), .funct(idex_funct), .alu_ctrl(alu_ctrl));

    wire [1:0] fwd_a, fwd_b;
    forward_unit u_fwd (
        .id_ex_rs(idex_rs), .id_ex_rt(idex_rt),
        .ex_mem_reg_write(exmem_reg_write_w), .ex_mem_rd(exmem_write_reg_w),
        .mem_wb_reg_write(memwb_reg_write_w), .mem_wb_rd(memwb_write_reg_w),
        .forward_a(fwd_a), .forward_b(fwd_b),
        .if_id_rs(id_rs), .if_id_rt(id_rt),
        .id_ex_reg_write(idex_reg_write), .id_ex_write_reg(ex_write_reg),
        .forward_branch_a(fwd_branch_a), .forward_branch_b(fwd_branch_b)
    );

    reg [31:0] alu_in_a, fwd_b_value;
    always @(*) begin
        case (fwd_a)
            `FWD_EX_MEM: alu_in_a = exmem_alu_result_w;
            `FWD_MEM_WB: alu_in_a = memwb_write_data_w;
            default:     alu_in_a = idex_rdata1;
        endcase
        case (fwd_b)
            `FWD_EX_MEM: fwd_b_value = exmem_alu_result_w;
            `FWD_MEM_WB: fwd_b_value = memwb_write_data_w;
            default:     fwd_b_value = idex_rdata2;
        endcase
    end

    wire [31:0] alu_in_b = idex_alu_src ? idex_imm32 : fwd_b_value;

    wire [31:0] alu_result;
    wire        alu_zero;
    alu u_alu (.a(alu_in_a), .b(alu_in_b), .alu_ctrl(alu_ctrl), .result(alu_result), .zero(alu_zero));

    wire [4:0] ex_write_reg = idex_reg_dst ? idex_rd : idex_rt;

    // =========================================================
    // EX/MEM REGISTER
    // =========================================================
    wire        exmem_mem_to_reg, exmem_mem_read;
    wire [31:0] exmem_write_data;

    ex_mem_reg u_ex_mem (
        .clk(clk), .rst(rst),
        .mem_to_reg_in(idex_mem_to_reg), .reg_write_in(idex_reg_write),
        .mem_read_in(idex_mem_read), .mem_write_in(idex_mem_write),
        .alu_result_in(alu_result), .write_data_in(fwd_b_value), .write_reg_in(ex_write_reg),

        .mem_to_reg_out(exmem_mem_to_reg), .reg_write_out(exmem_reg_write_w),
        .mem_read_out(exmem_mem_read), .mem_write_out(exmem_mem_write_w_int),
        .alu_result_out(exmem_alu_result_w), .write_data_out(exmem_write_data),
        .write_reg_out(exmem_write_reg_w)
    );
    wire exmem_mem_write_w_int;

    // =========================================================
    // MEM STAGE
    // =========================================================
    wire [31:0] mem_rdata;
    data_mem #(.MEM_WORDS(DMEM_WORDS)) u_dmem (
        .clk(clk),
        .mem_read(exmem_mem_read), .mem_write(exmem_mem_write_w_int),
        .addr(exmem_alu_result_w), .wdata(exmem_write_data),
        .rdata(mem_rdata)
    );

    // =========================================================
    // MEM/WB REGISTER
    // =========================================================
    mem_wb_reg u_mem_wb (
        .clk(clk), .rst(rst),
        .mem_to_reg_in(exmem_mem_to_reg), .reg_write_in(exmem_reg_write_w),
        .mem_rdata_in(mem_rdata), .alu_result_in(exmem_alu_result_w), .write_reg_in(exmem_write_reg_w),

        .mem_to_reg_out(memwb_mem_to_reg_w), .reg_write_out(memwb_reg_write_w),
        .mem_rdata_out(memwb_mem_rdata_w), .alu_result_out(memwb_alu_result_w),
        .write_reg_out(memwb_write_reg_w)
    );
    wire memwb_mem_to_reg_w;
    wire [31:0] memwb_mem_rdata_w, memwb_alu_result_w;

    // =========================================================
    // WB STAGE
    // =========================================================
    assign memwb_write_data_w = memwb_mem_to_reg_w ? memwb_mem_rdata_w : memwb_alu_result_w;
    assign wb_reg_write  = memwb_reg_write_w;
    assign wb_write_reg  = memwb_write_reg_w;
    assign wb_write_data = memwb_write_data_w;

endmodule
