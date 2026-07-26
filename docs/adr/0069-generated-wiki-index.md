# 由 compile 生成 Wiki 索引

---
status: accepted
---

当前 workspace 的 `wiki/index.md` 由 compile 根据节点页面生成，按节点类型提供链接、一句话摘要、状态、来源数量以及候选、冲突和孤立页面提示。index 是完整导航目录，可以随时重建，不作为独立开发事实来源。

## Consequences

- 人工不需要维护第二套节点清单。
- 节点新增、改名、归档或删除后必须同步更新索引。
- index 与 overview 分工：index 追求完整，overview 追求当前接手重点。
