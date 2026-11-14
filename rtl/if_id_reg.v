// =============================================================
// if_id_reg.v - IF/ID pipeline register
// =============================================================
module if_id_reg (
    input  wire        clk,
    input  wire         rst,
    input  wire         stall,   // hold current contents (load-use hazard)
    input  wire         flush,   // clear to NOP (taken branch)
    input  wire [31:0]  pc_in,
    input  wire [31:0]  pc_plus4_in,
    input  wire [31:0]  instr_in,

    output reg  [31:0]  pc_out,
    output reg  [31:0]  pc_plus4_out,
    output reg  [31:0]  instr_out
);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc_out       <= 32'd0;
            pc_plus4_out <= 32'd0;
            instr_out    <= 32'h00000000;
        end else if (flush) begin
            pc_out       <= 32'd0;
            pc_plus4_out <= 32'd0;
            instr_out    <= 32'h00000000; // squashed instruction -> NOP
        end else if (stall) begin
            // hold: do nothing
        end else begin
            pc_out       <= pc_in;
            pc_plus4_out <= pc_plus4_in;
            instr_out    <= instr_in;
        end
    end

endmodule
