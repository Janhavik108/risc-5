// =============================================================
// ex_mem_reg.v - EX/MEM pipeline register
// =============================================================
module ex_mem_reg (
    input  wire        clk,
    input  wire         rst,

    input  wire         mem_to_reg_in,
    input  wire         reg_write_in,
    input  wire         mem_read_in,
    input  wire         mem_write_in,

    input  wire [31:0]  alu_result_in,
    input  wire [31:0]  write_data_in,   // store data (rt value, possibly forwarded)
    input  wire [4:0]   write_reg_in,    // destination register

    output reg          mem_to_reg_out,
    output reg          reg_write_out,
    output reg          mem_read_out,
    output reg          mem_write_out,

    output reg  [31:0]  alu_result_out,
    output reg  [31:0]  write_data_out,
    output reg  [4:0]   write_reg_out
);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mem_to_reg_out <= 1'b0;
            reg_write_out  <= 1'b0;
            mem_read_out   <= 1'b0;
            mem_write_out  <= 1'b0;
            alu_result_out <= 32'd0;
            write_data_out <= 32'd0;
            write_reg_out  <= 5'd0;
        end else begin
            mem_to_reg_out <= mem_to_reg_in;
            reg_write_out  <= reg_write_in;
            mem_read_out   <= mem_read_in;
            mem_write_out  <= mem_write_in;
            alu_result_out <= alu_result_in;
            write_data_out <= write_data_in;
            write_reg_out  <= write_reg_in;
        end
    end

endmodule
