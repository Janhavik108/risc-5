// =============================================================
// data_mem.v - Data Memory (MEM stage)
// Synchronous write, combinational (asynchronous) read so the
// value is available for forwarding/write-back in the same
// pipeline stage transition.
// =============================================================
module data_mem #(
    parameter MEM_WORDS = 256
) (
    input  wire        clk,
    input  wire         mem_read,
    input  wire         mem_write,
    input  wire [31:0]  addr,      // byte address
    input  wire [31:0]  wdata,
    output wire [31:0]  rdata
);

    reg [31:0] mem [0:MEM_WORDS-1];
    integer i;

    initial begin
        for (i = 0; i < MEM_WORDS; i = i + 1)
            mem[i] = 32'd0;
    end

    wire [31:0] word_idx = addr[31:2];

    always @(posedge clk) begin
        if (mem_write && word_idx < MEM_WORDS)
            mem[word_idx] <= wdata;
    end

    assign rdata = (mem_read && word_idx < MEM_WORDS) ? mem[word_idx] : 32'd0;

endmodule
