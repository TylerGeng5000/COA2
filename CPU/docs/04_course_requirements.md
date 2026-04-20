# 课设PDF要求摘录与落地清单（Microprogrammed CPU Design）

本页把课程提供的 PDF《Computer Organization and Architecture Course Design2026》里 **Microprogrammed CPU Design** 章节的关键“硬性要求/隐含约束/建议交付物”提炼为可执行清单，供实现与验收对齐。

> 注意：该 PDF 前半部分还有一个 **POC（并行输出控制器/打印机握手）** 的项目说明；与你们当前“实现简单CPU”的任务无关时，可忽略。

## 1. 目标与范围

- 目标：设计并验证一个“简单 CPU（Central Processing Unit）”。
- 重点关系：寄存器读写、存储器读写、指令执行。
- 组成部分（至少四部分）：控制单元、内部寄存器、ALU、指令集。

## 2. 指令格式与存储器规模（硬指标）

- 存储器：`256 × 16`。
- 指令字：`16-bit`。
- 单地址指令格式：
  - `opcode`：8-bit
  - `addr/imm`：8-bit
- 寻址：
  - 大多数指令使用直接寻址：`[X]` 表示 memory 的 X 地址内容。
  - 部分指令可把 address part 当作立即数（PDF 里提到 immediate addressing 的概念；是否在本实验指令中使用，以 Table 1 与助教要求为准）。

## 3. 指令集要求（硬指标）

- PDF Table 1 给出 opcode 与语义。
- 明确要求：**All the instructions should be implemented in your design.**
- Table 1（PDF中展示的部分）至少包含：
  - `STORE`, `LOAD`, `ADD`, `SUB`, `JMPGEZ`, `JMP`, `HALT`
  - `MPY`
  - `AND`, `OR`, `NOT`, `SHIFTR`, `SHIFTL`
  - 以及后续“……”（如 PDF 课程实际还扩展了更多指令/同学课上补充，以课堂最终表为准）

### 3.1 分支行为（PDF示例说明）

- `JMPGEZ X`：若 `ACC >= 0` 则 `PC <- X`，否则 `PC <- PC+1`。
- 判定等价于：若 `ACC[15]==0`（符号位为 0）则跳转。

## 4. 测试程序要求（交付物）

PDF明确要求“设计若干程序测试这些指令”，并提供：

- 示例程序：计算 1..100 求和（给出指令级程序与 RAM HEX 内容示例）
- 乘法测试建议：用 `MPY` 分别计算 `6×5`、`-6×5`、`-6×-5` 并检查结果。
- 数据表示：**2’s complement**（补码）。

## 5. 内部寄存器与位宽（硬指标）

- `MAR`：8-bit
- `MBR`：16-bit
- `PC`：8-bit
- `IR`：8-bit（存 opcode）
- `BR`：16-bit
- `ACC`：16-bit
- `MR`：用于 `MPY`，执行过程中保存乘积的一部分（位宽在 PDF 描述中未单列，但按整体数据路径建议 16-bit 处理）
- `DR`：可能用于 `DIV`（本实验若不含 DIV，可不实现；若课堂要求实现，则由你们自行定义寄存器与算法）

## 6. 时序与复位（硬指标，容易踩坑）

- **All the registers are positive-edge-triggered.**（全部寄存器上升沿触发）
- **All the reset signals for the registers are synchronized to the clock signal.**（复位与时钟同步）

落地建议：全工程统一同步复位模板（不要有人用异步复位、有人用同步复位）。

## 7. ALU 必须支持的操作（硬指标）

PDF Table 3：

- `ADD`：`ACC <- ACC + BR`
- `SUB`：`ACC <- ACC - BR`
- `AND`：`ACC <- ACC & BR`
- `OR`：`ACC <- ACC | BR`
- `NOT`：`ACC <- ~BR`
- `SRL`：`ACC <- ACC << 1`（PDF 中 SRL 表述为左移 1 bit）
- `SRR`：`ACC <- ACC >> 1`（右移 1 bit）

> 与 Table 1 的 `SHIFTL/SHIFTR`（对 `[X]` 操作）结合实现时，建议先 `BR <- MEM[X]`，再用 ALU 完成写回 `ACC`。

## 8. 控制单元实现要求（微程序控制思路）

- 控制单元采用微程序控制的结构（Control Memory、CAR、CBR、Sequencing Unit）。
- PDF给出 `LOAD` 的控制流图与示例控制信号（C0..C10）。
- PDF建议流程：为每条指令画控制流图 → 由数据通路确定控制信号 → 写出该指令微程序序列。

> 你们实现时可以先用 `case(car)` 硬编码微程序（便于调试），再替换成 ROM 形式；关键是“外部可观察行为”一致。

## 9. 与仓库文档的对应关系

- 指令表与语义约定：见 `CPU/docs/01_min_isa.md`
- 模块端口与时序约定：见 `CPU/docs/02_interfaces.md`
- 同步复位与编码规范：见 `CPU/docs/00_conventions.md`
- 三人分工与推进计划：见 `CPU/docs/03_team_plan.md`
