# 将整个知识库 Git 仓库作为单一 Obsidian Vault

---
status: accepted
---

个人开发知识库 Git 仓库根目录就是唯一 Obsidian Vault，多个 workspace 作为 Vault 内的独立目录存在。Obsidian CLI 通过 Vault 根和 workspace 相对路径定位内容，不为每个 workspace 创建独立 Vault。

## Consequences

- Obsidian 的图谱、搜索和链接能力可以在整个知识库范围工作，也可以按 workspace 路径限制。
- workspace 的事实隔离由目录和编译规则保证，而不是由多个 Vault 保证。
- Vault 配置和根级 Schema 属于共享工具层，不能承载某个 workspace 的事实。
