# 将链接健康检查限定在图谱页面

---
status: accepted
---

v1 的语义链接健康检查只扫描当前 workspace `wiki/nodes/` 下的正式节点和已确认纳入图谱的候选页面。`raw/`、`workspace.md`、`wiki/overview.md`、`wiki/index.md` 与 `wiki/log.md` 不作为图谱关系源，避免原始资料、生成视图和审计日志制造无意义的断链或孤立节点诊断。

## Consequences

- 健康问题更贴近真实开发图谱，而不是整个 Vault 的文件结构。
- 生成页面仍可以展示诊断结果，但不会参与诊断本身。
- 候选页面需要有清晰的“已纳入图谱”状态，才能决定是否进入扫描范围。
