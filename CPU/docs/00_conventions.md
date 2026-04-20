# 代码编写规范（小组统一版）

本规范用于三人并行开发同一个 CPU 工程时，减少接口不一致与时序/位宽类 bug。

## 0. 总原则

- **先冻结接口，再写实现**：模块端口、位宽、时序约定先定下来，任何改动必须同步更新接口文档。
- **组合逻辑无锁存**：所有 `always @(*)` 必须给默认赋值；`case` 建议写 `default`。
- **时序逻辑统一写法**：寄存器只在 `always @(posedge clk)` 更新；复位按课设要求采用**同步复位**（课设PDF：reset signals synchronized to clock）。

## 1. 命名与风格

### 1.1 文件/模块

- 一个文件一个核心模块（允许附带局部 helper module）。
- 模块名：`CamelCase`，例如 `SimpleCpuTop`、`ControlUnit`、`RegFile`。

### 1.2 信号

- 统一信号命名：小写下划线，例如 `pc_next`、`mem_rdata`。
- 时钟/复位：`clk`、`rst`（同步复位，建议高有效）。
- 有效信号：后缀 `_v`（valid）、`_we`（write enable）、`_re`（read enable）。
- 宽度：在声明处写清楚，例如 `logic [15:0] acc_q;`。

### 1.3 常量/参数

- 参数全大写：`DATA_W`、`ADDR_W`、`MEM_DEPTH`。
- opcode 常量：`localparam logic [7:0] OP_LOAD = 8'h02;`。

## 2. 时序/组合编码规范（SystemVerilog 优先）

- 时序：
  - 只用非阻塞赋值 `<=`。
  - 同步复位模板：

```systemverilog
always_ff @(posedge clk) begin
  if (rst) begin
    // reset
  end else begin
    // normal
  end
end
```

- 组合：
  - 只用阻塞赋值 `=`。
  - 必须先给默认值，再覆盖。

```systemverilog
always_comb begin
  y = '0;
  unique case (sel)
    2'd0: y = a;
    2'd1: y = b;
    default: y = '0;
  endcase
end
```

## 3. 接口/位宽/端口约定

- 指令字：16-bit，`instr[15:8]`=opcode，`instr[7:0]`=addr/imm。
- 内部寄存器位宽（按课设）：
  - `PC`/`MAR`：8-bit
  - `IR`：8-bit
  - `ACC`/`BR`/`MBR`：16-bit
  - `MR`：16-bit（乘法结果的一部分；具体高/低字由小组统一定义）
- RAM：256×16，建议对外提供同步读接口（方便 FPGA BRAM 综合）。

## 4. 目录与分层（推荐）

- `CPU/rtl/`：可综合 RTL
- `CPU/sim/`：testbench、仿真脚本
- `CPU/programs/`：内存初始化文件（HEX/MEM）
- `CPU/constraints/`：板级约束（XDC）
- `CPU/docs/`：规格、接口、分工、测试说明

## 5. 协作与提交流程

- 分支命名：`feat/<topic>`、`fix/<topic>`、`doc/<topic>`。
- PR 必须包含：
  - 变更点摘要（1-3 行）
  - 本次通过的仿真用例列表
  - 如改动接口，必须同步更新 `CPU/docs/02_interfaces.md`
- 提交信息格式：`type: scope - summary`
  - `feat: datapath - add ACC/BR/ALU`
  - `fix: control - correct JMPGEZ condition`

## 6. 最小“质量闸门”

每次合并到 `main` 前必须满足：

- 核心 testbench 回归通过（至少覆盖：LOAD/STORE/ADD/SUB/JMPGEZ/JMP/HALT）
- 无明显位宽告警/未连接端口
- `halt` 行为可复现（停机后 PC/寄存器不再变化）
