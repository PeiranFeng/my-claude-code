---
allowed_tools: Bash, Read, Edit, Write
---

# /auto-implement — 自治实现循环

基于 design.md 和 test_case.md 自治完成实现、测试、实验验证的完整循环。

---

## 第零步：前置检查（全部通过才能继续，否则立即中止并说明原因）

### 文件完备性

在当前 git branch 对应的实验目录（`~/data/test/` 或 `~/data/exp/` 下）中：

1. `design.md` 存在且唯一，内容不含 `TODO`、`TBD`、`待完成`、`待实现`、`待讨论`、`暂定`、`[...]`、空节（只有标题无内容）
2. `test_case.md` 存在且唯一，内容同样完备

### design.md 可落地性检查

逐一核查 design.md 中声明的每个接口，**必须同时满足**：
- **签名完整**：方法名、所有参数名、参数类型、返回类型均已声明
- **输入输出约束明确**：tensor shape、对象类型、合法值范围有明确说明
- **实现方案具体**：有伪代码、算法步骤、或足以推导出唯一实现的描述——仅有"计算 X"而没有说明如何计算不算具体

**若任何接口不满足**：中止，在 code-log 中记录具体缺失项，告知用户："design.md 中 [接口名] 缺少 [具体内容]，无法落地实现，请修改 design.md 或重新执行 /design-mode。"

不得自行补全或假设 design.md 未说明的设计方案。

---

## 工具使用约束（最高优先级）

**只允许使用以下工具，禁止使用 Agent 子代理：**
- `Read`：读取文件
- `Edit` / `Write`：修改或创建文件
- `Bash`：运行 shell 命令（测试、git、查找文件等）

**绝对禁止**：
- 使用 `Agent` 工具（任何子代理类型）——会触发用户确认，破坏自治性
- 修改 git 远端（push、force push 等）
- 删除或覆盖 design.md / test_case.md / description.md
- 运行消耗大量 GPU 的训练任务（只允许第三步指定的实验命令）

---

## 执行规则（贯穿整个循环）

- **只改 design.md 中涉及的文件和接口**，不触碰其他任何代码
- **不因格式、空格、命名风格等原因修改已有代码**，即使看起来不规范
- **每次 Write/Edit 工具调用后**，立即将以下内容追加到 code-log：
  ```
  [时间戳] FILE WRITTEN
  path: <文件路径>
  lines: <起始行>-<结束行>
  ```
- code-log 路径：与 design.md 同目录的 `code-log.md`，追加写入，不覆盖

---

## 第一步：实现

按 design.md 中接口声明的顺序逐个实现。每实现一个接口：

1. 写入代码
2. 记录到 code-log（见上方规则）
3. 立即跑该接口对应的测试用例（见第二步），通过后再继续下一个

测试命令模板（从仓库根目录执行）：
```bash
PYTHONSAFEPATH=1 PYTHONPATH=$PWD/core:$PWD/app2:$PWD/lib:$PWD/lib2/python:$PWD/test/app2/data \
  conda run -n model-v4 python -m unittest <test_module> -v
```

---

## 第二步：测试循环

每次跑测试：

**若通过**：继续实现下一个接口。

**若不通过**：
1. 将报错追加到 code-log：
   ```
   [时间戳] TEST FAILED
   test: <测试用例名>
   error:
   <完整 traceback>
   ```
2. 分析报错原因：
   - 若错误来自**本次新写的代码**（design.md 定义的实现范围内）→ 修复，重新运行测试，循环最多 **3 次**
   - 若 3 次仍不通过，或错误来自**design.md 未涉及的代码、环境、依赖**→ 跳转到**中断流程**

**中断流程**：
```
[时间戳] INTERRUPT: out-of-scope error
source: <报错文件路径:行号>
reason: 该错误不在 design.md 定义的实现范围内
detail:
<错误描述>
```
写入 code-log，停止循环，通知用户："测试失败，原因超出 design.md 范围，详见 code-log。"

---

## 第三步：全量测试通过后，运行实验

从 `description.md` 中读取实验参数（`OVERRIDE`、`BACKTEST`、`SEEDS`、`TASK` 等），组装并执行：

```bash
cd <实验目录>
bash run.sh \
  DATA_SOURCE_PATH=/data/JP_end_2026-02-10/data \
  <从 description.md 读取的参数> \
  > run.log 2>&1
```

**若实验报错**：
1. 追加到 code-log：
   ```
   [时间戳] EXPERIMENT ERROR
   command: <完整命令>
   error:
   <报错内容>
   ```
2. 判断报错来源：
   - 来自本次实现的代码 → 修复，重跑，最多 **2 次**
   - 来自环境、数据路径、design.md 未涉及的模块 → 中断流程（同上）

**若实验通过**：在 code-log 追加：
```
[时间戳] DONE
unittest: PASS
experiment: PASS
```
告知用户循环完成，附上 code-log 路径。

---

## code-log 格式说明

所有写入均追加，不覆盖，时间戳格式 `YYYY-MM-DD HH:MM:SS`：

```markdown
# code-log

## [2026-05-13 14:30:01] FILE WRITTEN
path: app2/data/sparse_data.py
lines: 45-82

## [2026-05-13 14:31:15] TEST FAILED
test: test_sparse_data.TestSparseData.test_slice_empty
error:
AssertionError: Expected shape (0, 3) got (1, 3)
...

## [2026-05-13 14:32:00] FILE WRITTEN
path: app2/data/sparse_data.py
lines: 45-84

## [2026-05-13 14:32:30] INTERRUPT: out-of-scope error
source: core/lib/data.py:112
reason: 错误来自 design.md 未涉及的模块
detail: AttributeError: 'NoneType' object has no attribute 'time'

## [2026-05-13 15:10:00] DONE
unittest: PASS
experiment: PASS
```
