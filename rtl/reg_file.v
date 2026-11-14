// =============================================================
// reg_file.v - 32 x 32-bit Register File (ID stage read, WB stage write)
// - Register 0 is hardwired to zero.
// - Write happens on the falling... no: write on posedge clk in WB,
//   read is combinational and internally forwards a same-cycle
//   write so that WB and ID can safely occur in the same cycle
//   for back-to-back dependent instructions (register write-back
//   integrity check used by the testbench).
// =============================================================
module reg_file (
    input  wire        clk,
    input  wire         rst,
    input  wire         we,          // write enable (from WB stage)
    input  wire [4:0]   waddr,
    input  wire [31:0]  wdata,
    input  wire [4:0]   raddr1,
    input  wire [4:0]   raddr2,
    output wire [31:0]  rdata1,
    output wire [31:0]  rdata2
);

    reg [31:0] regs [0:31];
    integer i;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1)
                regs[i] <= 32'd0;
        end else if (we && waddr != 5'd0) begin
            regs[waddr] <= wdata;
        end
    end

    // Combinational read with same-cycle write-through (avoids a
    // 1-cycle stale read when WB and ID target the same register
    // in the same clock edge).
    assign rdata1 = (raddr1 == 5'd0) ? 32'd0 :
                     (we && waddr == raddr1 && waddr != 5'd0) ? wdata : regs[raddr1];

    assign rdata2 = (raddr2 == 5'd0) ? 32'd0 :
                     (we && waddr == raddr2 && waddr != 5'd0) ? wdata : regs[raddr2];

endmodule
