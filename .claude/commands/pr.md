---
name: pr
description: 拉取指定仓库和时间范围内的 GitHub PR，逐条翻译成中文并保存到 ~/data/pr/<repo>/<number>.md
disable-model-invocation: false
allowed-tools: Bash Read Write
---

# /pr — GitHub Pull Request 中文归档

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
- 若该编号的文件**已存在**且用户选择**覆盖**：先删除已有文件，再执行 3b/3c。
- 若该编号的文件**不存在**：直接执行 3b/3c。

### 3a — 删除已有文件（仅覆盖模式）

```bash
rm ~/data/pr/<repo>/<number>.md
```

### 3b — 拉取完整内容

```bash
gh pr view <number> \
  --repo FinAI-Project/<repo> \
  --json number,title,url,state,body,comments,reviews,labels,assignees,author,createdAt,closedAt,mergedAt,baseRefName,headRefName
```

### 3c — 翻译并写入 MD 文件

将上述 JSON 内容翻译成中文，写入 `~/data/pr/<repo>/<number>.md`。

**翻译规则**：
1. 所有正文（标题、正文、评论、Review 意见）译为中文；专有名词、技术术语后用括号注释英文原文，例如：合并（merge）、代码审查（code review）、基础分支（base branch）
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

## 描述（Description）

<翻译后的 body 正文>

---

## 评论（Comments）

### 评论 1 — <author>（<createdAt>）

<翻译后的评论内容>

（若无评论则写"暂无评论（No comments）"）

---

## 代码审查意见（Reviews）

### 审查 1 — <author>（<submittedAt>）【通过（APPROVED）/ 请求修改（CHANGES_REQUESTED）/ 评论（COMMENTED）】

<翻译后的审查内容>

（若无审查意见则写"暂无审查意见（No reviews）"）
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
