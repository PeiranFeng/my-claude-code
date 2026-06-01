> 备份文件：原 `10.0.2.28:~/data/compass-app-jasper/CLAUDE.md`

# CLAUDE.md

## 项目概览

日本股市量化金融研究平台，用于回测和 ML 模型训练。`app/`（v3，旧版）和 `app2/`（v4，活跃版）并行存在，**新工作一律用 `app2/`**。

---

## 代码库结构

### 子模块

| 子模块 | 路径 | 独立仓库 |
|--------|------|---------|
| `core` | `compass-app-jasper/core/` | `~/data/compass-core` |
| `lib2` | `compass-app-jasper/lib2/` | `~/data/fenghe-nn` |

**修改 core/lib2 必须在独立仓库目录下进行，不能改 jasper 的 submodule 路径。**

### 目录结构

| 路径 | 用途 |
|------|------|
| `app2/` | v4 应用入口 |
| `app2/conf/` | Hydra 配置树 |
| `app2/scripts/` | 入口脚本（window_generator、allocate_from_forecast_parquet） |
| `app2/make/` | 子 Makefile（TrainMovingWindows.mk、MergeMovingWindowResults.mk） |
| `app2/metric2/` | WeightedMetric 层级系统 |
| `lib/` | 共享 Python 库（fenghe.compass、Hydra wrappers、data utilities） |
| `lib2/` | C++/PyTorch/Triton GPU 内核库 |
| `core/` | 底层数值运算子模块（确定性 `lib._math_._cumsum_`） |
| `test/app2/` | app2 测试套件 |

### Namespace 合并

`fenghe` 是命名空间包，分布在 `lib/fenghe/` 和 `lib2/python/fenghe/`（后者有 `__init__.py`）。`conftest.py` 显式扩展 `fenghe.__path__` 使两部分均可见。

---

## 环境与运行

### 环境激活（每个 session 执行一次）

```bash
conda activate model-v4
export PYTHONNOUSERSITE=1
export PYTHONPATH="$HOME/data/compass-app-jasper/app2:$HOME/data/compass-app-jasper/core:$HOME/data/compass-app-jasper/lib:$HOME/data/compass-app-jasper/lib2"
```

### 运行测试

**统一使用 `unittest`，禁止使用 pytest（model-v4 环境未安装）。**

```bash
# 运行整个目录
PYTHONSAFEPATH=1 PYTHONPATH=$PWD/core:$PWD/app2:$PWD/lib:$PWD/lib2/python:$PWD/test/app2/data \
  conda run -n model-v4 python -m unittest discover -s test/app2/data -v

# 运行单个文件
PYTHONSAFEPATH=1 PYTHONPATH=$PWD/core:$PWD/app2:$PWD/lib:$PWD/lib2/python:$PWD/test/app2/data \
  conda run -n model-v4 python -m unittest test_data_set -v
```

关键点：`PYTHONSAFEPATH=1` 防止当前目录遮蔽 `core/lib/`；`core` 放最前确保确定性 CUDA cumsum；单文件运行时需显式把测试目录加入 PYTHONPATH（`conftest.py` 是 pytest 专属机制，unittest 不执行）。

### 运行实验

所有实验必须通过 `run.sh` 启动，**禁止直接调用子 Makefile**（`run.sh` 负责设置 PYTHONPATH、环境变量和所有 make 变量）。

```bash
# 1. 创建目录并复制 run.sh（临时验证 → test/；持久化实验 → exp/）
mkdir -p /home/peiran/data/test/<exp-dir>
cp /home/peiran/data/run_exp/run.sh /home/peiran/data/test/<exp-dir>/

# 2. 创建 description.md（见"实验目录文档规范"）

# 3. 后台运行
cd /home/peiran/data/test/<exp-dir>
bash run.sh \
  DATA_SOURCE_PATH=/data/JP_end_2026-02-10/data_2 \
  BACKTEST=latest \
  SEEDS="seed-00" \
  OVERRIDE="schema_file_path=conf/schema_files/mini.yaml train/execution=small train/executor=bold" \
  > run.log 2>&1 &

# 默认数据源：HK=/data/HK_end_2026-04-30/data_2  JP=/data/JP_end_2026-02-10/data_2

# 4. 停止实验
kill -- -$(ps -o pgid= -p <PID> | tr -d ' ')
```

