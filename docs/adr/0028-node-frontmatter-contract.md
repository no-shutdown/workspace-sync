# 为节点 Markdown 固定最小元数据契约

---
status: accepted
---

每个图谱节点 Markdown 必须拥有 YAML 元数据，至少包含稳定 `id`、节点 `type`、`title`、`created_at`、`updated_at` 和 `source_refs`；任务节点额外包含当前 `status`。元数据用于身份识别、编译更新、来源追溯和 Obsidian/其他工具查询，不能由文件名替代。

## Consequences

- 编译器可以在文件改名后仍通过稳定 ID 找到原节点。
- 人工新建节点也必须遵守同一最小契约。
- 节点正文继续承载解释和语义关系，不把所有内容塞进 YAML。
