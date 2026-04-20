`timescale 1ns/1ps

module tb_simple_cpu;
  reg clk;
  reg rst;
  wire halted;
  wire [7:0] dbg_pc;
  wire [15:0] dbg_acc;
  wire [7:0] dbg_ir;

  // Adjust path as needed in your simulator settings.
  // In Vivado xsim, you can add the programs folder to simulation fileset.
  localparam RAM_INIT_FILE = "CPU/programs/sum_1_100.hex";

  SimpleCpuTop #(
    .RAM_INIT_FILE(RAM_INIT_FILE)
  ) dut (
    .clk(clk),
    .rst(rst),
    .halted(halted),
    .dbg_pc(dbg_pc),
    .dbg_acc(dbg_acc),
    .dbg_ir(dbg_ir)
  );

  initial clk = 1'b0;
  always #5 clk = ~clk; // 100MHz

  initial begin
    rst = 1'b1;
    repeat (5) @(posedge clk);
    rst = 1'b0;
  end

  integer cycles;
  initial begin
    cycles = 0;
    // Run until halted or timeout
    wait (rst == 1'b0);
    while (!halted && cycles < 2000) begin
      @(posedge clk);
      cycles = cycles + 1;
    end

    if (halted) begin
      $display("PASS (halted) at cycle %0d, PC=%02h ACC=%04h IR=%02h", cycles, dbg_pc, dbg_acc, dbg_ir);
    end else begin
      $display("TIMEOUT at cycle %0d, PC=%02h ACC=%04h IR=%02h", cycles, dbg_pc, dbg_acc, dbg_ir);
    end
    $finish;
  end
endmodule
