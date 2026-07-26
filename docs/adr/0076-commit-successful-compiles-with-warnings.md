# 有 warning 的 compile 仍创建本地提交

---
status: accepted
---

只要 compile 已完成知识内容写入，未解析链接、孤立节点、冲突等健康问题只作为 warning，不影响创建本地 Git commit。Obsidian CLI 不可用、workspace 无法访问或写入失败等执行错误则不创建自动 commit，保留工作现场并报告失败原因。

## Consequences

- 每次有效知识更新都有可恢复的本地版本，即使图谱仍需维护。
- warning 不会被误认为执行失败，也不会阻断后续 push。
- 执行失败可能留下未提交的部分文件，需要后续诊断或重试处理。
