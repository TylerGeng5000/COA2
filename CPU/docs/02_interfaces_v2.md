# 模块接口说明 v2（逐端口/逐信号解释版）

本文件是对 02_interfaces.md 的“解释版/教学版”：

- **不改变原接口草案的结论**，只把每个接口/信号/变量“到底干什么”说清楚。
- 默认采用课设要求：**寄存器上升沿触发 + 同步复位**；RAM 采用 **同步读（读延迟 1 拍）**。

> 建议阅读顺序：先看“顶层连线”→“RAM 时序”→“Datapath 的寄存器与控制点”→“CU 怎么在每个微周期拉这些控制点”。

---

## 0. 全局参数（为什么需要它们）

这些参数是“整个 CPU 的尺寸基准”，A/B/C 必须一致。

- DATA_W = 16
  - 数据通路宽度（ACC/BR/MBR/ALU 输入输出）
  - 课设 RAM 是 16 位字，因此数据宽度必须是 16。
- ADDR_W = 8
  - 地址宽度（PC/MAR/指令地址字段）
  - 8 位地址可寻址 256 个字，符合 256×16 RAM。
- MEM_DEPTH = 256
  - 内存深度（用于描述 RAM 有 256 个字）。

指令字段约定：

- instr[15:8]：opcode（IR 保存这 8 位）
- instr[7:0]：addr/imm（通常作为 X，用于访存/跳转）

---

## 1. 顶层 SimpleCpuTop（只负责“连线”和“导出可观察信号”）

### 1.1 顶层端口解释

- clk
  - 系统时钟。
- rst
  - 同步复位（在 clk 上升沿采样），用于把寄存器清零到可预期状态。
- halted
  - 停机指示：当执行 HALT 指令后，CU 将其置 1，并且通常让 CU 停止推进微地址/不再发写使能。
- dbg_pc[7:0]
  - 观测 PC：仿真看波形、上板时映射到 LED/数码管都很有用。
- dbg_acc[15:0]
  - 观测 ACC：多数指令最终都会影响 ACC，便于调试。
- dbg_ir[7:0]
  - 观测当前 opcode（IR 的内容），便于确认“取指/译码是否正确”。

### 1.2 顶层为什么要固定“最小连线”

顶层固定连线可以保证：

- A 写 Datapath 时只关心寄存器/数据流。
- B 写 ControlUnit 时只关心每拍拉哪些控制信号。
- C 写 RAM/top/testbench 时不会被内部实现拖着走。

顶层要做的事情只有：

- 把 Datapath 的 mem_addr/mem_wdata 接到 RAM
- 把 CU 的 ram_we 接到 RAM.we
- 把 RAM.rdata 接回 Datapath.mem_rdata
- 把 Datapath 的 opcode/acc_sign 喂给 CU

---

## 2. 存储器 Ram256x16（同步读是“微程序设计”的前提）

### 2.1 端口解释

- clk
  - RAM 内部寄存器（rdata）更新用。
- addr[7:0]
  - 访问地址（来自 Datapath 的 MAR）。
- we
  - 写使能（来自 CU）。
- wdata[15:0]
  - 写入数据（来自 Datapath；推荐取 MBR）。
- rdata[15:0]
  - 读出数据（同步读：在 clk 上升沿更新）。

### 2.2 “同步读延迟 1 拍”到底意味着什么

- 你在周期 N 把 addr 设为某个值 A。
- 到周期 N+1 的上升沿，rdata 才更新为 mem[A]。

所以任何“读内存”的动作在微程序上都要至少两步：

1) 先让 MAR 装载目标地址（addr 生效）
2) 再等一拍，把 rdata 锁存到 MBR（或 BR/ACC）

这也是为什么课设的 LOAD 示例里会出现多次 “MBR<=memory” 这种微操作。

---

## 3. Datapath（寄存器集合 + 数据选择器 + ALU + RAM 接口）

Datapath 的本质是：

