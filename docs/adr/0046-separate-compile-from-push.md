# 将 compile 与 push 的职责分开

---
status: accepted
---

compile 负责从当前 workspace 的 raw 和当前会话中生成或更新 Wiki、图谱、索引和日志；push 负责采集项目现场、提交当前 workspace 的已有知识库变更并同步 Git 远端。push 不自动重新解释 raw，也不隐式改写图谱。

## Consequences

- 用户可以先检查 compile 的图谱变化，再决定何时 push。
- push 的结果更可预测，不会因为同步动作改变知识内容。
- 自动化流程若需要两步连做，必须显式串联 compile 和 push。
