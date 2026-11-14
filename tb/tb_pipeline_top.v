// =============================================================
// tb_pipeline_top.v - Self-checking testbench
//
// Runs program.hex to completion, then checks:
//   1. Final architectural register values (functional correctness
//      across single-instruction, back-to-back hazard, and branch
//      corner cases)
//   2. Data memory content written by SW (load/store correctness)
//   3. That the load-use hazard produced exactly one stall cycle,
//      and that ALU-ALU RAW hazards produced zero stall cycles
//      (hazard unit / forwarding unit are doing their job)
//   4. That the two squashed post-branch instructions never
//      committed a register write (write-back integrity / flush
//      correctness)
// =============================================================
`timescale 1ns/1ps

module tb_pipeline_top;

    reg clk = 0;
    reg rst = 1;

    integer errors = 0;
    integer checks = 0;
    integer stall_cycles = 0;
    integer flush_cycles = 0;
    integer cycle_count = 0;

    pipeline_top #(
        .IMEM_WORDS(256), .DMEM_WORDS(256), .IMEM_FILE("program.hex")
    ) u_dut (
        .clk(clk), .rst(rst)
    );

    // 100 MHz-equivalent test clock
    always #5 clk = ~clk;

    // -------- bookkeeping: count stall / flush cycles ----------
    always @(posedge clk) begin
        if (!rst) begin
            cycle_count = cycle_count + 1;
            if (u_dut.stall_pc)              stall_cycles = stall_cycles + 1;
            if (u_dut.branch_flush_if_id)    flush_cycles = flush_cycles + 1;
        end
    end

    // -------- guard against a squashed instruction sneaking a
    //          write into the register file (write-back integrity) --
    reg saw_bad_write;
    initial saw_bad_write = 1'b0;
    always @(posedge clk) begin
        if (!rst && u_dut.wb_reg_write && u_dut.wb_write_data == 32'd999) begin
            saw_bad_write = 1'b1;
        end
    end

    task check_reg(input [4:0] idx, input [31:0] expected, input [319:0] name);
        begin
            checks = checks + 1;
            if (u_dut.u_regfile.regs[idx] !== expected) begin
                errors = errors + 1;
                $display("  [FAIL] %0s (r%0d): expected=%0d actual=%0d",
                          name, idx, expected, u_dut.u_regfile.regs[idx]);
            end else begin
                $display("  [PASS] %0s (r%0d) = %0d", name, idx, u_dut.u_regfile.regs[idx]);
            end
        end
    endtask

    task check_mem(input [31:0] word_idx, input [31:0] expected, input [319:0] name);
        begin
            checks = checks + 1;
            if (u_dut.u_dmem.mem[word_idx] !== expected) begin
                errors = errors + 1;
                $display("  [FAIL] %0s (mem[%0d]): expected=%0d actual=%0d",
                          name, word_idx, expected, u_dut.u_dmem.mem[word_idx]);
            end else begin
                $display("  [PASS] %0s (mem[%0d]) = %0d", name, word_idx, u_dut.u_dmem.mem[word_idx]);
            end
        end
    endtask

    task check_cond(input cond, input [319:0] name);
        begin
            checks = checks + 1;
            if (!cond) begin
                errors = errors + 1;
                $display("  [FAIL] %0s", name);
            end else begin
                $display("  [PASS] %0s", name);
            end
        end
    endtask

    initial begin
        $dumpfile("pipeline_wave.vcd");
        $dumpvars(0, tb_pipeline_top);

        $display("=====================================================");
        $display(" 5-Stage Pipelined RISC Processor - Self-Checking TB");
        $display("=====================================================");

        rst = 1;
        repeat (3) @(posedge clk);
        rst = 0;

        // 32 instructions + enough drain cycles for the deepest
        // in-flight instruction to reach WB
        repeat (60) @(posedge clk);

        $display("\n--- Section 1/2: baseline + back-to-back ALU hazards ---");
        check_reg(1,  32'd5,   "r1 = addi 5");
        check_reg(2,  32'd10,  "r2 = addi 10");
        check_reg(3,  32'd15,  "r3 = add r1+r2 (EX/MEM fwd)");
        check_reg(4,  32'd10,  "r4 = sub r3-r1 (back-to-back EX/MEM fwd)");
        check_reg(5,  32'd10,  "r5 = and r3&r2 (MEM/WB fwd)");
        check_reg(6,  32'd15,  "r6 = or r1|r2");
        check_reg(7,  32'd1,   "r7 = slt r1<r2");

        $display("\n--- Section 3: load-use hazard ---");
        check_reg(8,  32'd100, "r8 = addi 100 (base addr)");
        check_mem(25, 32'd10,  "mem[100] = sw r2");
        check_reg(9,  32'd10,  "r9 = lw mem[100]");
        check_reg(10, 32'd15,  "r10 = add r9+r1 (post load-use stall)");

        $display("\n--- Section 4: branch corner cases ---");
        check_reg(15, 32'd1,   "r15 = addi 1");
        check_reg(16, 32'd2,   "r16 = addi 2");
        check_reg(17, 32'd222, "r17 = addi 222 (branch NOT taken -> executes)");
        check_reg(18, 32'd333, "r18 = addi 333 (fallthrough label)");

        check_reg(20, 32'd7,   "r20 = addi 7");
        check_reg(21, 32'd7,   "r21 = addi 7");
        check_reg(22, 32'd0,   "r22 untouched (both post-branch instrs squashed)");
        check_reg(23, 32'd111, "r23 = addi 111 (after taken branch)");

        check_reg(24, 32'd50,  "r24 = addi 50");
        check_reg(25, 32'd50,  "r25 = add r24+r0 (feeds branch next cycle)");
        check_reg(26, 32'd0,   "r26 untouched (squashed by ID-stage-forwarded branch)");
        check_reg(27, 32'd77,  "r27 = addi 77 (after forwarded-operand branch taken)");

        $display("\n--- Hazard/flush timing & write-back integrity ---");
        $display("  stall_pc asserted for %0d cycle(s) (expect exactly 1: the load-use hazard)", stall_cycles);
        $display("  branch_flush_if_id asserted for %0d cycle(s) (expect exactly 2: two taken branches)", flush_cycles);
        check_cond(stall_cycles == 1, "exactly one stall cycle (zero-stall ALU forwarding confirmed)");
        check_cond(flush_cycles == 2, "exactly two flush cycles (one per taken branch)");
        check_cond(saw_bad_write == 1'b0, "no squashed instruction ever committed a register write");

        $display("\n=====================================================");
        if (errors == 0)
            $display(" RESULT: ALL %0d CHECKS PASSED", checks);
        else
            $display(" RESULT: %0d / %0d CHECKS FAILED", errors, checks);
        $display("=====================================================");

        $finish;
    end

    // Safety timeout
    initial begin
        #2000;
        $display("TIMEOUT - simulation did not finish in time");
        $finish;
    end

endmodule
