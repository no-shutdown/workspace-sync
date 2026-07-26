# workspace-sync 直接存储个人开发知识库

---
status: accepted
---

workspace-sync 的存储空间与个人开发知识库是同一个 Git 仓库，不再维护一份独立的 workspace 交接副本。仓库根目录直接承载共享 `SCHEMA.md` 和多个工作空间目录；每个工作空间直接包含自己的 `raw/`、`wiki/`、索引和日志。原有以 `manifest.json`、`summary.md`、`conversation.jsonl`、`projects/` 为中心的 workspace 存储布局不再是设计约束，可以整体废弃并重构。

## Consequences

- `compile`、`push` 和 `pull` 都直接操作同一个个人开发知识库空间。
- 不再需要在 workspace-sync 存储和知识库 Git 仓库之间复制 Wiki 内容。
- `summary.md` 不再是唯一或核心上下文；工作空间总览由 `wiki/overview.md` 派生。
- 完整对话文件不是知识库正确性的前提，`raw/` 和 Wiki 才是主要知识资产。
- 现有 `SKILL.md`、README 和 action 文档中的旧目录结构需要整体重写，不能只做局部兼容修补。
