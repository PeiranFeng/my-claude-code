# CLAUDE.md

## 写作规约

只写"看代码看不出来但必须知道"的内容。**禁止信息重复**——同一事实只在一处出现，其他地方引用或省略，避免修改时出现不一致。

**信息来源优先级**（适用于 CLAUDE.md 和 skill 文件）：仓库代码 > CLAUDE.md > skill/markdown 文件。当某个信息在更高优先级的来源中已存在，只记录引用位置（如"见 CLAUDE.md"、"见 conf/ 下的 yaml"），不重复写内容。

**工作原则的编号是稳定引用**：原则采用 `分组-条目` 二级编号（如 `1-2`）。分组编号（`0`–`11`）和各分组内的条目编号均为稳定标识，原则之间通过此编号互相引用。修改时禁止改动已有编号；新增条目只能在对应分组末尾追加，新增分组只能在末尾追加；废弃某条时保留编号并标注作废，不得重排或回填。

**CLAUDE.md 只记录普适原则，禁止使用具体例子作补充说明**：例子过短则不够精确，上下文切换后无法提供有效信息；例子过长则污染上下文，使 CLAUDE.md 本身臃肿。

---

## 工作原则

### 0. 第一性原理

**优先完成用户要求的任务**，全程守住首要目标、禁止偏离；只实现和用户确认过的方案，禁止书写任何未确认的方案。这是最高准则，下列各条是它在具体情形下的展开。

---

### 1. 任务执行与范围控制

**1-1. 优先完成任务本身**：不被路上发现的"有趣问题"带偏。例如跑实验时发现的 warning、代码风格问题、其他分支的 bug，都不属于当前任务，不去管。

**1-2. 越界问题只反馈，不深挖**：遇到非当前分支或超出需求范围的问题时，一句话报告给用户（"发现 X，可能有问题，是否需要处理？"）然后停下，由用户决定是否扩大范围，不自行展开调查。

**1-3. 避免无效推理陷阱**：没有证据不猜测根因；不对目录结构、配置含义做假设并基于假设继续推理；任务卡住时回报用户，而不是换方向"自行研究"。一句话总结：**遇到边界就停下问用户，而不是替用户做决定继续走**。

**1-4. 讨论锚定首要目标**：接到指令或讨论开始时，先用一句话明确并复述首要目标作为锚点；之后每冒出一个新方案或新问题，都先一句话复述当前锚点再继续。新方案/问题必须拿回锚点称重——先判断它是否真的改变结论，不能因为某个观点本身正确就接受它、让它覆盖既有结论（**正确 ≠ 决定性**）。讨论须收敛到三者之一方可结束：① 首要目标达成；② 首要目标不成立；③ 取得明确折中。

---

### 2. 代码质量

**2-1. 不修改无关格式**：修改代码时，不改动需求范围之外的缩进、换行、空格等格式，保持原有代码风格不变。

**2-2. 代码检查要悲观，没有调查没有发言权**：评估代码（review 建议、判断某问题"已修复"或"非 bug"）时默认悲观——假定可能仍有问题，而不是乐观假定没事。下"已修复/非 bug/不受影响"这类结论前，必须先**实地调查验证**（实际运行、写最小复现、追代码与配置链路），不得仅凭 commit message、他人描述或纯推理就下结论。结论必须有调查证据支撑。

**2-3. 有现成工具时禁止自己实现**：执行命令或开发代码时，如果已有现成的库函数、CLI 工具或框架 API 能完成任务，禁止自己手写等价实现。

**2-4. 名实一致**：变量/方法/类的命名、注释必须与实际行为相符——名字声称的语义、注释描述的行为，必须能对应到代码的真实行为，不得名实错位。

**2-5. 禁止隐含魔法值混入输出**：禁止把魔法值混入正常取值区间的输出数据中充当特殊语义。此类语义应拆成独立、显式的字段表达。

---

### 3. Tensor 与 GPU

**3-1. 禁止在 tensor 创建时手动指定 `device=`**：项目通过 `try_to_use_gpu()` 统一设置默认 device（见注意事项），手动指定反而会造成与全局设置不一致的风险。code review 时不应以缺少 `device=` 为由提修改建议。

**3-2. tensor 对象必须用 torch 提供的方法处理**：禁止用 `.tolist()`、`.numpy()` 等方式将 tensor 转换为 Python 原生格式后再处理；所有 tensor 操作应保持在 torch 的 API 体系内完成。

**3-3. tensor 功能的测试必须运行在 GPU 上**：涉及 tensor 计算的测试，必须在有 GPU 的环境中执行，不得仅在 CPU 上通过即视为合格。

---

### 4. 算法设计

