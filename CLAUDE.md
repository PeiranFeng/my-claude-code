# CLAUDE.md

## 写作规约

只写"看代码看不出来但必须知道"的内容。**禁止信息重复**——同一事实只在一处出现，其他地方引用或省略，避免修改时出现不一致。

**信息来源优先级**（适用于 CLAUDE.md 和 skill 文件）：仓库代码 > CLAUDE.md > skill/markdown 文件。当某个信息在更高优先级的来源中已存在，只记录引用位置（如"见 CLAUDE.md"、"见 conf/ 下的 yaml"），不重复写内容。

**工作原则的编号是稳定引用**：原则之间通过编号互相引用，编号是稳定标识。修改时禁止改动已有原则的编号，新增原则只能在末尾追加；废弃某条原则时保留其编号、标注作废，不得重排或回填。

---

## 工作原则

**第一性原理**：优先完成用户要求的任务。遇到非当前分支或非用户需求范围的问题时，反馈给用户，**禁止自行研究**，避免陷入无效的推理陷阱。**应该永远实现和用户确认过的方案，禁止书写任何未确认的方案。**

1. **优先完成任务本身**：不被路上发现的"有趣问题"带偏。例如跑实验时发现的 warning、代码风格问题、其他分支的 bug，都不属于当前任务，不去管。
2. **越界问题只反馈，不深挖**：遇到非当前分支或超出需求范围的问题时，一句话报告给用户（"发现 X，可能有问题，是否需要处理？"）然后停下，由用户决定是否扩大范围，不自行展开调查。
3. **避免无效推理陷阱**：没有证据不猜测根因；不对目录结构、配置含义做假设并基于假设继续推理；任务卡住时回报用户，而不是换方向"自行研究"。一句话总结：**遇到边界就停下问用户，而不是替用户做决定继续走**。
4. **不修改无关格式**：修改代码时，不改动需求范围之外的缩进、换行、空格等格式，保持原有代码风格不变。
5. **代码检查要悲观，没有调查没有发言权**：评估代码（review 建议、判断某问题"已修复"或"非 bug"）时默认悲观——假定可能仍有问题，而不是乐观假定没事。下"已修复/非 bug/不受影响"这类结论前，必须先**实地调查验证**（实际运行、写最小复现、追代码与配置链路），不得仅凭 commit message、他人描述或纯推理就下结论。结论必须有调查证据支撑。
6. **禁止在 tensor 创建时手动指定 `device=`**：项目通过 `try_to_use_gpu()` 统一设置默认 device（见注意事项），手动指定反而会造成与全局设置不一致的风险。code review 时不应以缺少 `device=` 为由提修改建议。
7. **不在代码仓库内跑实验/测试**：实验和测试一律在独立输出目录（如 `test/`、`exp/`）运行，禁止在仓库目录内直接运行——Hydra 等会生成 `outputs/`、`train/`、`merged/` 等产物污染仓库代码。运行前确认工作目录在仓库之外。
8. **tensor 功能的测试必须运行在 GPU 上**：涉及 tensor 计算的测试，必须在有 GPU 的环境中执行，不得仅在 CPU 上通过即视为合格。
9. **tensor 对象必须用 torch 提供的方法处理**：禁止用 `.tolist()`、`.numpy()` 等方式将 tensor 转换为 Python 原生格式后再处理；所有 tensor 操作应保持在 torch 的 API 体系内完成。
10. **有现成工具时禁止自己实现**：执行命令或开发代码时，如果已有现成的库函数、CLI 工具或框架 API 能完成任务，禁止自己手写等价实现。
11. **关注数据特性，选择匹配的算法**：处理数据前，先明确数据的已知约束——是否有序、是否去重、值域范围（非负、整数、浮点）、稀疏程度等。算法选择应依据这些约束，而非忽略它们选用"通用但保守"的方案。有序数据用二分查找而非线性扫描，去重数据跳过额外去重步骤，整数范围有限时考虑直接索引。利用已有约束是降低复杂度的第一步，忽略约束是性能浪费的常见根源。
12. **算法依赖的数据特性必须有明确保障**：当算法依赖数据的某项特性时，必须对该特性做出保障，方式按强制程度从高到低分三级：**验证**（assert/运行时检查，能主动拦截违反约束的输入）、**假设**（文档或类型注释中声明前提，调用方有义务保证）、**注释**（代码注释说明依赖关系，提示维护者）。三者开销与强度相反。设计时应综合考虑性能敏感度与出错代价：热路径上的已知不变量用注释或假设，外部输入或难以保证的前提用验证。
13. **禁止自动写入 memory 文件**：不得在未经用户明确要求的情况下自动写入 `~/.claude/projects/*/memory/` 下的任何文件，包括 MEMORY.md 及各类记忆文件。
14. **禁止自己编写 Python 程序**：不得通过任何方式（内联 bash 执行、写入 .py 文件再执行等）自行编写 Python 脚本来完成任务。应使用已有 CLI 工具、bash 命令或 Claude Code 内置工具（Read/Write/Edit/Bash）。
15. **每次回复开头用用户名称呼用户**：每个 session 第一次回复前执行一次 `whoami` 获取 Linux 用户名，将结果保存在本次会话上下文中，之后每次回复开头以该用户名称呼用户（如"peiran，……"），不需要每次重新执行命令。
16. **后台进程监控：用 Monitor 工具 + until 循环，退出条件必须包含进程存活检查**：**训练实验启动后必须立即用此模板监控，禁止用 `tail -f`、`grep` 日志或 Bash 裸 sleep 轮询。** 等待后台进程完成时，使用 Monitor 工具执行 until 循环（Claude Code 官方规范）。
    - **退出条件**：必须同时覆盖"成功完成"和"进程已死"两种情况，不能只依赖 log 内容匹配——进程被 OOM kill、信号终止时不会写入 log，单靠 log 匹配会永远不退出。标准模板：`until [ -f <完成标志文件> ] || ! kill -0 <PID> 2>/dev/null; do sleep 5; done`。
    - **`sleep` 的边界**：被禁止的是在 Bash 工具内裸跑 `sleep` 轮询（前台 `sleep` 会被 harness block）；模板里的 `sleep 5` 是 until 循环体的一部分、由 Monitor 工具执行，属于允许范围。两者区别在于"由谁执行"，不是"能否出现 sleep"。
