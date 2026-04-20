# Vivado 工程文件架构（全 Verilog .v/.vh）

本仓库按“图中每个框模块化 + 顶层连线”的协作方式组织文件；同时避免把每个寄存器都拆成单独文件导致连线碎片化。

## 1. 推荐目录

- `CPU/rtl/`：可综合 Verilog RTL（全部 `.v` + 公共 `.vh`）
- `CPU/sim/`：仿真 testbench（`.v`）
- `CPU/programs/`：内存初始化文件（`readmemh` 用的 `.hex`）
- `CPU/constraints/`：Vivado 约束（`.xdc`，按板卡实际引脚补）
- `CPU/docs/`：规格、接口、分工与课设要求清单

## 2. 关键文件与职责（逐文件）

### 2.1 `CPU/rtl/defines.vh`

用途：全工程共享常量，避免 A/B/C 各写各的。

必须定义：

- 位宽：`DATA_W=16`、`ADDR_W=8`
- opcode 常量：`OP_LOAD/OP_STORE/...`（来自课设 Table 1）
- 选择信号编码：`PC_SEL_*`、`MAR_SEL_*`、`MBR_SEL_*`、`ACC_SEL_*`
- ALU 内部 op：`ALU_ADD/...`（与指令 opcode 分开）

### 2.2 `CPU/rtl/alu16.v`（可选独立模块）

用途：实现课设 Table 3 的 ALU 操作。

必须包含变量/端口：

- 输入：`a[15:0]`、`b[15:0]`、`op[3:0]`
- 输出：`y[15:0]`
- 组合逻辑 `always @(*)`，无寄存器。

### 2.3 `CPU/rtl/ram256x16.v`

用途：实现 256×16 RAM（建议同步读以推断 BRAM）。

必须包含变量/端口：

- `mem[0:255]`：`reg [15:0] mem [0:255]`
- 输入：`clk`、`addr[7:0]`、`we`、`wdata[15:0]`
- 输出：`rdata[15:0]`（`reg`，在 `posedge clk` 更新）

可选：

- `INIT_FILE` 参数：仿真时 `$readmemh` 预装程序/数据。

### 2.4 `CPU/rtl/datapath.v`

用途：实现寄存器集合与数据通路（A 的主战场）。

必须定义的寄存器（课设要求）：

- `pc_q[7:0]`, `mar_q[7:0]`, `mbr_q[15:0]`, `ir_q[7:0]`, `br_q[15:0]`, `acc_q[15:0]`, `mr_q[15:0]`

必须提供的端口：

- RAM：`mem_addr[7:0]`、`mem_wdata[15:0]`、`mem_rdata[15:0]`
- 控制输入：`pc_we/pc_sel/mar_we/mar_sel/mbr_we/mbr_sel/ir_we/br_we/acc_we/acc_sel/alu_op/mr_we`
- 反馈/调试输出：`opcode[7:0]`、`acc_sign`、`dbg_pc/dbg_acc/dbg_ir`

实现要点：

- 同步复位：`always @(posedge clk)` 中 `if (rst) ... else ...`
- 指令字段来源：`instr_addr = mbr_q[7:0]`，opcode = `ir_q`

### 2.5 `CPU/rtl/control_unit.v`

用途：实现微程序控制单元（B 的主战场）。

必须定义的状态/变量：

- `car_q[7:0]`：微地址寄存器
- 控制信号输出寄存器：`pc_we/.../alu_op/.../ram_we/halted`

实现要点：

- 输出控制信号必须“默认清零”，再按 `car_q` 置位（避免锁存器）
- 必须显式考虑 RAM 同步读延迟 1 拍（取指/读操作多一个微周期）

### 2.6 `CPU/rtl/simple_cpu_top.v`

用途：顶层集成（C 或集成人员负责）。

必须包含：

- 实例化：`Datapath`、`ControlUnit`、`Ram256x16`
- 连线：`mem_addr/mem_wdata/mem_rdata/opcode/acc_sign/ram_we`
- 输出：`halted` 与 `dbg_*`

### 2.7 `CPU/sim/tb_simple_cpu.v`

用途：最小可跑 testbench。

必须包含：

- 时钟发生器
- 同步复位脉冲
- 超时保护（例如 2000 cycles）
- `RAM_INIT_FILE` 指向程序镜像（`CPU/programs/*.hex`）

### 2.8 `CPU/programs/sum_1_100.hex`

用途：课设给的 1..100 求和示例程序内存镜像（`$readmemh` 可直接读）。

必须包含：

- `@00` 的指令区
- `@A0` 的数据区（A0=0, A1=1, A2=100 等）

## 3. Vivado 中如何添加文件

- 把 `CPU/rtl/*.v` 与 `CPU/rtl/defines.vh` 加入 **Design Sources**
- 把 `CPU/sim/tb_simple_cpu.v` 加入 **Simulation Sources**
- 把 `CPU/programs/sum_1_100.hex` 加入 **Simulation Sources**（或设置仿真工作目录使相对路径可见）

> 注意：你要求后缀都用 `.v`，所以本工程避免使用 `.sv` 和 SystemVerilog 语法。
