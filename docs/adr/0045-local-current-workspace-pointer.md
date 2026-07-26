# 当前 workspace 选择只保存在本地上下文

---
status: accepted
---

当前 workspace 是本机或当前 AI 会话的上下文指针，不写入个人开发知识库 Git 仓库。知识库只保存所有 workspace 的内容；不同设备可以选择不同 workspace。当前指针缺失时，相关操作按工作空间创建规则处理。

## Consequences

- 不会因为一台设备选择了某个 workspace 而改变其他设备的当前工作对象。
- workspace 选择不是需要 Git 合并的知识事实。
- CLI/skill 需要有可靠的本地指针存储和缺失时的新建流程。
