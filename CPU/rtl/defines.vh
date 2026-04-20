// Common definitions for the simple CPU project (Verilog .vh)
// Keep this file free of SystemVerilog syntax.

`ifndef CPU_DEFINES_VH
`define CPU_DEFINES_VH

// Widths (match course spec)
`define DATA_W 16
`define ADDR_W 8

// Instruction fields
`define OPCODE_MSB 15
`define OPCODE_LSB 8
`define ADDR_MSB   7
`define ADDR_LSB   0

// Opcodes (Table 1 in the course PDF)
`define OP_STORE   8'h01
`define OP_LOAD    8'h02
`define OP_ADD     8'h03
`define OP_SUB     8'h04
`define OP_JMPGEZ  8'h05
`define OP_JMP     8'h06
`define OP_HALT    8'h07
`define OP_MPY     8'h08
`define OP_AND     8'h0A
`define OP_OR      8'h0B
`define OP_NOT     8'h0C
`define OP_SHIFTR  8'h0D
`define OP_SHIFTL  8'h0E

// PC select
`define PC_SEL_PLUS1 2'd0
`define PC_SEL_ADDR  2'd1

// MAR select
`define MAR_SEL_PC    2'd0
`define MAR_SEL_ADDR  2'd1

// MBR select
`define MBR_SEL_MEM 1'b0
`define MBR_SEL_ACC 1'b1

// ACC select
`define ACC_SEL_ALU  2'd0
`define ACC_SEL_ZERO 2'd1
`define ACC_SEL_MBR  2'd2

// ALU ops (internal, do NOT reuse instruction opcode)
`define ALU_ADD       4'd0
`define ALU_SUB       4'd1
`define ALU_AND       4'd2
`define ALU_OR        4'd3
`define ALU_NOT_B     4'd4
`define ALU_SHIFTL_B  4'd5
`define ALU_SHIFTR_B  4'd6

`endif
