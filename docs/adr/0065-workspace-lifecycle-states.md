# 使用 active、paused、archived 管理 workspace 生命周期

---
status: accepted
---

workspace.md 的生命周期状态固定为 `active`、`paused` 和 `archived`。完成当前目标或决定放弃的 workspace 都进入 `archived`，通过归档原因区分；归档保留全部 raw、Wiki、任务和历史，不自动删除。

## Consequences

- list 和 overview 可以区分当前开发空间与历史空间。
- workspace 生命周期与任务生命周期分开维护。
- 归档操作需要记录时间和原因，并保留恢复为 active 的历史能力。
