// =============================================================
// pc_reg.v - Program Counter register (IF stage)
// Freezes on load-use stall, loaded with branch target on
// a taken branch (resolved in ID), otherwise increments by 4.
// =============================================================
module pc_reg (
    input  wire        clk,
    input  wire         rst,
    input  wire         stall,       // freeze PC (load-use hazard)
    input  wire         pc_src,      // 1 = take branch target
    input  wire [31:0]  branch_target,
    output reg  [31:0]  pc
);

    wire [31:0] pc_plus4 = pc + 32'd4;
    wire [31:0] pc_next  = pc_src ? branch_target : pc_plus4;

    always @(posedge clk or posedge rst) begin
        if (rst)
            pc <= 32'd0;
        else if (stall)
            pc <= pc;              // hold current PC during a stall
        else
            pc <= pc_next;
    end

endmodule
