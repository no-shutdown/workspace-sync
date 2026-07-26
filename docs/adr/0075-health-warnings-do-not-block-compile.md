# 健康检查警告不阻断 compile

---
status: accepted
---

compile 在完成可写入的 raw、Wiki 节点和生成页面后，即使链接健康检查发现未解析链接、孤立节点或其他图谱维护问题，也视为成功并返回 warning。警告展示在命令结果中并追加到 `wiki/log.md`；只有 Obsidian CLI 不可用、目标 workspace 不可访问或写入失败等执行错误才使 compile 失败。

## Consequences

- 新知识不会因为已有图谱问题而无法保存。
- 用户能明确区分“内容已更新但需要维护”和“编译没有完成”。
- 健康检查不能通过自动改写节点来消除 warning。
