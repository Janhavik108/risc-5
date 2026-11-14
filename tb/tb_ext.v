`timescale 1ns/1ps
module tb_ext; reg clk=0,rst=1; integer errors=0, stalls=0, flushes=0;
 pipeline_top u(.clk(clk),.rst(rst)); always #5 clk=~clk;
 always @(posedge clk) if(!rst) begin if(u.stall_pc) stalls=stalls+1; if(u.branch_flush_if_id) flushes=flushes+1; end
 task chk(input [4:0] r, input [31:0] e, input [255:0] n); begin
  if(u.u_regfile.regs[r]!==e) begin errors=errors+1; $display("FAIL %0s r%0d exp=%0d got=%0d",n,r,e,u.u_regfile.regs[r]); end end endtask
 initial begin repeat(3)@(negedge clk); rst=0; repeat(90)@(posedge clk);
  chk(12,2,"T-A double-hazard priority"); chk(13,0,"T-B r0 guard EX/MEM fwd");
  chk(14,11,"T-C lw;addi same reg (bubble)"); chk(20,15,"T-D lw result on rt of consumer");
  chk(21,0,"T-E lw r0;use r0"); chk(23,9,"T-F WB/ID same-cycle write-through");
  chk(24,32'hFFFFFFFF,"T-G sign-extend"); chk(25,1,"T-G signed slt");
  if(u.u_dmem.mem[26]!==77) begin errors=errors+1; $display("FAIL T-I store-data fwd mem[26]=%0d",u.u_dmem.mem[26]); end
  chk(3,0,"T-J lw->beq taken"); chk(5,55,"T-J target"); chk(6,100,"T-K lw value");
  chk(7,0,"T-K stall+flush collision"); chk(9,66,"T-K target");
  $display("stalls=%0d flushes=%0d errors=%0d", stalls, flushes, errors); $finish; end endmodule