**4-1. 关注数据特性，选择匹配的算法**：处理数据前，先明确数据的已知约束——是否有序、是否去重、值域范围（非负、整数、浮点）、稀疏程度等。算法选择应依据这些约束，而非忽略它们选用"通用但保守"的方案。有序数据用二分查找而非线性扫描，去重数据跳过额外去重步骤，整数范围有限时考虑直接索引。利用已有约束是降低复杂度的第一步，忽略约束是性能浪费的常见根源。

**4-2. 算法依赖的数据特性必须有明确保障**：当算法依赖数据的某项特性时，必须对该特性做出保障，方式按强制程度从高到低分三级：**验证**（assert/运行时检查，能主动拦截违反约束的输入）、**假设**（文档或类型注释中声明前提，调用方有义务保证）、**注释**（代码注释说明依赖关系，提示维护者）。三者开销与强度相反。设计时应综合考虑性能敏感度与出错代价：热路径上的已知不变量用注释或假设，外部输入或难以保证的前提用验证。

---

### 5. OOP 设计

**5-1. 方法的输出应满足正交性**：把方法返回的一组输出量看作对若干份"独立信息"的编码。正交即每个输出量恰好对应一份独立信息、彼此不交叠。要同时满足两个互为对偶的方向：
- **不重复**：同一份信息不能由多个输出量承载——任何一个输出量都不应能由其它输出量推导得出。重复或可推导的量应删除，由使用方按需自行计算。
- **不混合**：单个输出量不能把多份本可分开的独立信息糅合在一起——一个输出量只编码一份信息。糅合的量应拆成各自独立的输出，由使用方按需自行组合。
- **为何要正交**：正交的输出是一组最小且完备的"基"——无冗余（同一份数据不在多处重复存储/传输/计算，改一处不必同步多处，不会出现不一致）；每个量语义单一，可被独立取用、自由组合；任何派生量都能由这组基唯一地组合得到。非正交的输出会迫使使用方接受捆绑、在多处维护同一份信息，是冗余与不一致的根源。

**5-2. 对象的所有权与生命周期必须一致**：谁创建，谁负责销毁。若某对象的生命周期与类实例完全绑定，两者应为组合关系，在 `__init__` 中创建并持有；若某对象的销毁时机由外部决定，则类不拥有其所有权，不应在 `__init__` 中创建并存为成员变量，而应以引用形式注入（构造参数或方法参数），两者为聚合关系。违反此规则会导致隐式的所有权混乱：类表面上持有对象，实际上无法控制其生命周期。

**5-3. Tell, Don't Ask**：不要先读取对象的状态、再在外部做判断和决策——这是在把对象内部的职责泄露到外部。应直接告诉对象去做某件事，将判断逻辑封装在对象自身的方法内。违反时的典型症状：调用方大量读取对象字段后自行分支判断，而这些判断逻辑本应属于对象的行为。

**5-4. 迪米特法则（Law of Demeter）**：一个方法只与直接依赖交互——自身、自身成员变量、方法参数、方法内创建的对象。禁止越过直接依赖、访问其内部成员或更深层的嵌套结构。这类穿透访问意味着调用方对中间层的内部结构有隐式了解，中间层任何变动都会向外传播；应由中间层自己暴露所需方法，将内部结构封装在接口之后。

**5-5. 变换操作应满足封闭性（closure property）**：对领域对象的变换操作（filter、slice、transform 等）应返回与输入相同的类型，保持类型封闭，使操作可任意组合。违反时的典型症状：变换方法返回裸底层类型，调用方必须手动重新包装才能继续使用领域对象的接口。终结操作（从对象中提取标量、聚合值等）不受此约束，返回不同类型是正确的。

---

### 6. 测试

**6-1. 编写测试用例的覆盖标准**：根据被测方法的复杂度选择覆盖标准。
- **逻辑复杂的方法**（参数含复杂类型对象、存在多个独立逻辑层、调用链较深）：满足 **100% 分支覆盖**——① 每个 `if` 语句的 True 和 False 分支各有一个用例；② 每条 `raise` 语句有一个直接触发它的用例；③ 每条正常返回路径（不经过任何 `raise`）有一个用例。
- **逻辑简单但对计算精度或安全性要求高的方法**（数值运算、边界判断、鉴权校验）：满足 **MC/DC**（DO-178C 标准）——每个布尔子条件能独立影响最终判定结果，即固定其他条件时，单独翻转该条件能改变判定输出。
- 两条规则可叠加：逻辑复杂且精度要求高的方法，同时满足两者。

---

### 7. Git 与远程操作

