---
name: run-experiment
description: Launch a compass-app-jasper experiment with GPU monitoring. Writes monitor.py, starts the experiment and monitor process, and stops the monitor automatically when the experiment finishes or terminates.
disable-model-invocation: false
allowed-tools: Bash Read Glob Grep Write
---

# Run Experiment

## Step 1 — 检查 submodule 状态

```bash
cd ~/data/compass-app-jasper && git submodule status
```

列出每个 submodule 的状态（`+` 表示与记录不一致，`-` 表示未初始化）：

- 全部正常（无前缀）：告知用户，继续
- 有不一致：**不要自动 update**，列出具体情况，询问用户是否执行 `git submodule update`，等待确认后再继续

## Step 2 — 验证 Hydra override 路径

**在创建目录之前先验证参数**，避免参数错误时目录已经建好。

对用户提供的每一个 OVERRIDE 参数：
1. 找到对应的 yaml 文件（在 `~/data/compass-app-jasper/app2/conf/` 下）
2. 确认该 key 的完整嵌套路径存在（如 `backtest.window_generator.size`，而不是 `window_generator.size`）
3. 如果找不到对应 key，停止并告知用户，不要继续

## Step 3 — 确定实验目录

目录命名和文档规范见 CLAUDE.md。

- 向用户确认目录名和类型（test/exp）

**如果目录已存在**（重复运行）：
- 告知用户需要清理实验产物（`train/`、`merged/`、`outputs/`、`run.log`、`windows/` 等），保留 `description.md` 和 `design.md`
- 等待用户确认后清理，再继续

**如果目录不存在**（新实验）：
- 创建目录，自动填入能推断的字段（分支、关键参数），只询问以下两项：
  - **目的**：这个实验是为了验证什么
  - **预期验证**：要回答的具体问题
- 按 CLAUDE.md 中的模板写入 `description.md`

## 并发数参考（8 卡 RTX PRO 6000 Blackwell）

根据 `exp/improve-gpu-manager-max-procs-{2,3,4}-default-full` 对比实验（2026-04-09，26 window、single seed、JP 数据）：

| max-procs-per-gpu | -j | 耗时 |
|:-----------------:|:--:|------|
| 2 | 32 | 1:10:06 |
| **3** | **32** | **1:05:36** ← 最优 |
| 4 | 32 | 1:06:06 |

**结论：单 seed 实验默认用 `-j32`。**

- `gpu_manager.py` 的 `DEFAULT_MAX_PROCS_PER_GPU = 3`（已是默认，无需额外传参）
- 8 GPU × 3 进程/卡 = 24 并发上限，`-j32` 保持队列不空
- 多 seed 时 `-j` 同样用 32，seed 级并发由 Make 内部调度

## Step 4 — 汇总完整命令，等待确认

向用户展示以下内容，等待明确确认后再执行：

```
实验目录：<path>

完整命令：
  DATA_SOURCE_PATH=<path>/data \
  BACKTEST=<value> \
  SEEDS=<value> \
  TASK=<value> \
  OVERRIDE="<overrides>" \
  bash run.sh -j<N> > run.log 2>&1 &

参数检查：
  ✓/✗  DATA_SOURCE_PATH 含 /data 后缀
  ✓/✗  SEEDS 已指定（如未指定，请确认是否使用默认）
  ✓/✗  TASK 已指定
  ✓/✗  所有 OVERRIDE 路径已验证
  ✓/✗  -j 并行数已指定（如未指定，请确认是否使用默认）
```

同时询问用户：**是否需要启动 GPU 监控？**（需要明确回答）

## Step 5 — 用户确认后执行

从 run_exp 复制所需文件：

```bash
mkdir -p <exp-dir>
cp /home/peiran/data/run_exp/run.sh <exp-dir>/
# 如需监控：
cp /home/peiran/data/run_exp/monitor.py <exp-dir>/
```

启动实验和监控，**必须拆成独立的 Bash 调用，不能合并进同一条命令**。原因：多行命令在单次 eval 中执行时，`$!` 和后续 echo 会被拼接在同一行（变成 `EXP_PID=$!echo "..."`），导致变量赋值失败。

### 不启动监控

**调用 1 — 启动实验：**
```bash
cd <exp-dir>
DATA_SOURCE_PATH=... bash run.sh -j<N> ... > run.log 2>&1 &
echo "实验 PID: $!"
```

### 启动监控

**调用 1 — 先启动监控：**
```bash
cd <exp-dir>
python monitor.py > monitor.out 2>&1 &
echo "监控 PID: $!"
```

**调用 2 — 再启动实验：**
```bash
cd <exp-dir>
DATA_SOURCE_PATH=... bash run.sh -j<N> ... > run.log 2>&1 &
echo "实验 PID: $!"
```

**调用 3 — 启动守护进程（用上面记录的实际 PID 替换）：**
```bash
EXP_PID=<实验PID>
MON_PID=<监控PID>
(
  while kill -0 $EXP_PID 2>/dev/null && [ ! -f <exp-dir>/.train_done ]; do
    sleep 30
  done
  kill $MON_PID 2>/dev/null
  echo "[monitor] 实验已结束，监控已停止"
) &
```

### 验证进程存活（有无监控均执行）

**调用 — 等待 30 秒后验证（用实际 PID 替换）：**
```bash
sleep 30
EXP_ALIVE=$(kill -0 <实验PID> 2>/dev/null && echo "运行中" || echo "已退出")
echo "实验进程 <实验PID>: $EXP_ALIVE"
```
如果进程已退出，立即查看 run.log 排查原因。

告知用户停止实验的正确方式（直接 kill PID 只杀父进程，子进程会成为孤儿继续运行）：
```bash
kill -- -$(ps -o pgid= -p <实验PID> | tr -d ' ')
```
