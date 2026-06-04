# CLAUDE.md

## 关于本文件

只写"看代码看不出来但必须知道"的内容。**禁止信息重复**——同一事实只在一处出现，其他地方引用或省略，避免修改时出现不一致。

**信息来源优先级**（适用于 CLAUDE.md 和 skill 文件）：仓库代码 > CLAUDE.md > skill/markdown 文件。当某个信息在更高优先级的来源中已存在，只记录引用位置（如"见 CLAUDE.md"、"见 conf/ 下的 yaml"），不重复写内容。

**第一性原理**：优先完成用户要求的任务。遇到非当前分支或非用户需求范围的问题时，反馈给用户，**禁止自行研究**，避免陷入无效的推理陷阱。

1. **优先完成任务本身**：不被路上发现的"有趣问题"带偏。例如跑实验时发现的 warning、代码风格问题、其他分支的 bug，都不属于当前任务，不去管。
2. **越界问题只反馈，不深挖**：遇到非当前分支或超出需求范围的问题时，一句话报告给用户（"发现 X，可能有问题，是否需要处理？"）然后停下，由用户决定是否扩大范围，不自行展开调查。
3. **避免无效推理陷阱**：没有证据不猜测根因；不对目录结构、配置含义做假设并基于假设继续推理；任务卡住时回报用户，而不是换方向"自行研究"。一句话总结：**遇到边界就停下问用户，而不是替用户做决定继续走**。

---

## 语言要求

所有回复只能使用**中文**或**英文**，禁止出现其他语言（包括日文、韩文等）。

凡是上传到 GitHub 的文字，一律使用**英文**，包括 commit message、issue 描述、PR 标题和描述、PR comments 等。

---

## 项目概述

这是存放 Claude Code 配置（CLAUDE.md、skills、settings）的元仓库，供 `compass-app-jasper`、`compass-core`、`fenghe-nn` 三个仓库共用。

---

## 仓库关系

| 仓库路径 | 角色 |
|---------|------|
| `~/data/compass-app-jasper` | 主仓库（量化研究平台），包含两个 git submodule |
| `~/data/compass-core` | submodule `core/` 的源仓库（底层数值运算） |
| `~/data/fenghe-nn` | submodule `lib2/` 的源仓库（GPU 内核 / PyTorch 绑定） |
| `~/data/test/` | 临时实验输出目录 |
| `~/data/exp/` | 持久化实验输出目录 |

`compass-app-jasper/core/` 和 `compass-app-jasper/lib2/` 是 submodule，分别对应 `compass-core` 和 `fenghe-nn`。

---

## 子模块联合开发规范

### 正常功能开发流程

1. 在源仓库（`~/data/compass-core` 或 `~/data/fenghe-nn`）开发、提交、推送
2. 在主仓库更新 submodule 指针：

   ```bash
   cd ~/data/compass-app-jasper/core   # 或 lib2/
   git checkout <新 commit hash 或分支>
   cd ~/data/compass-app-jasper
   git add core lib2
   git commit -m "update submodule: ..."
   ```

**禁止在 jasper 的 `core/` 或 `lib2/` 子目录下直接提交功能修改。**

### Debug / 临时修改

- 可以在 `compass-app-jasper/core/` 或 `compass-app-jasper/lib2/` 内直接改代码
- **禁止将这类修改 push 到远程**
- 若验证有效，须回到源仓库重新提交，再走正常流程更新指针

---

## compass-core 关键命令

```bash
cd ~/data/compass-core
CUBLAS_WORKSPACE_CONFIG=:4096:8 python -m pytest test/
```

主分支：`develop`；feature 分支格式：`<issue-number>-<description>`。

---

## fenghe-nn 关键命令

```bash
cd ~/data/fenghe-nn/python
pip install -e .   # 安装（含 C++ 扩展编译）
pytest test/
```

Python 包名为 `finai`，import 路径 `from fenghe.xxx import ...`。主分支：`develop`。

---

## compass-app-jasper 关键命令

**机器相关配置**（conda 环境名、数据路径）以 `.claude/session-context.sh` 为准，执行前先读取确认，不要硬编码。

