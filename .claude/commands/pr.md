---
name: pr
description: 拉取指定仓库和时间范围内的 GitHub PR，阅读源码并进行分析，保存到 ~/data/pr/<repo>/<number>.md
disable-model-invocation: false
allowed-tools: Bash Read Write
---

# /pr — GitHub Pull Request 分析归档

## Step 1 — 确认参数

### 模式 A：直接指定编号列表

若用户在调用时直接给出了 PR 编号列表（如 `#210 #211` 或 `210,211`）以及所属仓库，则：
- **跳过所有其他条件询问**（时间范围、发布者）
- 直接以该编号列表和仓库作为处理目标，进入 Step 2（覆盖确认）

### 模式 B：按条件查询

若用户未给出编号列表，从命令行参数或对话上下文中读取：
- **仓库**：`compass-app-jasper` / `compass-core` / `fenghe-nn`，可多选，默认**全部三个**
- **时间范围**：默认**最近 7 天**（从今天往前推 7 天）
- **发布者（author）**：筛选由特定用户创建的 PR，默认**不限制**

如果用户在调用时没有提供上述参数，**用 AskUserQuestion 询问**，提供以下选项：
- 仓库：三个仓库（可多选），含"全部"选项
- 时间范围：最近 7 天 / 最近 30 天 / 自定义（让用户输入）
- 发布者：不限制 / 指定用户名（Other 输入）

确认后，将仓库列表、起始日期、发布者固定下来，后续步骤直接使用，不再询问。

---

## Step 2 — 拉取 PR 列表

对每个目标仓库，根据已确认的筛选参数构造命令：

```bash
gh pr list \
  --repo FinAI-Project/<repo> \
  --state all \
  --search "created:>=<YYYY-MM-DD>" \
  [--author <author>] \
  --json number,title,url,state,createdAt \
  --limit 200
```

- 若设置了**发布者**，追加 `--author <login>` 参数
- 若不限制，则不添加该参数

记录返回的 PR 编号列表。如果列表为空，告知用户该仓库在此条件下没有 PR，跳过。

---

## Step 2.5 — 覆盖确认

在拿到待处理编号列表后，检查其中哪些在 `~/data/pr/<repo>/` 下已存在对应 `.md` 文件：

```bash
ls ~/data/pr/<repo>/<number>.md 2>/dev/null
```

若存在已有文件，**用 AskUserQuestion 询问**：
- **覆盖**：删除已有文件，重新拉取并写入
- **跳过**：保留已有文件，仅处理尚未存在的编号

将覆盖策略固定下来，后续步骤直接使用，不再询问。

---

## Step 3 — 逐条处理 PR

对每个 PR，按以下子步骤执行：

- 若该编号的文件**已存在**且用户选择**跳过**：直接略过，不拉取、不写入。
- 若该编号的文件**已存在**且用户选择**覆盖**：先删除已有文件，再执行 3a–3d。
- 若该编号的文件**不存在**：直接执行 3a–3d。

### 3a — 删除已有文件（仅覆盖模式）

```bash
rm ~/data/pr/<repo>/<number>.md
```

### 3b — 拉取 PR 元数据和审查意见

```bash
gh pr view <number> \
  --repo FinAI-Project/<repo> \
  --json number,title,url,state,body,comments,reviews,labels,assignees,author,createdAt,closedAt,mergedAt,baseRefName,headRefName
```

同时拉取 diff，用于了解改动范围：

```bash
gh pr diff <number> --repo FinAI-Project/<repo>
```

### 3c — 阅读源码，理解改动

**不切换分支**。先 fetch，再用 `git show` 直接读取远程分支上的文件：

```bash
# 1. fetch（确保 origin/<headRefName> 是最新状态）
git -C ~/data/<repo> fetch origin

# 2. 读取文件（不切换本地分支）
git -C ~/data/<repo> show origin/<headRefName>:<path/to/file>
```

根据仓库不同，选择对应的入口文件开始阅读：

- **compass-app-jasper**：从 `app2/Makefile` 或 `app2/train.py` 出发，追踪 diff 中涉及的模块
- **compass-core / fenghe-nn**：从 diff 中涉及的测试文件（`test/` 目录）出发，再追踪到被测试的实现文件

阅读目标：
1. 明确每个改动文件的职责和在整体架构中的位置
2. 理解新增/修改代码的逻辑（做了什么、为什么这样做）
3. 识别潜在的数值安全、边界条件、接口设计问题
4. 对于 diff 中涉及的自定义类型，以及审查意见指控有问题的代码所涉及的类型，必须追踪到其实现文件，验证实际行为后再下结论

### 3d — 写入 MD 文件

将分析结果写入 `~/data/pr/<repo>/<number>.md`，**不是简单翻译 PR 内容，而是基于源码阅读的实质性分析**。

**写作规则**：
1. 所有文字使用**中文**；专有名词、技术术语后用括号注释英文原文，例如：跳跃扩散（jump-diffusion）、前向传播（forward pass）
2. 代码块（`` ``` `` 包裹的内容）**保持原文不翻译**
3. 遇到图片（Markdown 中的 `![...](...)`）替换为：`【此处有一张图片，无法解析】`
4. 遇到其他无法解析的内容（附件、视频等），注明：`【此处有附件/媒体内容，无法解析】`

**MD 文件格式**（严格按此结构）：

```markdown
# PR #<number>：<翻译后的标题>

- **编号（Number）**：#<number>
- **网址（URL）**：<url>
- **状态（State）**：开放中（open）/ 已合并（merged）/ 已关闭（closed）
- **作者（Author）**：<author>
- **源分支（Head Branch）**：<headRefName>
- **目标分支（Base Branch）**：<baseRefName>
- **创建时间（Created At）**：<createdAt>
- **合并时间（Merged At）**：<mergedAt>（若未合并则省略此行）
- **关闭时间（Closed At）**：<closedAt>（若未关闭则省略此行）
- **标签（Labels）**：<labels>（若无则省略）
- **指派人（Assignees）**：<assignees>（若无则省略）

---

## 变更摘要（Change Summary）

<!-- 基于源码阅读的改动说明，不是 PR body 的翻译。说明：改了哪些文件、各自的职责、核心逻辑变化。 -->

---

## 代码审查（Code Review）

<!-- 基于源码阅读的独立审查意见。关注：数值安全、边界条件、接口设计、算法正确性。每条意见注明对应文件和行号（如已知）。若无问题可写"未发现明显问题"。 -->

---

## 审查意见评估（Review Comment Evaluation）

<!-- 逐条评估 PR 上已有的审查意见（包括 Gemini 和人工审查），判断每条意见是否成立、是否重要、是否已被处理。格式：
### 意见 N — <author>
**原文摘要**：…
**评估**：成立 / 不成立 / 部分成立
**理由**：…
-->
```

---

## Step 4 — 汇报结果

所有 PR 处理完毕后，输出一个简短汇总：

```
已归档 PR：
  compass-app-jasper: #210, #211（共 2 条）
  compass-core:       #55（共 1 条）
  fenghe-nn:          无新 PR
文件位置：~/data/pr/
```
