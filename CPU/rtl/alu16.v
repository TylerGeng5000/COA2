`include "defines.vh"

// 16-bit ALU (pure combinational)
module Alu16(
  input  [`DATA_W-1:0] a,
  input  [`DATA_W-1:0] b,
  input  [3:0]         op,
  output reg [`DATA_W-1:0] y
);
  always @(*) begin
    case (op)
      `ALU_ADD:      y = a + b;
      `ALU_SUB:      y = a - b;
      `ALU_AND:      y = a & b;
      `ALU_OR:       y = a | b;
      `ALU_NOT_B:    y = ~b;
      `ALU_SHIFTL_B: y = b << 1;
      `ALU_SHIFTR_B: y = b >> 1;
      default:       y = {`DATA_W{1'b0}};
    endcase
  end
endmodule
