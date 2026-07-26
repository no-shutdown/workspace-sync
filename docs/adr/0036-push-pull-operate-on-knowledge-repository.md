# 保留 push/pull 命令并直接操作知识库仓库

---
status: accepted
---

继续保留 `push`、`pull` 和 `compile` 作为 workspace-sync 的主要操作，但它们直接作用于配置的个人开发知识库 Git 仓库：`pull` 获取工作空间内容，`compile` 更新当前工作空间的 raw 和 Wiki，`push` 提交并推送知识库变更。三者不再经过旧的 workspace 快照存储层。

## Consequences

- 命令名称保持用户已有的工作习惯，底层存储职责被统一到知识库仓库。
- `manifest.json`、`summary.md` 和 `conversation.jsonl` 不再是 push/pull 的核心交接产物。
- push/pull 的实现需要改为 Git 仓库同步、工作空间选择和知识库状态校验。
- 没有当前 workspace 时，相关命令进入用户命名的新建流程，而不是直接失败。
