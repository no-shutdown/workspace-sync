# pull 后打开当前 workspace 总览

---
status: accepted
---

pull 在本地 Vault 已准备好并确定当前 workspace 后，通过 Obsidian CLI 打开该 Vault，并打开 `<workspace>/wiki/overview.md`。这样 pull 不只是恢复文件，还完成面向用户和 AI 的接手入口。

## Consequences

- 新设备可以在一次 pull 后直接看到当前 workspace 的开发全景。
- overview 缺失或损坏时必须明确报告，并仍保留已恢复的仓库内容。
- 打开动作使用本地 workspace 路径，不把设备路径写入知识库。
