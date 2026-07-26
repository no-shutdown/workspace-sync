# 为 workspace 保留独立稳定身份

---
status: accepted
---

每个 workspace 创建时获得稳定 `workspace_id`，与用户可读的文件夹名称分离。文件夹可以通过受控 rename 操作改名而不产生新的 workspace；本地当前指针、内部链接和历史都继续关联原 workspace ID。

## Consequences

- workspace 改名不会破坏其任务、节点、raw 或历史。
- 需要有一个可被 Obsidian CLI 读取的 workspace 元数据入口来保存 ID 和生命周期信息。
- pull/list 不能只用文件夹名称判断 workspace 是否相同。