TensorBoard：`/opt/miniconda3/envs/model-v4/bin/tensorboard --logdir /home/peiran/data/exp --port 6006 --bind_all`

**切换分支会影响后台实验**：Makefile 会调用仓库内脚本，多分支同时运行需使用不同仓库目录。

### 旧版应用 (v3)

```bash
Data=<PathToDataFolder> python app/build.py all
Seeds="seed-00" RUN_LEVEL=SANITY Data=<PathToDataFolder> python app/build.py all
```

---

## 配置参数

### 关键参数

| 维度 | 参数 | 选项 | 默认 |
|------|------|------|------|
| 回测窗口 | `BACKTEST=` | `latest`, `sanity`, `default`(全部) | `default` |
| 训练强度 | `train/execution=` | `small`(3 iter), `median`(3000), `full`(6000) | `full` |
| 学习率 | `train/executor=` | `bold`(1e-2), `mild`(1e-3), `default`(1e-5), `fine`(1e-4) | `default` |
| Schema | `schema_file_path=` | `conf/schema_files/mini.yaml`, `feature-60.yaml`, `feature-602.yaml`, `feature-v4-full.yaml` | `feature-602.yaml` |
| 任务 | `TASK=` | `long_gross_0_100`, `long_gross_95_100`, `simple_partial_index_long`, `simple_partial_index_short` | `default` |

**参数名以 config 文件中实际定义为准，运行实验前验证 override 路径确实存在于 config.yaml，不要凭记忆使用旧参数名（如 `schema=` 已弃用，用 `schema_file_path=`）。**

### Hydra 配置语法

`OVERRIDE` 混用 group override（`/`）和 value override（`.`）：

```bash
OVERRIDE="train/execution=small schema_file_path=conf/schema_files/mini.yaml"  # group override
OVERRIDE="train.evaluator.risk.metric.drawdown.weight=-0.2"                     # value override
```

Seed：用 `seed=seed-01`（override），不用 `+seed=seed-01`（append 会导致"appears more than once"错误）。

### 常用参数组合

| 用途 | BACKTEST | OVERRIDE | SEEDS |
|------|----------|---------|-------|
| 快速冒烟 | `latest` | `schema_file_path=conf/schema_files/mini.yaml train/execution=small train/executor=bold` | `seed-00` |
| sanity | `sanity` | 同上 | — |
| 全回测 | `default` | — | — |

---

## 架构

### Pipeline 流程

```
window_generator.py → windows/*.yaml
                           ↓
              train.py (per window, via TrainMovingWindows.mk)
                           ↓
              forecast/{train,test}.{stock,index}.parquet
                           ↓
       allocate_from_forecast_parquet.py
                           ↓
              allocation_from_forecast/{train,test}.parquet
                           ↓
       MergeMovingWindowResults.mk → merged/
```

### 多 Seed Pipeline

```
Makefile → TrainWithSeeds.mk
               ↓ per seed
           TrainWithOneSeed.mk → TrainMovingWindows.mk → TrainOneWindow.mk
               ↓
           MergeMovingWindowResults.mk → merged/ per seed
               ↓
           MergeSeedResults.mk → allocation/ensemble.py (avg weight across seeds)
```

### Metric 系统（`app2/metric2/`）

`WeightedMetric` 组合为树形结构，`weight` 含义：
- **非零**：有梯度，参与 loss
- **`0.0`**：`torch.no_grad()`，仅记录 TensorBoard
- **`null`**：不实例化，不计算

默认评估器（`conf/train/evaluator/default3.yaml`）：`_branch_` 路由树，在 stock/index 分支上评分 `Correlation` 和 `ExplainedErrorRatio`。调用时必须包裹 `Cache()`：
```python
with Cache():
    score = evaluator(output, target, query)
```

---

## 工作规范

### 规则 1：测试

**场景：编写或运行测试时**
- 统一使用 `unittest`（`python -m unittest`），禁止切换至 pytest
- **禁止**仅凭 import 成功或类型检查声称"验证通过"，必须实际运行测试套件并看到 OK

### 规则 2：设计 vs 实现模式

**场景：讨论接口、类结构、架构方案时（未收到明确实现指令前）**
- 只在对话中讨论，不读代码、不改文件、不提供完整实现方案
- 收到"开始实现"/"动手"/"implement" 等明确指令后，才开始写代码

