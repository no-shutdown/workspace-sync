# list 列出并选择本地 Vault 中的 workspace

---
status: accepted
---

list 直接通过 Obsidian CLI 列出当前本地 Vault 根目录下的 workspace 文件夹；用户选择名称后，workspace-sync 设置本地当前 workspace 并打开其 `wiki/overview.md`。list 不执行远端同步，远端更新由 pull 负责。

## Consequences

- workspace 选择不需要下载完整内容或访问远端。
- 本地 Vault 缺失或未打开时，list 必须明确提示先配置/恢复 Vault。
- list 的结果来自单一知识库空间，不再合并本地缓存和远端 workspace 快照。
