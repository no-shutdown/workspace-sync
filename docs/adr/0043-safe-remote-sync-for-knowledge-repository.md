# 安全同步知识库 Git 远端

---
status: accepted
---

push 发现知识库远端有新提交时，先 fetch 并尝试将本地提交 rebase/整合到远端之后；无冲突时继续推送，有冲突时停止并保留本地与远端内容供用户解决。push 禁止 force push 或静默丢弃任何一方的 Wiki、raw 或图谱修改。

## Consequences

- 知识库 Git 历史保持可追溯，远端内容不会被一次操作强行覆盖。
- 编译产生的本地 commit 可能在 push 阶段遇到 Wiki 合并冲突。
- 冲突解决需要尊重 raw 不可覆盖和 Wiki 共同维护规则。
