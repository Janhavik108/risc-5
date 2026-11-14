// =============================================================
// instr_mem.v - Instruction Memory (IF stage)
// Combinational read, byte-addressed PC, word-aligned access.
// =============================================================
module instr_mem #(
    parameter MEM_WORDS = 256,
    parameter INIT_FILE = "program.hex"
) (
    input  wire [31:0] addr,     // byte address (from PC)
    output wire [31:0] instr
);

    reg [31:0] mem [0:MEM_WORDS-1];

    initial begin
        if (INIT_FILE != "")
            $readmemh(INIT_FILE, mem);
    end

    // word-aligned combinational read; out-of-range -> NOP
    assign instr = (addr[31:2] < MEM_WORDS) ? mem[addr[31:2]] : 32'h00000000;

endmodule