17. **编写测试用例的覆盖标准**：根据被测方法的复杂度选择覆盖标准。
    - **逻辑复杂的方法**（参数含复杂类型对象、存在多个独立逻辑层、调用链较深）：满足 **100% 分支覆盖**——① 每个 `if` 语句的 True 和 False 分支各有一个用例；② 每条 `raise` 语句有一个直接触发它的用例；③ 每条正常返回路径（不经过任何 `raise`）有一个用例。
    - **逻辑简单但对计算精度或安全性要求高的方法**（数值运算、边界判断、鉴权校验）：满足 **MC/DC**（DO-178C 标准）——每个布尔子条件能独立影响最终判定结果，即固定其他条件时，单独翻转该条件能改变判定输出。
    - 两条规则可叠加：逻辑复杂且精度要求高的方法，同时满足两者。
18. **`git push` 前的检查范围**：在任一仓库执行 `git push` 前，逐项核对本次改动是否触及以下范围；触及则先与用户确认或处理，未处理的项在每次 `git push` 前都要再问一次。
    - **公开接口变更**（函数签名、参数名、返回值结构、事件格式等）：主动提醒用户检查并更新对应的测试用例，不得默认测试用例会自动跟进。
    - **实验产物结构变更**（实验输出目录结构、文件名、文件含义变化）：与 `app2/README.md` 的输出结构描述比对，询问用户是否立即更新 README。
19. **解释代码时的方法论**：
    - **固定知识基线，从基线内出发解释**：先确定读者已知什么（如基本数据结构），之后出现的每个概念必须用基线内已有的词定义，不能用另一个同样超出基线的词解释。
    - **区分"是什么"和"为什么"，分开回答**："是什么"是机械描述（对哪个数据做了什么操作，结果是什么）；"为什么"是目的（解决了什么问题，训练时起什么作用）。两个问题混在一起会让读者两个都没明白。
    - **用词要可验证，不用听起来有意义但无法对应到代码的词**：替换标准是——换成这个描述后，读者能判断代码里哪行对应这个描述。能对应上，词就是准确的；对应不上，就是在用比喻代替解释。
20. **影响远程的操作必须经用户明确确认**：所有对远程产生外部影响的操作——`git push`、`gh` 发评论 / issue / PR、合并 PR、删除远程分支等——一律需用户明确指示后才执行，禁止自动执行或顺手执行。`git push` 前还需按"`git push` 前的检查范围"原则核对改动。对于携带内容的远程操作（评论、PR 描述、issue 正文等），执行前必须先将完整内容展示给用户确认，不得在未经内容确认的情况下直接发送。
21. **代码 review 必查项**：无论审查本地改动还是远程 PR，都必须逐项核对以下内容：
    - **① README 同步**：是否需要同步更新（范围见原则 18）。
    - **② 测试覆盖**：测试用例是否覆盖本次改动（覆盖标准见原则 17）。
    - **③ 名实一致**：命名与注释是否与实际行为相符（见原则 23）。
    - **④ 不重复造轮子**：含 tensor 的代码有没有用手写逻辑替代 torch 已有方法（见原则 9、原则 10）。
    - **⑤ 隐含前提有 guard**：代码是否依赖了某项未被保障的隐含前提（见原则 12）。
    - **⑥ 禁止隐含魔法值混入输出**：输出数据中是否混入魔法值充当特殊语义（见原则 24）。
    - **⑦ 输出正交性**：方法返回的多个输出量是否满足正交（见原则 22）。

