// =============================================================
// id_ex_reg.v - ID/EX pipeline register
//
// 'bubble' zeroes every control signal (reg_write, mem_read,
// mem_write, branch) so the latched instruction behaves as a
// NOP -- this is how the load-use stall is turned into a single
// dead cycle in the pipeline without a separate flush datapath.
// =============================================================
module id_ex_reg (
    input  wire        clk,
    input  wire         rst,
    input  wire         bubble,       // force control signals to 0 (NOP)

    // Control signals in
    input  wire         reg_dst_in,
    input  wire         alu_src_in,
    input  wire         mem_to_reg_in,
    input  wire         reg_write_in,
    input  wire         mem_read_in,
    input  wire         mem_write_in,
    input  wire         branch_in,
    input  wire [1:0]   alu_op_in,

    // Data in
    input  wire [31:0]  pc_plus4_in,
    input  wire [31:0]  rdata1_in,
    input  wire [31:0]  rdata2_in,
    input  wire [31:0]  imm32_in,
    input  wire [4:0]   rs_in,
    input  wire [4:0]   rt_in,
    input  wire [4:0]   rd_in,
    input  wire [5:0]   funct_in,

    // Control signals out
    output reg          reg_dst_out,
    output reg          alu_src_out,
    output reg          mem_to_reg_out,
    output reg          reg_write_out,
    output reg          mem_read_out,
    output reg          mem_write_out,
    output reg          branch_out,
    output reg  [1:0]   alu_op_out,

    // Data out
    output reg  [31:0]  pc_plus4_out,
    output reg  [31:0]  rdata1_out,
    output reg  [31:0]  rdata2_out,
    output reg  [31:0]  imm32_out,
    output reg  [4:0]   rs_out,
    output reg  [4:0]   rt_out,
    output reg  [4:0]   rd_out,
    output reg  [5:0]   funct_out
);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            reg_dst_out    <= 1'b0;
            alu_src_out    <= 1'b0;
            mem_to_reg_out <= 1'b0;
            reg_write_out  <= 1'b0;
            mem_read_out   <= 1'b0;
            mem_write_out  <= 1'b0;
            branch_out     <= 1'b0;
            alu_op_out     <= 2'b00;
            pc_plus4_out   <= 32'd0;
            rdata1_out     <= 32'd0;
            rdata2_out     <= 32'd0;
            imm32_out      <= 32'd0;
            rs_out         <= 5'd0;
            rt_out         <= 5'd0;
            rd_out         <= 5'd0;
            funct_out      <= 6'd0;
        end else if (bubble) begin
            // Squash: kill every control signal, keep data don't-cares
            reg_dst_out    <= 1'b0;
            alu_src_out    <= 1'b0;
            mem_to_reg_out <= 1'b0;
            reg_write_out  <= 1'b0;
            mem_read_out   <= 1'b0;
            mem_write_out  <= 1'b0;
            branch_out     <= 1'b0;
            alu_op_out     <= 2'b00;
            pc_plus4_out   <= 32'd0;
            rdata1_out     <= 32'd0;
            rdata2_out     <= 32'd0;
            imm32_out      <= 32'd0;
            rs_out         <= 5'd0;
            rt_out         <= 5'd0;
            rd_out         <= 5'd0;
            funct_out      <= 6'd0;
        end else begin
            reg_dst_out    <= reg_dst_in;
            alu_src_out    <= alu_src_in;
            mem_to_reg_out <= mem_to_reg_in;
            reg_write_out  <= reg_write_in;
            mem_read_out   <= mem_read_in;
            mem_write_out  <= mem_write_in;
            branch_out     <= branch_in;
            alu_op_out     <= alu_op_in;
            pc_plus4_out   <= pc_plus4_in;
            rdata1_out     <= rdata1_in;
            rdata2_out     <= rdata2_in;
            imm32_out      <= imm32_in;
            rs_out         <= rs_in;
            rt_out         <= rt_in;
            rd_out         <= rd_in;
            funct_out      <= funct_in;
        end
    end

endmodule
