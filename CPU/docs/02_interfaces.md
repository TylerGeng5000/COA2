# 模块接口草案（可直接作为实现基线）

本草案以课设给出的寄存器集合与“微程序控制单元 + 数据通路”架构为核心，目标是让三人并行开发时接口不打架。

## 0. 全局参数

- `DATA_W = 16`
- `ADDR_W = 8`
- `MEM_DEPTH = 256`

## 1. 顶层 `SimpleCpuTop`

职责：把 `ControlUnit`、`Datapath`、`Ram256x16` 连接起来；对外提供最少可演示信号。

建议端口：

- 输入：`clk`, `rst`
- 输出：`halted`（停机指示）
- 可选调试输出：`dbg_pc[7:0]`, `dbg_acc[15:0]`, `dbg_ir[7:0]`

> 上板演示如果需要接 LED/数码管，再在顶层做映射，内部模块不直接依赖板卡 IO。

### 1.1 顶层最小连线（示意）

顶层只做“连线”和“导出 debug”，建议连线关系固定如下（便于三人并行不打架）：

- `Datapath` 负责输出：`mem_addr`、`mem_wdata`、`opcode`、`acc_sign`、`dbg_*`
- `ControlUnit` 负责输出：各类寄存器写使能/选择信号、`alu_op`、以及 `ram_we`
- `Ram256x16` 负责：`rdata`（同步读，延迟 1 拍）

信号流：

- `ram.addr  <- dp.mem_addr`
- `ram.we    <- cu.ram_we`
- `ram.wdata <- dp.mem_wdata`
- `dp.mem_rdata <- ram.rdata`
- `cu.opcode <- dp.opcode`
- `cu.acc_sign <- dp.acc_sign`

这样分工后：A 写 `Datapath`、B 写 `ControlUnit`、C 写 `Ram256x16 + SimpleCpuTop + testbench`，接口天然对齐。

## 2. 存储器 `Ram256x16`

课设描述 RAM 为 256×16 且“独立输入/输出端口”。为了综合到 FPGA BRAM，建议使用**同步读**。

### 2.1 建议端口

- 输入：
  - `clk`
  - `addr[7:0]`
  - `we`（写使能）
  - `wdata[15:0]`
- 输出：
  - `rdata[15:0]`（同步读：在时钟沿更新）

### 2.2 读写时序约定

- 读：`addr` 在周期 N 给出，`rdata` 在周期 N+1 有效。
- 写：周期 N 上升沿，若 `we=1`，执行 `MEM[addr] <- wdata`。

> 若你们决定做“组合读”，也可以，但必须统一并更新控制时序（微程序步骤会不同）。

## 3. 数据通路 `Datapath`

职责：实现寄存器（PC/MAR/MBR/IR/BR/ACC/MR）、ALU、多路选择器，以及与 RAM 的地址/数据连接。

### 3.1 建议端口（推荐固定，便于并行开发）

#### 3.1.1 时钟与复位

- 输入：`clk`
- 输入：`rst`（同步复位；课设要求 reset 与时钟同步）

#### 3.1.2 与 RAM 的接口

- 输出：`mem_addr[7:0]`（建议直接等于 `MAR`）
- 输出：`mem_wdata[15:0]`（建议直接等于 `MBR`，由 CU 保证写内存前 MBR 已准备好）
- 输入：`mem_rdata[15:0]`（来自 RAM，同步读延迟 1 拍）

> 写使能 `ram_we` 建议由 `ControlUnit` 直接输出到 `Ram256x16`，避免 datapath 里出现“输入输出同名 we”的绕。

#### 3.1.3 控制输入（来自 ControlUnit）

推荐把控制信号“语义化”，不要直接暴露 C0/C1/C2… 的位：

（以下信号名/位宽建议固定，编码方式可用 `enum`/`localparam`）：

- `pc_we`：1-bit
- `pc_sel[1:0]`：
  - `PC_SEL_PLUS1`：`PC <- PC + 1`
  - `PC_SEL_ADDR`：`PC <- instr_addr`（即 `MBR[7:0]` 或 IR 旁路的地址字段）

- `mar_we`：1-bit
- `mar_sel[1:0]`：
  - `MAR_SEL_PC`：`MAR <- PC`（取指）
  - `MAR_SEL_ADDR`：`MAR <- instr_addr`（访存）

