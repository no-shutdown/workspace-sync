# 使用 workspace.md 保存工作空间自身元数据

---
status: accepted
---

每个 workspace 根目录必须包含 `workspace.md`，以 YAML 元数据保存稳定 `workspace_id`、用户可读名称、生命周期状态、创建时间、更新时间和归档信息等 workspace 自身属性。开发目标和图谱全景仍分别由节点页面和 `wiki/overview.md` 承载。

## Consequences

- workspace 改名和生命周期变化有明确的元数据落点。
- list、pull 和 Obsidian CLI 可以通过同一页面识别 workspace。
- `workspace.md` 不是普通任务节点，编译器不能把它当作任务或项目解析。
