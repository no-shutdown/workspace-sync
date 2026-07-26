# 使用单一知识库 Git 仓库配置

---
status: accepted
---

workspace-sync 不再为 workspace 提供 Local、GitHub、GitLab、MinIO 四套存储 backend；它统一配置一个个人开发知识库 Git 仓库、分支、本地 Vault 路径和认证方式。该仓库同时是 workspace-sync 的存储空间、Obsidian Vault 和个人开发知识库。

## Consequences

- 配置模型和 push/pull 流程显著简化，所有 workspace 位于同一 Git 仓库。
- 原有 backend 接口、workspace 快照 staging 和远端对象布局需要移除或重写。
- Git 远端服务的差异只存在于 Git 连接和认证层，不再改变知识库目录模型。