- **一堆寄存器**（PC/MAR/MBR/IR/BR/ACC/MR）
- **一堆 mux**（决定本拍写入寄存器的值来自哪里）
- **一段组合运算**（ALU）
- **对外的 RAM 口**（MAR 驱动 addr、MBR 驱动 wdata、mem_rdata 作为读入源）

### 3.1 时钟与复位

- clk：驱动所有寄存器在上升沿更新。
- rst：同步复位。
  - rst=1 时，Datapath 要把寄存器清到合理初值（例如 PC=0、ACC=0 等）。

### 3.2 RAM 接口（三个信号）

- mem_addr[7:0]
  - Datapath 输出给 RAM 的地址。
  - 推荐直接连接为 MAR 的当前值。
  - CU 想读/写内存时，首先通过 mar_we/mar_sel 控制 MAR 装载正确地址。

- mem_wdata[15:0]
  - Datapath 输出给 RAM 的写数据。
  - 推荐直接等于 MBR。
  - 因为课设数据通路里 MBR 本来就是“内存缓冲寄存器”，写内存前先把 MBR 准备好最自然。

- mem_rdata[15:0]
  - Datapath 从 RAM 拿到的读出数据（同步读延迟 1 拍）。
  - CU 通常会在“下一拍”让 mbr_we=1 且 mbr_sel=MEM，把 mem_rdata 锁存进 MBR。

为什么 ram_we 不做成 Datapath 的输入？

- 因为写使能是“控制策略”，属于 CU 的职责。
- Datapath 只负责提供地址与数据；是否写由 CU 决定。

### 3.3 控制输入（CU→Datapath）的逐信号解释

下面每个信号都是“微程序的一根手指”，B 写 CU 的工作就是在每个微周期把这些手指摆成正确姿势。

#### 3.3.1 PC（程序计数器）相关

- pc_we
  - 置 1 时表示“本拍要更新 PC”。
  - 置 0 时 PC 保持不变。

- pc_sel[1:0]
  - 当 pc_we=1 时，`pc_sel` 选择 PC 的写入来源。
  - **本工程的编码约定（对齐 CPU/rtl/defines.vh）：**
    - `pc_sel = 2'b00`（PC_SEL_PLUS1）：PC <- PC + 1（顺序执行下一条指令）
    - `pc_sel = 2'b01`（PC_SEL_ADDR）：PC <- instr_addr（跳转；instr_addr 通常来自 MBR[7:0]）
    - `pc_sel = 2'b10`：保留（reserved），建议当作“保持不变/非法值”处理
    - `pc_sel = 2'b11`：保留（reserved），建议当作“保持不变/非法值”处理

  - 为什么要保留 10/11：
    - 以后如果你们扩展“PC <- PC + imm”或“PC <- ACC[7:0]”之类的特性，有编码空间。
    - 现阶段基线 CPU 用不到，越少 mux 分支越不容易写错。

典型用法：

- 取指结束时：pc_we=1, pc_sel=PLUS1
- JMP/JMPGEZ 成立时：pc_we=1, pc_sel=ADDR

#### 3.3.2 MAR（内存地址寄存器）相关

- mar_we
  - 置 1 时“本拍要更新 MAR”。

- mar_sel[1:0]
  - 选择 MAR 写入来源。
  - **本工程的编码约定（对齐 CPU/rtl/defines.vh）：**
    - `mar_sel = 2'b00`（MAR_SEL_PC）：MAR <- PC（用于取指：把下一条指令地址送 RAM）
    - `mar_sel = 2'b01`（MAR_SEL_ADDR）：MAR <- instr_addr（用于 LOAD/STORE/ADD… 的访存地址）
    - `mar_sel = 2'b10`：保留（reserved）
    - `mar_sel = 2'b11`：保留（reserved）

典型用法：

- 取指第 1 拍：mar_we=1, mar_sel=PC
- 执行访存类指令时：mar_we=1, mar_sel=ADDR

#### 3.3.3 MBR（内存缓冲寄存器）相关

- mbr_we
  - 置 1 时“本拍要更新 MBR”。

