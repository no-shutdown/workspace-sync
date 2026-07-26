# Vault 文件操作统一通过 Obsidian CLI

---
status: accepted
---

workspace-sync 对个人开发知识库 Vault 内文件的读取、创建、修改、搜索、链接查询和打开统一使用官方 Obsidian CLI；Git 命令只负责 commit、fetch、rebase、push 等版本控制操作。workspace-sync 不再实现第二套 Vault 文件 API、图谱数据库或语义索引。

## Consequences

- compile、会话启动和图谱健康检查都必须通过 Obsidian CLI 访问 Vault 内容。
- Obsidian CLI 不可用时，相关操作应明确失败，不静默改用另一套文件接口。
- Git diff 负责版本审查，但不负责理解节点和关系语义。
