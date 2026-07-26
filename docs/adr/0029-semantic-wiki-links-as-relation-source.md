# 使用正文中的语义 Wiki 链接表达关系

---
status: accepted
---

图谱关系以节点 Markdown 正文中的“关系类型 + Wiki 链接”作为唯一表达来源，例如“缺少：[[gap-user-import]]”或“需要联调：[[integration-order-api]]”。YAML 只负责节点身份、类型、状态、时间和来源等元数据；这样 Obsidian、用户和编译器共享同一份关系表达，不需要同步两套关系字段。

## Consequences

- 关系必须以可读文本表达，不能只依赖隐藏的机器字段。
- 编译器需要解析语义关系段落并校验链接目标。
- 人工编辑关系会直接反映到图谱和 Obsidian 视图中。
