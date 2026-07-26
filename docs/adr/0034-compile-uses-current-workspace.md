# compile 复用 push 和 pull 的当前工作空间

---
status: accepted
---

`compile` 的目标沿用 `push` 和 `pull` 建立的当前 workspace，不另加工作空间参数或第二套选择机制。用户在当前 workspace 中执行 `/workspace-sync compile`，命令只读取和更新该 workspace 的 `raw/`、`wiki/`、索引和日志。

## Consequences

- `compile`、`push` 和 `pull` 对 workspace 的理解保持一致。
- 当前 workspace 未建立时，compile 必须先要求用户选择或恢复 workspace，不能自动猜测。
- 编译结果天然属于当前工作空间，不会写入其他工作空间。