`session-context.sh` 和 `settings.local.json` 均不纳入版本控制，**每台机器需自行创建**：
- `session-context.sh`：定义 `CONDA_ENV`、`DATA_HK`、`DATA_JP` 等变量
- `settings.local.json`：配置 SessionStart hook 以自动执行 `session-context.sh`（参考模板见下方）

```json
{
  "hooks": {
    "SessionStart": [
      {"hooks": [{"type": "command", "command": "bash /home/peiran/data/my-claude-code/.claude/session-context.sh"}]}
    ]
  }
}
```

```bash
# 激活环境（每 session 一次）
conda activate $CONDA_ENV
export PYTHONNOUSERSITE=1
export PYTHONPATH="$HOME/data/compass-app-jasper/app2:$HOME/data/compass-app-jasper/core:$HOME/data/compass-app-jasper/lib:$HOME/data/compass-app-jasper/lib2"

# 运行测试（unittest，禁止 pytest）
cd ~/data/compass-app-jasper
PYTHONSAFEPATH=1 PYTHONPATH=$PWD/core:$PWD/app2:$PWD/lib:$PWD/lib2/python \
  conda run -n $CONDA_ENV python -m unittest discover -s test/app2/data -v

# 运行实验（必须通过 run.sh，禁止直接调用子 Makefile）
# 临时验证 → test/；持久化 → exp/；先创建 description.md
mkdir -p ~/data/test/<exp-dir>
cp ~/data/run_exp/run.sh ~/data/test/<exp-dir>/
cd ~/data/test/<exp-dir>
bash run.sh \
  DATA_SOURCE_PATH=$DATA_JP \
  BACKTEST=latest SEEDS="seed-00" \
  OVERRIDE="schema_file_path=conf/schema_files/mini.yaml train/execution=small train/executor=bold" \
  > run.log 2>&1 &

# 停止实验
kill -- -$(ps -o pgid= -p <PID> | tr -d ' ')

# TensorBoard
conda run -n $CONDA_ENV tensorboard --logdir ~/data/exp --port 6006 --bind_all
```

新工作一律用 `app2/`，`app/` 是旧版 v3（默认数据源见 `.claude/session-context.sh`）。

### 实验目录文档规范

每个实验目录下必须维护：

**`description.md`**（创建或重启实验时更新）：
```markdown
# <实验名>

**目的**：
**分支**：
**关键参数**：
**预期验证**：
```

**`design.md`**（涉及代码设计或超参讨论时维护）：记录设计方案、分析过程和 Q&A，跨 session 开发时优先阅读此文件恢复上下文。

---

## Git 操作规范

执行任何 git 命令前，必须明确目标仓库。如果用户指令中没有明确说明是哪个仓库，**先询问，不得静默执行**。

涉及的仓库：`my-claude-code` / `compass-app-jasper` / `compass-core` / `fenghe-nn`

---

## 注意事项

- **jasper 测试用 `unittest`**，compass-core 用 `pytest`，两个仓库不要混用
- **切换 jasper 分支会影响后台运行的实验**；多分支同时跑需使用不同仓库目录
- submodule 在 jasper 中是 detached HEAD 状态，`git checkout` 到具体 commit 才生效
- `fenghe` 是命名空间包，`lib/fenghe/` 和 `lib2/python/fenghe/` 合并；unittest 不执行 conftest，需手动在 PYTHONPATH 包含两个路径
- 重复运行实验时保留 `description.md`，只删实验产物（`train/`、`merged/`、`outputs/`、`run.log`、`windows/`）
- **分析实验前必须先读 `compass-app-jasper/app2/README.md`**，了解输出目录层级，不可对目录结构做假设
- OVERRIDE 中每个参数必须确认存在于 `conf/` 下的 yaml，且必须用完整 Hydra 路径（如 `backtest.window_generator.size=2000`，不能写 `window_generator.size=2000`）
- seed 覆盖用 `seed=seed-01`，**不能**用 `+seed=seed-01`（会报重复 key 错误）