- mbr_sel
  - 选择 MBR 写入来源。
  - **本工程的编码约定（对齐 CPU/rtl/defines.vh）：**
    - `mbr_sel = 1'b0`（MBR_SEL_MEM）：MBR <- mem_rdata（从内存读入一字）
    - `mbr_sel = 1'b1`（MBR_SEL_ACC）：MBR <- ACC（把 ACC 的值准备成写内存的数据）

典型用法：

- 取指第 2 拍（同步读 RAM）：mbr_we=1, mbr_sel=MEM
- STORE 之前：mbr_we=1, mbr_sel=ACC（把要写的数据装进 MBR）

#### 3.3.4 IR（指令寄存器）相关

- ir_we
  - 置 1 时：IR <- MBR[15:8]
  - IR 存的是 opcode（8 位）。

典型用法：

- 取指完成时：ir_we=1

#### 3.3.5 BR（缓冲寄存器，作为 ALU 第二操作数）相关

- br_we
  - 置 1 时“本拍要更新 BR”。

- br_sel（可选）
  - 如果实现 br_sel，通常用于区分 BR 的来源（例如从 MBR 或直接从 mem_rdata）。
  - 如果不实现 br_sel，也没问题：统一让 BR <- MBR，CU 通过控制“先把东西装进 MBR”来间接控制 BR。

典型用法：

- LOAD：先读内存到 MBR，再 br_we=1 让 BR <- MBR
- ADD/SUB/AND/OR：同理，先把 MEM[X] 读到 MBR，再 BR <- MBR

#### 3.3.6 ACC（累加器）相关

- acc_we
  - 置 1 时“本拍要更新 ACC”。

- acc_sel[1:0]
  - 选择 ACC 的写入来源。
  - **本工程的编码约定（对齐 CPU/rtl/defines.vh）：**
    - `acc_sel = 2'b00`（ACC_SEL_ALU）：ACC <- alu_y（最常见）
    - `acc_sel = 2'b01`（ACC_SEL_ZERO）：ACC <- 16'h0000（课设 LOAD 示例里会用到清零）
    - `acc_sel = 2'b10`（ACC_SEL_MBR）：ACC <- MBR（若你们希望 LOAD 直接写回，不走 ALU）
    - `acc_sel = 2'b11`：保留（reserved），建议当作“保持不变/非法值”处理

典型用法：

- LOAD（走 ALU 版本）：先 ACC<-0，再 ACC<-ACC+BR
- ADD：ACC<-ACC+BR
- SUB：ACC<-ACC-BR
- AND/OR：ACC<-ACC &/| BR
- NOT/SHIFT（按课设 Table1 对 [X]）：先 BR<-MEM[X]，再 ACC<-NOT(BR) 或 SHIFT(BR)

#### 3.3.7 ALU 控制

- alu_op
  - 选择 ALU 做什么运算。
  - 注意：它是 **内部运算选择**，不等同于指令 opcode。

建议与课设 Table 3 对齐：

**本工程的编码约定（对齐 CPU/rtl/defines.vh，4-bit）：**

- `alu_op = 4'd0`（ALU_ADD）：y = a + b
- `alu_op = 4'd1`（ALU_SUB）：y = a - b
- `alu_op = 4'd2`（ALU_AND）：y = a & b
- `alu_op = 4'd3`（ALU_OR）：y = a | b
- `alu_op = 4'd4`（ALU_NOT_B）：y = ~b
- `alu_op = 4'd5`（ALU_SHIFTL_B）：y = b << 1
- `alu_op = 4'd6`（ALU_SHIFTR_B）：y = b >> 1
- `alu_op = 4'd7 ~ 4'd15`：保留（reserved），建议输出 0（或保持 y=0）

其中 a 通常接 ACC，b 通常接 BR。

#### 3.3.8 MR（乘法寄存器）相关

- mr_we
  - 乘法相关写使能。
  - MPY 的算法/结果拆分（ACC 低 16 / MR 高 16）需要你们在实现时固定。

