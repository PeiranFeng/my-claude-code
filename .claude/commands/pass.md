---
name: pass
description: 更新 Claude Code 权限白名单。输入是指令则把 Bash allow 条目写入仓库与用户两处 settings，是目录则写入用户 additionalDirectories。仅当输入含 pull 才 pull+并集同步，仅当输入含 push 才 commit+push my-claude-code。
disable-model-invocation: true
allowed-tools: Bash Read Edit Write
---

# /pass — 白名单

三个作用域：

- **仓库 allow**（受版本控制、跨机共享）：`~/data/my-claude-code/.claude/settings.json` 的 `permissions.allow`
- **用户 allow**（本机全局）：`~/.claude/settings.json` 的 `permissions.allow`
- **用户目录白名单**（本机全局、机器相关绝对路径，不入版本控制）：`~/.claude/settings.json` 的 `permissions.additionalDirectories`

## 行为由输入关键词触发（可组合）

- 输入含独立 token `pull` → 执行【pull 同步】。
- 输入含独立 token `push` → 执行【push】。
- 其余 token（指令名或目录路径）→ 执行【更新 settings】。
- 三者可同时出现在一次调用里，各自独立触发；都没有则报告用法、不做任何改动。

`pull` / `push` 为保留关键词，不作为待加白名单的指令名处理。

## 更新 settings（默认动作；有指令/目录输入时）

- **目录**（绝对路径、`~` 开头、或指向已存在的目录）→ 加入 `~/.claude/settings.json` 的 `additionalDirectories`。去重：该路径已存在、或已有某个父目录覆盖它时跳过。只写用户全局，**不写仓库 settings**。
- **指令**（其余）→ 生成权限 pattern：输入已含括号（完整 pattern，如 `Bash(git push:*)`）时直接用；否则取首个 token 作命令名，生成 `Bash(<命令>:*)`。写入仓库与用户两处 `permissions.allow` 并保持一致。去重：已存在则跳过。

只更新文件，**不 pull、不 commit、不 push**。

## pull 同步（仅当输入含 pull）

在 main 分支，用 merge（不 rebase）。先确认不落后于 `origin/main`、且工作区改动不与待并入内容冲突，再 pull：

```
git -C ~/data/my-claude-code fetch origin
```
```
git -C ~/data/my-claude-code pull --no-rebase
```

然后读仓库与用户两处 `permissions.allow`，取并集写回两处，任一方独有的条目都保留、不丢弃。

## push（仅当输入含 push）

仅当**仓库那份** `.claude/settings.json` 有改动时执行（调用 /pass push 即为授权，无需二次确认）：

```
git -C ~/data/my-claude-code add .claude/settings.json
```
```
git -C ~/data/my-claude-code commit -m "<英文 message>"
```
```
git -C ~/data/my-claude-code push
```

commit message 用英文描述本次新增内容（如 `chore(settings): allow Bash(ps:*)`），并附环境规约要求的 `Co-Authored-By` 尾注。仓库 settings 无改动则报告"无可推送"，不 commit/push。
