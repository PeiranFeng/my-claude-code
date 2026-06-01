# CLAUDE.md

## 关于本文件

只写"看代码看不出来但必须知道"的内容。**禁止信息重复**——同一事实只在一处出现，其他地方引用或省略，避免修改时出现不一致。

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