**7-1. `git push` 前的检查范围**：在任一仓库执行 `git push` 前，逐项核对本次改动是否触及以下范围；触及则先与用户确认或处理，未处理的项在每次 `git push` 前都要再问一次。
- **公开接口变更**（函数签名、参数名、返回值结构、事件格式等）：主动提醒用户检查并更新对应的测试用例，不得默认测试用例会自动跟进。
- **实验产物结构变更**（实验输出目录结构、文件名、文件含义变化）：与 `app2/README.md` 的输出结构描述比对，询问用户是否立即更新 README。

**7-2. 影响远程的操作必须经用户明确确认**：所有对远程产生外部影响的操作——`git push`、`gh` 发评论 / issue / PR、合并 PR、删除远程分支等——一律需用户明确指示后才执行，禁止自动执行或顺手执行。`git push` 前还需按 7-1 核对改动。对于携带内容的远程操作（评论、PR 描述、issue 正文等），执行前必须先将完整内容展示给用户确认，不得在未经内容确认的情况下直接发送。

---

### 8. 代码 Review

**8-1. 代码 review 必查项**：无论审查本地改动还是远程 PR，都必须逐项核对以下内容：
- **① README 同步**：是否需要同步更新（范围见 7-1）。
- **② 测试覆盖**：测试用例是否覆盖本次改动（覆盖标准见 6-1）。
- **③ 名实一致**：命名与注释是否与实际行为相符（见 2-4）。
- **④ 不重复造轮子**：含 tensor 的代码有没有用手写逻辑替代 torch 已有方法（见 3-2、2-3）。
- **⑤ 隐含前提有 guard**：代码是否依赖了某项未被保障的隐含前提（见 4-2）。
- **⑥ 禁止隐含魔法值混入输出**：输出数据中是否混入魔法值充当特殊语义（见 2-5）。
- **⑦ 输出正交性**：方法返回的多个输出量是否满足正交（见 5-1）。
- **⑧ Tell, Don't Ask**：有无在外部读取对象状态后自行判断、本该由对象自身封装的逻辑（见 5-3）。

---

### 9. 项目专用规则

**9-1. 不在代码仓库内跑实验/测试**：实验和测试一律在独立输出目录（如 `test/`、`exp/`）运行，禁止在仓库目录内直接运行——Hydra 等会生成 `outputs/`、`train/`、`merged/` 等产物污染仓库代码。运行前确认工作目录在仓库之外。

**9-2. 禁止自动写入 memory 文件**：不得在未经用户明确要求的情况下自动写入 `~/.claude/projects/*/memory/` 下的任何文件，包括 MEMORY.md 及各类记忆文件。

**9-3. 禁止自己编写 Python 程序**：不得通过任何方式（内联 bash 执行、写入 .py 文件再执行等）自行编写 Python 脚本来完成任务。应使用已有 CLI 工具、bash 命令或 Claude Code 内置工具（Read/Write/Edit/Bash）。唯一例外：读取 parquet 文件时，可以用 `python -c "..."` 内联或写入临时 `.py` 文件，但临时文件用完后必须立即删除。

**9-4. 后台进程监控：用 Monitor 工具 + until 循环，退出条件必须包含进程存活检查**：**训练实验启动后必须立即用此模板监控，禁止用 `tail -f`、`grep` 日志或 Bash 裸 sleep 轮询。** 等待后台进程完成时，使用 Monitor 工具执行 until 循环（Claude Code 官方规范）。
- **退出条件**：必须同时覆盖"成功完成"和"进程已死"两种情况，不能只依赖 log 内容匹配——进程被 OOM kill、信号终止时不会写入 log，单靠 log 匹配会永远不退出。标准模板：`until [ -f <完成标志文件> ] || ! kill -0 <PID> 2>/dev/null; do sleep 5; done`。
- **`sleep` 的边界**：被禁止的是在 Bash 工具内裸跑 `sleep` 轮询（前台 `sleep` 会被 harness block）；模板里的 `sleep 5` 是 until 循环体的一部分、由 Monitor 工具执行，属于允许范围。两者区别在于"由谁执行"，不是"能否出现 sleep"。

**9-5. `~/data/issue/` 和 `~/data/pr/` 仅在用户主动提出时才可访问**：未经用户明确要求，禁止以任何方式（Read、Edit、Write、Bash 等）访问这两个目录下的文件。需要 PR / issue 内容时，直接通过 `gh` 命令从远程 GitHub 获取，不得自行读取本地文件作为决策依据。

**9-6. Hydra 管理的工作必须通过 `app2/conf/` 配置，禁止硬编码**：凡是由 Hydra 负责的工作（实例化、超参设置等），其配置一律在 `app2/conf/` 下对应的 config group 中书写，禁止将这些工作硬编码到代码中。当需要新增配置项而对应配置文件不存在时，先询问用户该配置应如何增加，不得自行在代码里绕过 Hydra 的配置体系。

---

### 10. 沟通与交互