### 3.4 Datapath 输出（Datapath→CU/Top）的逐信号解释

- opcode[7:0]
  - 当前指令的 opcode（通常就是 IR 的内容）。
  - CU 用它来“dispatch”：决定跳转到哪条指令的微程序入口。

- acc_sign
  - ACC 的符号位（通常就是 ACC[15]）。
  - CU 用它实现 JMPGEZ：acc_sign=0 表示 ACC>=0。

- dbg_pc/dbg_acc/dbg_ir
  - 仅用于调试/上板观测，不参与功能。
  - 强烈建议保留：它能把联调成本降低一半。

---

## 4. Alu16（可选独立模块）

如果你们把 ALU 独立成模块，它是“纯组合逻辑”，端口含义非常直接：

- a：操作数 1（建议接 ACC）
- b：操作数 2（建议接 BR）
- op：运算选择
- y：结果（写回 ACC）

为什么 ALU 不需要 clk/rst？

- 因为它不存状态，只做 combinational 计算。

---

## 5. ControlUnit（微程序控制：把控制信号按拍输出）

CU 的工作可以概括为：

1) 维护微地址 CAR（当前处于哪个微周期/微指令）
2) 在每个微周期输出一组控制信号（驱动 Datapath 的寄存器写入/选择）
3) 在“dispatch 点”根据 opcode 跳转到对应指令的微程序入口
4) 对 JMPGEZ 这种依赖标志的指令，根据 acc_sign 决定不同分支

### 5.1 CU 输入端口解释

- clk/rst：驱动 CAR 等状态寄存器。
- opcode：来自 Datapath.IR（当前指令是什么）。
- acc_sign：来自 Datapath.ACC[15]（用于 JMPGEZ 判断）。

### 5.2 CU 输出端口解释

- pc_we/pc_sel/.../alu_op/mr_we：同 Datapath 控制输入（见第 3 节）。
- ram_we
  - 写内存使能：ram_we=1 的那个时钟沿，RAM 执行 MEM[addr] <- wdata。
  - 注意：写内存必须保证此时 Datapath.MAR 已是目标地址、MBR 已是要写的数据。
- halted
  - HALT 后置 1。
  - 常见做法：halted=1 后 CU 停止推进 CAR，并且所有 we 保持 0，CPU 状态冻结。

---

## 6. 一个“微程序如何拉控制信号”的例子（帮助你把信号用起来）

以同步读 RAM 的取指为例（不是唯一实现，但最直观）：

- T0：mar_we=1, mar_sel=PC（把 PC 放到 MAR，开始取指）
- T1：mbr_we=1, mbr_sel=MEM（拿到上一拍地址对应的 rdata，锁进 MBR）
- T2：ir_we=1（IR<-MBR[15:8]），pc_we=1 pc_sel=PLUS1（PC++）
- T3：dispatch（根据 opcode 跳到指令微程序入口）

访存读（例如 LOAD X）的核心套路：

- 先 MAR<-addr
- 等一拍 MBR<-MEM
- 再用 BR/ALU/ACC 完成写回

---

## 7. 目录归属说明（与当前 .v 工程一致）

原草案第 5 节用了 `.sv` 作为示例后缀；但你们工程明确使用 `.v`。

建议以当前仓库骨架为准：

- A（数据通路）维护：CPU/rtl/datapath.v、CPU/rtl/alu16.v
- B（控制器）维护：CPU/rtl/control_unit.v
- C（验证/板级）维护：CPU/rtl/ram256x16.v、CPU/rtl/simple_cpu_top.v、CPU/sim/*、CPU/programs/*、CPU/constraints/*

---

## 8. 常见误区（对照自检）

- 把 opcode 和 alu_op 混用：opcode 是“指令”，alu_op 是“ALU 内部运算选择”。
- 忘记同步读 RAM 延迟：读内存必然要多一个微周期。
- CU 没有给控制信号默认值：会在组合逻辑里推断锁存器，导致波形怪异。
- halted 后还在写寄存器：HALT 后应冻结状态（所有 *_we=0）。
