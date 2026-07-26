# 采用按工作空间隔离的 Karpathy Wiki 目录结构

---
status: accepted
---

知识库 Git 仓库根目录提供共享的 `SCHEMA.md`；每个工作空间目录独立包含 `raw/` 和 `wiki/`。`wiki/` 内固定提供 `index.md`、`log.md` 和按节点类型组织的 Markdown 页面目录（项目、系统、能力、能力缺口、联调点、任务、技术决策）。工作空间之间不共享事实页面、原始档、索引或日志。

## Consequences

- 编译器可以在单个工作空间目录内完成输入、编译和导航更新。
- 共享 Schema 只描述规则，不承载任何工作空间事实，因此不会破坏工作空间隔离。
- Obsidian 可以直接打开整个 Git 仓库，也可以将单个工作空间作为独立 Vault 使用。
