`include "defines.vh"

// Datapath: registers + muxing + RAM interface + ALU
module Datapath(
  input                 clk,
  input                 rst,          // synchronous reset

  // RAM interface
  output [`ADDR_W-1:0]  mem_addr,
  output [`DATA_W-1:0]  mem_wdata,
  input  [`DATA_W-1:0]  mem_rdata,

  // Control inputs (from ControlUnit)
  input                 pc_we,
  input  [1:0]          pc_sel,
  input                 mar_we,
  input  [1:0]          mar_sel,
  input                 mbr_we,
  input                 mbr_sel,
  input                 ir_we,
  input                 br_we,
  input                 acc_we,
  input  [1:0]          acc_sel,
  input  [3:0]          alu_op,
  input                 mr_we,

  // Feedback outputs (to ControlUnit / debug)
  output [7:0]          opcode,
  output                acc_sign,
  output [7:0]          dbg_pc,
  output [15:0]         dbg_acc,
  output [7:0]          dbg_ir
);
  // Registers (course spec)
  reg [`ADDR_W-1:0] pc_q;
  reg [`ADDR_W-1:0] mar_q;
  reg [`DATA_W-1:0] mbr_q;
  reg [7:0]         ir_q;
  reg [`DATA_W-1:0] br_q;
  reg [`DATA_W-1:0] acc_q;
  reg [`DATA_W-1:0] mr_q;

  // Derived fields
  wire [7:0] instr_addr = mbr_q[`ADDR_MSB:`ADDR_LSB];

  // ALU
  wire [`DATA_W-1:0] alu_y;
  Alu16 u_alu(
    .a(acc_q),
    .b(br_q),
    .op(alu_op),
    .y(alu_y)
  );

  // RAM ports
  assign mem_addr  = mar_q;
  assign mem_wdata = mbr_q;

  // Feedback/debug
  assign opcode   = ir_q;
  assign acc_sign = acc_q[`DATA_W-1];
  assign dbg_pc   = pc_q;
  assign dbg_acc  = acc_q;
  assign dbg_ir   = ir_q;

  // Next-state wires
  reg [`ADDR_W-1:0] pc_d;
  reg [`ADDR_W-1:0] mar_d;
  reg [`DATA_W-1:0] mbr_d;
  reg [7:0]         ir_d;
  reg [`DATA_W-1:0] br_d;
  reg [`DATA_W-1:0] acc_d;
  reg [`DATA_W-1:0] mr_d;

  always @(*) begin
    // Defaults: hold
    pc_d  = pc_q;
    mar_d = mar_q;
    mbr_d = mbr_q;
    ir_d  = ir_q;
    br_d  = br_q;
    acc_d = acc_q;
    mr_d  = mr_q;

    // PC mux
    if (pc_we) begin
      case (pc_sel)
        `PC_SEL_PLUS1: pc_d = pc_q + 1'b1;
        `PC_SEL_ADDR:  pc_d = instr_addr;
        default:       pc_d = pc_q;
      endcase
    end

    // MAR mux
    if (mar_we) begin
      case (mar_sel)
        `MAR_SEL_PC:   mar_d = pc_q;
        `MAR_SEL_ADDR: mar_d = instr_addr;
        default:       mar_d = mar_q;
      endcase
    end

    // MBR mux
    if (mbr_we) begin
      case (mbr_sel)
        `MBR_SEL_MEM: mbr_d = mem_rdata;
        `MBR_SEL_ACC: mbr_d = acc_q;
        default:      mbr_d = mbr_q;
      endcase
    end

    // IR
    if (ir_we) begin
      ir_d = mbr_q[`OPCODE_MSB:`OPCODE_LSB];
    end

    // BR
    if (br_we) begin
      br_d = mbr_q;
    end

    // ACC
    if (acc_we) begin
      case (acc_sel)
        `ACC_SEL_ALU:  acc_d = alu_y;
        `ACC_SEL_ZERO: acc_d = {`DATA_W{1'b0}};
        `ACC_SEL_MBR:  acc_d = mbr_q;
        default:       acc_d = acc_q;
      endcase
    end

    // MR (placeholder; MPY micro-ops to define later)
    if (mr_we) begin
      mr_d = mr_q; // TODO: define MR writeback policy for MPY
    end
  end

  always @(posedge clk) begin
    if (rst) begin
      pc_q  <= {`ADDR_W{1'b0}};
      mar_q <= {`ADDR_W{1'b0}};
      mbr_q <= {`DATA_W{1'b0}};
      ir_q  <= 8'h00;
      br_q  <= {`DATA_W{1'b0}};
      acc_q <= {`DATA_W{1'b0}};
      mr_q  <= {`DATA_W{1'b0}};
    end else begin
      pc_q  <= pc_d;
      mar_q <= mar_d;
      mbr_q <= mbr_d;
      ir_q  <= ir_d;
      br_q  <= br_d;
      acc_q <= acc_d;
      mr_q  <= mr_d;
    end
  end
endmodule