- `mbr_we`：1-bit
- `mbr_sel`：1-bit
  - `MBR_SEL_MEM`：`MBR <- mem_rdata`
  - `MBR_SEL_ACC`：`MBR <- ACC`（写内存前准备写数据）

- `ir_we`：1-bit（`IR <- MBR[15:8]`）

- `br_we`：1-bit
- `br_sel`：1-bit（可选，若你们想区分 `BR <- MBR` 与 `BR <- mem_rdata`；否则统一 `BR <- MBR` 即可）

- `acc_we`：1-bit
- `acc_sel[1:0]`：
  - `ACC_SEL_ALU`：`ACC <- alu_y`
  - `ACC_SEL_ZERO`：`ACC <- 16'h0000`
  - （可选）`ACC_SEL_MBR`：`ACC <- MBR`（若你们希望 LOAD 直接写回而不走 ALU）

- `mr_we`：1-bit（乘法相关）
- `mr_sel`：实现自定（如 `MR <- mul_hi`）

- `alu_op`：ALU 操作选择（见 3.4）

### 3.2 输出（反馈给控制单元/顶层）

- `opcode[7:0]`（建议直接等于 `IR`）
- `acc_sign`（建议直接等于 `ACC[15]`）
- （可选 debug）`dbg_pc[7:0]`, `dbg_acc[15:0]`, `dbg_ir[7:0]`

### 3.3 关键实现约定（避免歧义）

- 指令字格式固定：`MBR[15:8]` 为 opcode，`MBR[7:0]` 为 addr/imm。
- 取指建议流程（配合同步读 RAM）：
  1) `MAR <- PC`
  2) 下一拍：`MBR <- mem_rdata`
  3) `IR <- MBR[15:8]`，同时可用 `MBR[7:0]` 作为指令地址字段

> 因 RAM 同步读会延迟 1 拍，所以所有“读内存”的微程序都要显式考虑这一拍延迟。

### 3.4 （可选）ALU 子模块接口 `Alu16`

如果你们希望把 ALU 单独做成模块（便于 A 单独开发、C 单测），建议采用最小组合接口：

- 输入：`a[15:0]`（通常接 ACC）
- 输入：`b[15:0]`（通常接 BR）
- 输入：`op`（ALU 操作选择）
- 输出：`y[15:0]`
- （可选）输出：`y_hi[15:0]`（用于乘法高 16 位写 MR；若 MPY 不走 ALU 可不实现）

`op` 语义建议与课设 Table 3 对齐（避免混淆指令 opcode）：

- `ALU_ADD`：`y = a + b`
- `ALU_SUB`：`y = a - b`
- `ALU_AND`：`y = a & b`
- `ALU_OR`：`y = a | b`
- `ALU_NOT_B`：`y = ~b`（课设：NOT(BR)）
- `ALU_SHIFTL_B`：`y = b << 1`
- `ALU_SHIFTR_B`：`y = b >> 1`

> 课设 Table 1 的 `NOT/SHIFT` 描述以 `[X]` 为操作数来源。
> 推荐统一实现：先 `BR <- MEM[X]`，再用上述 ALU 操作得到结果写回 `ACC`。

## 4. 控制单元 `ControlUnit`（微程序控制）

职责：维护 `CAR`（control address register），读取控制存储器（control memory/ROM），发出各类控制信号；根据 `IR(opcode)`、`acc_sign` 做微地址转移。

### 4.1 端口

- 输入：`clk`, `rst`
- 输入：`opcode[7:0]`（来自 datapath 的 IR）
- 输入：`acc_sign`
- 输出：所有 datapath 控制信号（见 3.1.3）
- 输出：`ram_we`（写 RAM 使能，直接连到 `Ram256x16.we`）
- 输出：`halted`

### 4.2 微程序实现形式（建议二选一）

- 方案A（更直观）：`case (car_q)` 输出一组控制信号 + `car_next`
- 方案B（更贴近课设）：控制存储器 ROM（`.mem` 初始化）+ 控制缓冲寄存器 CBR

> 小组建议先用方案A跑通，再视情况替换为 ROM 形式（接口不变）。

## 5. 文件归属建议（避免冲突）

- A（数据通路）维护：`rtl/datapath/*.sv`
- B（控制器）维护：`rtl/control/*.sv`
- C（验证/板级）维护：`sim/*`、`constraints/*`、`programs/*`

只要遵守本接口草案，三人可以并行推进，最后由顶层做集成。
