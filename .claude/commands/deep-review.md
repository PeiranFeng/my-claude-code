---
name: deep-review
description: 按 CLAUDE.md 中标记 [require-review] 的原则，对本地 diff 或远程 PR 做多维度并发代码 review，结果只写文件到 ~/data/review/<repo>/<branch>/，不产生终端内容输出
disable-model-invocation: false
allowed-tools: Bash Read Agent AskUserQuestion
---

# /deep-review — 多维度并发代码 Review

只写文件，不在终端输出 review 内容本身（可以输出"已完成，见 <路径>"这类简短确认）。

## Step 1 — 确认 review 对象

若调用方（用户，或调用本 skill 的其他 skill，如 `/pr`）已在 prompt 中明确给出以下信息，跳过询问，直接使用：

- **类型**：本地 diff（local）/ 远程 PR（remote）
- **仓库**（repo）：`compass-app-jasper` / `compass-core` / `fenghe-nn`
- **分支**（branch）：local 用当前 git 分支；remote 用 PR 的 headRefName
- **remote 时还需**：PR 编号、PR 所属仓库全名（如 `FinAI-Project/<repo>`）
- **覆盖策略**：`~/data/review/<repo>/<branch>/` 已存在时，覆盖 / 保留现状。若调用方已经就同一改动做过覆盖/跳过的决策（例如 `/pr` 在自己的 Step 2.5 中已询问过用户），直接复用该决策，不再重复询问

以上信息若调用方未给出，用 AskUserQuestion 询问用户：类型、仓库、分支或 PR 编号；若发现输出目录已存在，额外询问覆盖策略。

### 可选：item 范围

调用方可以指定只 review CLAUDE.md 中哪些分组编号（对应 Step 3 里"组 2"、"组 3"这类分组号，不是条目号），支持两种格式：
- 连续区间：`[2-4]`，表示组 2、3、4
- 离散项：`[1,2,3]`，表示组 1、2、3
- 两种格式可以出现在同一次调用里，如 `[2-4,7]`

**未指定范围时，默认覆盖 Step 3 中扫描到的全部分组**（不缩小范围）。范围只用于筛选 Step 3 要派发哪些分组的 agent，**不影响 Step 4**——Step 4 的通用 review agent 无论范围如何都必须派发。

## Step 2 — 准备输出目录

```bash
mkdir -p ~/data/review/<repo>/<branch>
```

若该目录已存在且非空：
- 覆盖：先 `rm -rf ~/data/review/<repo>/<branch>/*`，再继续 Step 3
- 保留现状：直接结束，不执行 Step 3、Step 4

## Step 3 — 扫描 `[require-review]` 标记，按分组并发 review

```bash
grep -n '\[require-review\]' /home/peiran/data/my-claude-code/CLAUDE.md
```

按条目编号的分组号（如 `2-1` 属于第 2 组）归类，得到带标记条目的分组集合。未命中任何标记的分组不派发 agent。若调用方指定了 item 范围（见 Step 1），在此基础上再交集一次——只保留范围内、且确实带标记的分组；范围里写了但该分组其实没有 `[require-review]` 标记的，直接忽略，不报错。

对每个（命中标记 ∩ 指定范围，若未指定范围则只看命中标记）的分组 i，并发起一个 `general-purpose` 类型的 agent（Agent 工具），prompt 中必须包含：

- 只给该组 i 中带 `[require-review]` 标记的条目原文（不要整份 CLAUDE.md，避免无关原则带偏判断）
- 获取 review 对象的方式：
  - local：`git -C ~/data/<repo> diff <base>...<branch>`（base 分支向调用方确认，或用 `git merge-base`）
  - remote：`gh pr diff <number> --repo <仓库全名>`，需要更多上下文时用 `git -C ~/data/<repo> show origin/<branch>:<path>` 读取具体文件
- 只针对这些条目逐条给出结论（通过 / 存在问题），存在问题时注明文件路径和行号（已知时）
- 结果写入 `~/data/review/<repo>/<branch>/item_<i>.md`，全部通过时写"各项均通过"
- 明确告知该 agent：只写文件，不需要额外的总结汇报

## Step 4 — 并发一个通用 review agent

同一条消息内再起一个 `general-purpose` 类型的 agent，prompt 中必须包含：

- 明确指示该 agent 用 Skill 工具调用：
  - local：`skill: "code-review"`（力度按调用方指定，未指定则用默认力度）
  - remote：`skill: "review"`，并传入 PR 编号与仓库全名
- 将该 skill 产出的发现整理写入 `~/data/review/<repo>/<branch>/base.md`
- 同样只写文件，不额外汇报

Step 3、Step 4 的所有 agent 在同一条消息中一起派发，并发执行。

## Step 5 — 收尾检查

确认 `~/data/review/<repo>/<branch>/` 下存在 `base.md`，以及 Step 3 实际派发过 agent 的每个分组对应的 `item_<i>.md`（范围外未派发的分组不应该有对应文件，也不必有）。缺失文件视为对应 agent 失败，只重跑缺失的那个 agent，不重跑已完成的。全部齐备后向调用方确认输出目录路径与本次实际覆盖的分组范围，不复述文件内容。