**场景：准备修改文件时**
- 每次 Edit/Write 前，先用一句话说明要改什么、为什么
- **禁止**未经要求添加 fallback 逻辑、重命名变量、移动 import、删改无关注释
- 若认为需要更大范围改动，先说明后询问，不得自行扩展

### 规则 3：分支验证

**场景：开始分析 bug、描述代码行为、声称存在问题时**
- 先执行 `git branch --show-current` 确认当前分支与目标一致
- **禁止**在未确认分支的情况下描述代码行为或声称存在 bug

### 实验目录文档规范

每次创建实验目录时，同时创建 `description.md`：

```markdown
# <实验名>

**目的**：
**分支**：
**关键参数**：
**预期验证**：
```

涉及代码/超参设计讨论时，用 `/design` skill 在同目录下维护 `design.md`。

**重复运行实验**：保留 `description.md`（和 `design.md`），删除实验产物（`train/`、`merged/`、`outputs/`、`run.log`、`windows/`），再重新启动。

---

## Known Gotchas

**数据路径需 `/data` 后缀：**
```bash
DATA_SOURCE_PATH=/data/JP_end_2026-02-10/data   # 正确
DATA_SOURCE_PATH=/data/JP_end_2026-02-10         # 错误
```

**`data_source.load()` 返回 dataset，不设置 self.data_set：**
```python
data_set = data_source.load()          # 正确
data_source.load()
reference = data_source.data_set.time  # 错误
```

**Seed override 用 `seed=` 不用 `+seed=`：** `conf/default.yaml` 已有 `- seed: seed-00`，`+seed=seed-01` 会导致 "appears more than once" 错误。

**`/tmp/gpu_lock` 跨用户权限问题（已修复 merged to develop）：** 用 `os.open(O_RDWR)` 优先，失败后 fallback `os.open(O_CREAT|O_EXCL|O_RDWR)` + `fchmod(0o666)`。

---

## 训练健康评估

### Step 1：权重树恢复（OLS 反推）

用 OLS 将 TOTAL 回归到各子 metric，恢复实际权重（归一化，`|w|` 之和=1），再乘穿树得每个叶子的有效权重。R² 应接近 1.0；偏低说明分解不完整或存在非线性交互。

### Step 2：分桶 Mover 分析（在 validate 上）

将训练步数等分 5 桶，计算每个叶子 metric 的贡献：`delta_contribution = (mean[bucket] - mean[bucket-1]) × effective_weight`。第一桶跳过。

| 模式 | 含义 |
|------|------|
| 单一 metric 全程贡献 >50% | 该 metric 主导，其余是"乘客" |
| `var` 前期大幅贡献后趋平 | 早期方差快速拟合，之后停滞 |
| `cor`/`err` 贡献全程接近 0 | 无预测信号 |
| `err` 持续负贡献 | 过拟合信号 |
| 正负 mover 相互抵消 | 训练目标矛盾 |

### Step 3：Forecast 退化检查（基于 test）

| # | 检查项 | 阈值 | 意义 |
|---|--------|------|------|
| 1 | 日期不重叠 | 任何重叠 = FAIL | 数据泄漏，所有 metric 失效 |
| 2 | Drift-return 相关性 | test \|corr\| < 0.01 = WARN | 同时报 train corr 量化泛化 gap |
| 3 | Drift 退化 | test std < 1e-4 = FAIL | drift 近似常数，Kelly 产生固定仓位 |
| 4 | Variance collapse | test mean < 5e-4 = FAIL | Kelly weight → ∞ → allocation 饱和 |
| 5 | 市场方向 | INFO | 测试期指数累计收益 |

### Step 4：退化训练特征

1. `var/train` 极低（< 0.01）但 `var/test` 仍高（> 1.0）
2. `var` 贡献 >50%，`cor`/`err` 极小
3. Variance collapse FAIL
4. allocation net ≈ 任务边界（饱和）
5. TOTAL/validate 单调上升，TOTAL/test 中途反转下降

**已知修复**：`logvar_offset: 4.0` + var weight 降至 `-0.02`（stock）/`-0.1`（index），参考 `feat/default_rc02_task_946` 分支。
