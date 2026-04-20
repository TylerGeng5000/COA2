`include "defines.vh"

// Microprogrammed Control Unit (skeleton)
// This module drives datapath control signals.
// NOTE: This is a starter scaffold to align interfaces; you will fill micro-sequences.
module ControlUnit(
  input        clk,
  input        rst,       // synchronous reset
  input  [7:0] opcode,
  input        acc_sign,

  output reg   pc_we,
  output reg [1:0] pc_sel,
  output reg   mar_we,
  output reg [1:0] mar_sel,
  output reg   mbr_we,
  output reg   mbr_sel,
  output reg   ir_we,
  output reg   br_we,
  output reg   acc_we,
  output reg [1:0] acc_sel,
  output reg [3:0] alu_op,
  output reg   mr_we,

  output reg   ram_we,
  output reg   halted
);
  // Control address register (micro PC)
  reg [7:0] car_q;
  reg [7:0] car_d;

  // Simple example micro-sequencer:
  // 0: MAR <- PC
  // 1: MBR <- MEM[MAR]   (sync RAM: mem_rdata available now)
  // 2: IR  <- MBR[15:8], PC <- PC+1
  // 3: dispatch by opcode (placeholder)
  always @(*) begin
    // defaults (deassert everything)
    pc_we   = 1'b0;
    pc_sel  = `PC_SEL_PLUS1;
    mar_we  = 1'b0;
    mar_sel = `MAR_SEL_PC;
    mbr_we  = 1'b0;
    mbr_sel = `MBR_SEL_MEM;
    ir_we   = 1'b0;
    br_we   = 1'b0;
    acc_we  = 1'b0;
    acc_sel = `ACC_SEL_ALU;
    alu_op  = `ALU_ADD;
    mr_we   = 1'b0;

    ram_we  = 1'b0;
    halted  = 1'b0;

    car_d = car_q + 8'd1;

    case (car_q)
      8'd0: begin
        // place PC on MAR for instruction fetch
        mar_we  = 1'b1;
        mar_sel = `MAR_SEL_PC;
        car_d   = 8'd1;
      end
      8'd1: begin
        // latch instruction word from RAM into MBR
        mbr_we  = 1'b1;
        mbr_sel = `MBR_SEL_MEM;
        car_d   = 8'd2;
      end
      8'd2: begin
        // decode opcode and increment PC
        ir_we   = 1'b1;
        pc_we   = 1'b1;
        pc_sel  = `PC_SEL_PLUS1;
        car_d   = 8'd3;
      end
      8'd3: begin
        // dispatch placeholder: for now immediately go back to fetch
        // TODO: set car_d to the entry address of each instruction microprogram
        // TODO: implement HALT, LOAD/STORE/ADD/SUB/JMP/JMPGEZ, etc.
        car_d = 8'd0;
      end
      default: begin
        car_d = 8'd0;
      end
    endcase

    // If you later implement HALT, set halted=1 and hold car_d.
    // Example:
    // if (opcode == `OP_HALT) begin halted=1; car_d=car_q; end
  end

  always @(posedge clk) begin
    if (rst) begin
      car_q <= 8'd0;
    end else begin
      car_q <= car_d;
    end
  end
endmodule
