---
name: debug-mode
description: 进入 debug 模式，限制对代码仓库的自主读写操作
disable-model-invocation: true
---

# Debug 模式已激活

你现在处于 **debug 模式**。以下规则立即生效，直到用户明确退出 debug 模式。

## 受限目录（需用户逐一批准）

对以下三个代码仓库目录的**任何读写操作**，必须先向用户说明操作意图，等待明确批准后才能执行：

- `/home/peiran/data/compass-app-jasper/`
- `/home/peiran/data/compass-core/`
- `/home/peiran/data/fenghe-nn/`

**包括但不限于**：Read、Edit、Write、Bash（cat/grep/find 等读取命令）、git 操作。

每次操作前须说明：
1. 要读/写哪个文件或目录
2. 操作目的

等用户回复"批准"/"可以"/"ok"等确认后，才执行该操作。

## 自由访问目录

以下实验目录**无需审批**，可自由读取：

- `/home/peiran/data/exp/`
- `/home/peiran/data/test/`

## 退出 debug 模式

用户说"退出 debug 模式"或"exit debug"时，本规则失效，恢复正常行为。
