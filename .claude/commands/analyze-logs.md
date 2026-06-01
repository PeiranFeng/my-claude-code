---
name: analyze-logs
description: Analyze GPU monitoring data (monitor.csv) and training metrics from a completed compass-app-jasper experiment. Use when the user wants a GPU utilization report or training metrics summary from an experiment directory.
disable-model-invocation: false
allowed-tools: Bash Read Glob Grep
---

# Analyze Experiment Logs

## Step 1 — 确认实验目录

确认目标实验目录（用户提供，或从对话上下文推断）：
```bash
ls <exp-dir>/
```

## Step 2 — 确认可用的日志文件

**先检查文件是否存在、格式是什么，再做任何分析。不要假设某个字段存在。**

检查以下文件（如存在）：
- `monitor.csv` — GPU 监控数据
- `run.log` — 主流程日志（含训练 metrics CSV）
- `monitor.out` — GPU 监控文本版

对每个文件：
```bash
head -3 <file>
wc -l <file>
```

列出实际可用的字段/列，告知用户哪些分析可以做，哪些不存在。**如果用户请求的指标不在日志里，立即告知，不要继续搜索。**

## Step 3 — GPU 利用率分析（如 monitor.csv 存在）

**训练阶段判断**：用任意一张卡有进程（`num_procs > 0`）作为训练阶段的标志，而不是只看 GPU0 的显存。这样可以正确处理多卡并行、GPU0 较晚分配的情况。

对训练阶段的每张 GPU 利用率计算以下统计量（不能只用均值和 range）：

| 指标 | 说明 |
|------|------|
| 中位数 | 典型水平 |
| 均值 | 平均水平 |
| 标准差 | 波动程度 |
| P25–P75 | 中间 50% 的区间（四分位距） |
| 最小值/最大值 | 极端值参考 |

同时统计：
- 各卡的**双进程占比**（`num_procs == 2` 的采样比例）
- 各卡的**三进程占比**（`num_procs == 3` 的采样比例）
- 各卡的**四进程占比**（`num_procs == 4` 的采样比例）
- 全局双进程占比（所有卡×采样点中 `num_procs == 2` 的比例）
- 如 `gpu{i}_power_w` 列存在，统计各卡训练期间功耗（W）的均值、最大值

## Step 4 — 训练 metrics 分析（如 run.log 含 iter CSV）

检查 iter CSV 的列名（第一行以 `iter,` 开头）：
```bash
grep -m1 "^iter," run.log
```

只分析实际存在的列，不要搜索不在列名中的字段。

## Step 5 — 输出报告

```
实验目录：<path>
训练时段：<开始时间> → <结束时间>（共 X 分钟）

GPU 概览（训练期间，共 N 个采样点）：
  全局双进程占比：X%

各卡利用率：
  GPU  显存(MB)  中位数  均值  标准差  P25–P75      双进程%  三进程%  四进程%  均值功耗(W)  峰值功耗(W)
  GPU0  XXXX    XX%    XX%   XX%    XX%–XX%     XX%     XX%     XX%    XXX        XXX
  GPU1  XXXX    XX%    XX%   XX%    XX%–XX%     XX%     XX%     XX%    XXX        XXX
  ...

（如 monitor.csv 无 power_w 列，功耗列省略）

不可用的指标：<列出用户请求但日志中不存在的字段>
```
