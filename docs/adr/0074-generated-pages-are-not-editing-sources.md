# 将 overview 和 index 定义为生成页面

---
status: accepted
---

当前 workspace 的 `wiki/overview.md` 和 `wiki/index.md` 由 compile 生成，分别承担快速接手视图和完整导航目录的职责。它们可以随时重建，不作为人工事实或任务状态的编辑入口；用户和 AI 对开发事实的修改必须落在 raw 或具体 Wiki 节点页面中。

## Consequences

- 生成视图不会与节点事实形成第二份可冲突的真相。
- 手工维护需要进入正确的 raw 或节点页面，而不是修改汇总页。
- compile 失败或未运行时，旧的生成页面可能暂时落后于事实源，日志和状态需要明确标示。
