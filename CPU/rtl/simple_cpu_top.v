`include "defines.vh"

module SimpleCpuTop #(
  parameter RAM_INIT_FILE = ""  // optional: preload program/data (hex)
)(
  input        clk,
  input        rst,      // synchronous reset
  output       halted,
  output [7:0] dbg_pc,
  output [15:0] dbg_acc,
  output [7:0] dbg_ir
);
  // Interconnect
  wire [`ADDR_W-1:0] mem_addr;
  wire [`DATA_W-1:0] mem_wdata;
  wire [`DATA_W-1:0] mem_rdata;

  wire [7:0] opcode;
  wire       acc_sign;

  // Control signals
  wire       pc_we;
  wire [1:0] pc_sel;
  wire       mar_we;
  wire [1:0] mar_sel;
  wire       mbr_we;
  wire       mbr_sel;
  wire       ir_we;
  wire       br_we;
  wire       acc_we;
  wire [1:0] acc_sel;
  wire [3:0] alu_op;
  wire       mr_we;

  wire       ram_we;

  Datapath u_dp(
    .clk(clk),
    .rst(rst),
    .mem_addr(mem_addr),
    .mem_wdata(mem_wdata),
    .mem_rdata(mem_rdata),
    .pc_we(pc_we),
    .pc_sel(pc_sel),
    .mar_we(mar_we),
    .mar_sel(mar_sel),
    .mbr_we(mbr_we),
    .mbr_sel(mbr_sel),
    .ir_we(ir_we),
    .br_we(br_we),
    .acc_we(acc_we),
    .acc_sel(acc_sel),
    .alu_op(alu_op),
    .mr_we(mr_we),
    .opcode(opcode),
    .acc_sign(acc_sign),
    .dbg_pc(dbg_pc),
    .dbg_acc(dbg_acc),
    .dbg_ir(dbg_ir)
  );

  ControlUnit u_cu(
    .clk(clk),
    .rst(rst),
    .opcode(opcode),
    .acc_sign(acc_sign),
    .pc_we(pc_we),
    .pc_sel(pc_sel),
    .mar_we(mar_we),
    .mar_sel(mar_sel),
    .mbr_we(mbr_we),
    .mbr_sel(mbr_sel),
    .ir_we(ir_we),
    .br_we(br_we),
    .acc_we(acc_we),
    .acc_sel(acc_sel),
    .alu_op(alu_op),
    .mr_we(mr_we),
    .ram_we(ram_we),
    .halted(halted)
  );

  Ram256x16 #(
    .INIT_FILE(RAM_INIT_FILE)
  ) u_ram(
    .clk(clk),
    .addr(mem_addr),
    .we(ram_we),
    .wdata(mem_wdata),
    .rdata(mem_rdata)
  );
endmodule
