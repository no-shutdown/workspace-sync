# 新会话从 Schema、overview 和活动图谱启动

---
status: accepted
---

新 AI 会话进入当前 workspace 后，默认读取共享 `SCHEMA.md`、该 workspace 的 `wiki/overview.md`，以及当前活动任务和其关联的项目、系统、能力缺口、联调点和决策节点。raw 原始档与完整历史不默认全部加载，只在需要追溯或解决冲突时按需读取。

## Consequences

- 新会话先获得结构化全景，不依赖某一份不断压缩的 summary。
- 启动上下文保持较小，具体事实通过 Wiki 链接按需展开。
- overview 和活动节点必须持续保持可导航、可更新。
