# 使用 Obsidian CLI 作为知识库交互层

---
status: accepted
---

workspace-sync 使用官方 Obsidian CLI 对个人开发知识库 Markdown 执行打开、读取、创建、搜索、链接查询和 Obsidian 命令调用；Obsidian 原生 Graph View 负责可视化。workspace-sync 自身不再实现独立图谱数据库或图形运行时，Git Markdown 仍是唯一事实来源。

## Consequences

- compile 负责生成和维护 Markdown，Obsidian CLI 负责 Vault 交互和视图入口。
- 实现需要检查 Obsidian CLI 是否可用，并在不可用时给出明确提示。
- 当前方案依赖官方 CLI 的运行环境和命令能力，不应假设任意机器都已安装或启动 Obsidian。

## Reference

- [Obsidian CLI 官方文档](https://obsidian.md/help/cli)