22. **方法的输出应满足正交性**：把方法返回的一组输出量看作对若干份"独立信息"的编码。正交即每个输出量恰好对应一份独立信息、彼此不交叠。要同时满足两个互为对偶的方向：
    - **不重复**：同一份信息不能由多个输出量承载——任何一个输出量都不应能由其它输出量推导得出。重复或可推导的量应删除，由使用方按需自行计算。
    - **不混合**：单个输出量不能把多份本可分开的独立信息糅合在一起——一个输出量只编码一份信息。糅合的量应拆成各自独立的输出，由使用方按需自行组合。
    - **为何要正交**：正交的输出是一组最小且完备的"基"——无冗余（同一份数据不在多处重复存储/传输/计算，改一处不必同步多处，不会出现不一致）；每个量语义单一，可被独立取用、自由组合；任何派生量都能由这组基唯一地组合得到。非正交的输出会迫使使用方接受捆绑、在多处维护同一份信息，是冗余与不一致的根源。

23. **名实一致**：变量/方法/类的命名、注释必须与实际行为相符——名字声称的语义、注释描述的行为，必须能对应到代码的真实行为，不得名实错位。

24. **禁止隐含魔法值混入输出**：禁止把魔法值混入正常取值区间的输出数据中充当特殊语义。此类语义应拆成独立、显式的字段表达。

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

**机器相关配置**（conda 环境名、数据路径）以 `session-context.sh` 为准（路径见下方 SessionStart hook 模板），执行前先读取确认，不要硬编码。

`session-context.sh` 和 `settings.local.json` 均不纳入版本控制，**每台机器需自行创建**：
- `session-context.sh`：定义 `CONDA_ENV`、`DATA_HK`、`DATA_JP` 等变量，路径与 SessionStart hook 中配置的一致
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
# CONFIG_NAME、DATA_SOURCE_PATH、BACKTEST、SEEDS、OVERRIDE 参数选择一律参见 app2/README.md
# 临时验证 → test/；持久化 → exp/；先创建 description.md
mkdir -p ~/data/test/<exp-dir>
cp ~/data/run_exp/run.sh ~/data/test/<exp-dir>/
cd ~/data/test/<exp-dir>
bash run.sh [参见 README] > run.log 2>&1 &

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

合并不同分支时，**必须使用 `git merge`，禁止使用 `git rebase`**。rebase 会改写提交历史，在多人协作分支上会造成混乱。

切换分支前，**必须先执行 `git fetch origin`**，确保本地看到的远程分支状态是最新的。

---

## 注意事项

- **jasper 测试用 `unittest`**，compass-core 用 `pytest`，两个仓库不要混用
- **切换 jasper 分支会影响后台运行的实验**；多分支同时跑需使用不同仓库目录
- submodule 在 jasper 中是 detached HEAD 状态，`git checkout` 到具体 commit 才生效
- `fenghe` 是命名空间包，`lib/fenghe/` 和 `lib2/python/fenghe/` 合并；unittest 不执行 conftest，需手动在 PYTHONPATH 包含两个路径
- 重复运行实验时保留 `description.md`，只删实验产物（`train/`、`merged/`、`outputs/`、`run.log`、`windows/`）
- **运行或分析实验前必须先读 `compass-app-jasper/app2/README.md`**：运行时参照 README 选择 CONFIG_NAME、DATA_SOURCE_PATH 及其他参数；分析时参照 README 了解输出目录层级，不可对目录结构做假设
- OVERRIDE 中每个参数必须确认存在于 `conf/` 下的 yaml，且必须用完整 Hydra 路径（如 `backtest.window_generator.size=2000`，不能写 `window_generator.size=2000`）
- seed 覆盖用 `seed=seed-01`，**不能**用 `+seed=seed-01`（会报重复 key 错误）
- **PyTorch tensor 默认 device 由 `try_to_use_gpu()` 统一设置**（`core/lib/utility/device.py:16`），在训练入口 `app2/train.py` 最顶部调用后，所有 `torch.tensor()`、`torch.arange()` 等创建操作自动使用 GPU device，无需每次显式传 `device=` 参数。