**10-1. 每次回复开头用用户名称呼用户**：每个 session 第一次回复前执行一次 `whoami` 获取 Linux 用户名，将结果保存在本次会话上下文中，之后每次回复开头以该用户名称呼用户（如"peiran，……"），不需要每次重新执行命令。

**10-2. 回复 PR comment 的规范**：回复须简短明确。已按意见修改的，回复"Agreed, fixed."；不认可的，回复"Not an issue."并一句话说明原因。回复位置必须与 comment 类型一致：inline comment 须在对应 inline comment 下回复，top-level comment 须在 top-level 下回复，禁止错位。

**10-3. 回复中的引用必须自明**：不使用需要读者查找外部来源才能理解的指针——包括裸原则编号、缩写、代词等。每个引用在当前句子中给出足够上下文，使读者无需跳出当前回复即可理解。

---

### 11. 描述代码行为

适用于主动解释、review 记录、skill 输出等一切需要描述代码做了什么的场景。

**11-1. 禁止裸名词**：引用变量名、方法名、类名时，必须附有能让读者定位该名称的上下文；裸名称单独出现，读者无法判断它属于哪里、是什么。

**11-2. 解释的最小单元是类/模块**：解释某个方法、代码段或变量前，先判断上下文中是否已介绍过它所在的类/模块。若未介绍，先说明该类/模块：封装了什么数据、提供什么行为、对数据有什么约束。然后说明具体方法/变量在整个类/模块中的定位和作用，再进入解释本身。

**11-3. "是什么"与"为什么"分开回答**：是什么 = 操作和结果；为什么 = 目的。不混。

**11-4. 每个描述词对应代码里的具体一行**：对应不上就是比喻，换掉。

**11-5. 外部工具默认未知**：数学概念、PyTorch/Triton/CUDA 等框架知识不假定读者已知；已出现在 `deep-dive/base-line/` 的概念视为已知基线，其余一律解释或明确标注"假定读者已掌握"。

**11-6. 解释外部工具后更新 base-line**：用户明确表示不理解某个外部工具或数学概念，且该概念不在 `deep-dive/base-line/` 中时，解释后在对应文件（`math.md`、`pytorch.md`、`triton.md`、`cuda.md`）末尾追加该概念，格式包含接口签名（如适用）、定义说明、`Last mentioned` 日期。`base-line/` 只追加，不删改已有条目。

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

**机器相关配置**（conda 环境名等）以 `session-context.sh` 为准（路径见下方 SessionStart hook 模板），执行前先读取确认，不要硬编码。

`session-context.sh` 和 `settings.local.json` 均不纳入版本控制，**每台机器需自行创建**：
- `session-context.sh`：定义 `CONDA_ENV` 等变量
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

### GitHub Actions 实验产物

GitHub Actions 触发的实验，实际运行的代码与本地一样来自 compass-app-jasper 仓库，输出目录结构与本地实验（`~/data/test`、`~/data/exp`）大同小异，差异仅在所跑的分支不同。

最终产物同步到 `/output/` 下。批次目录默认为当月（如 `2026-05`），也可能特殊指定。目录内每个实验的命名格式为 `<branch>-<run-id>-<job>`。查找某个 run-id 的实验时，若当月目录不存在或找不到对应条目，可能是产物尚未同步，而非实验未运行。

**当前机器是否受 k8s 调度，以 `kubectl get po` 能否执行为准：**

- **能执行** → 当前机器接收 k8s 调度，可直接观察运行中的实验：
  - **找实验**：`kubectl get po` 列出所有 pod，pod 名即「实验名（与 git action 一致，含 run-id）+ k8s 随机后缀」；`STATUS` 为 `Running` 表示进行中，`Completed` 表示已结束。
  - **从 Actions run 链接对齐 pod**：pod 名（及 `/output` 产物名）里的 `<run-id>` 是 Actions 的 **run number**（页面显示为 `#N`）。用 `gh run list --repo <repo> --branch <branch> --json number,databaseId` 取 `number` 字段，对齐到 pod 名前缀 `<branch>-<number>-<job>`。
  - **看日志/中间产物**：实验在 pod 内的工作目录是 `/tmp/runner`（**不是** `/output`），实时日志 `kubectl exec <pod> -- tail -f /tmp/runner/output.log`。`/tmp/runner` 内的输出目录层级随分支而异，需要时以对应分支的代码（makefile）为准，不做假设。
  - **同步到 /output 的时机**：运行期间 `/output` 为空；实验全部窗口完成后，由 `rclone-output-*` pod 将 `/tmp/runner` 的结果 rclone 同步到 `/output/<批次>/`。
- **不能执行** → 当前机器不受 k8s 调度，无法观察运行中实验的状态，只能被动等结果同步到 `/output` 后再分析。

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
