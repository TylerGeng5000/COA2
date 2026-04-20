# 三人小组分工与周计划（可执行版本）

## 1. 角色分工（强并行、弱耦合）

### A：数据通路负责人（Datapath Owner）

交付物：寄存器集合 + ALU + RAM 连接 + debug 导出。

- 实现：PC/MAR/MBR/IR/BR/ACC/MR
- ALU：ADD/SUB/AND/OR/NOT/SRL/SRR（MPY 另行处理）
- 输出：`opcode`、`acc_sign`、`dbg_pc/dbg_acc`

### B：控制器负责人（Control Owner）

交付物：微程序控制单元（CAR/控制存储器/转移逻辑）与各指令的微序列。

- 先把“基线指令集”控制序列跑通
- 再补齐完整指令集与异常/边界行为（HALT、分支等）

### C：验证与板级负责人（Verification + FPGA Owner）

交付物：testbench 回归、程序装载格式、上板约束/演示流程。

- testbench：能加载 memory init（HEX/MEM），跑到 HALT 自动判定 PASS/FAIL
- 回归用例：sum(1..100)、分支覆盖、MPY/逻辑/移位专项
- 上板：时钟/复位、LED/数码管映射（如课程要求）

## 2. 冻结里程碑（建议）

- M0：冻结接口（本仓库 `CPU/docs/02_interfaces.md`）
- M1：基线指令集闭环（能跑 sum(1..100) 并 HALT）
- M2：完整指令集闭环（含 MPY/逻辑/移位）
- M3：上板演示闭环（复位稳定、可观察 PC/ACC 变化、演示程序可复现）

## 3. 两周推进表（按“课设常见节奏”）

> 如果你们实际周期是 1 周或 3 周，把每一行压缩/拉伸即可。

### 第1周：可运行 CPU（优先闭环）

- Day1：
  - 全员：通读课设要求，冻结接口与指令语义约定（尤其 MPY 高低字）
  - C：搭 testbench 骨架（加载内存、时钟复位、跑到 HALT）
- Day2-3：
  - A：完成寄存器 + RAM 读写路径 + ALU(ADD/SUB)
  - B：完成取指/译码基本微序列 + LOAD/STORE/ADD/SUB
  - C：做 sum(1..100) 用例与波形检查点
- Day4-5：
  - B：补 JMPGEZ/JMP/HALT
  - A：补 debug 输出、修位宽/时序
  - C：做分支覆盖用例与回归脚本

目标：M1 达成。

### 第2周：补齐完整指令 + 上板

- Day6-7：
  - A：补 AND/OR/NOT/SHIFT 所需的数据通路控制点
  - B：补 AND/OR/NOT/SHIFTL/SHIFTR 微序列
  - C：补逻辑/移位专项用例
- Day8-9：
  - A+B：实现/对齐 MPY 语义（含 MR/ACC 写回规则）
  - C：MPY 三组用例（6*5、-6*5、-6*-5）及结果检查
- Day10：
  - C：上板约束与演示流程固化
  - 全员：做一次“从空工程到演示”的走查（确保可复现）

目标：M2/M3 达成。

## 4. 每日检查清单（5分钟）

- 拉取最新 `main`：`git pull --rebase`
- 本地至少跑一遍核心回归（基线指令集）
- 当天新增/修复点记录在 PR 描述里
- 若改动接口：同步更新 `CPU/docs/02_interfaces.md`
- 合并前互相 Review：重点看位宽、时序、默认赋值、分支条件

## 5. 风险点与对策

- 风险：RAM 读写时序不统一 → 对策：先在接口文档固定“同步读/写在时钟沿”并让微程序按此设计。
- 风险：MPY 结果拆分不一致 → 对策：Day1 冻结 `MR/ACC` 高低字规则，并写成测试用例锁死。
- 风险：只在最后一天上板 → 对策：第2周 Day6 就开始做最小上板（LED 显示 halted/PC）。
