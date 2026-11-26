# html

```text
/workspace-sync html [工作区名称]
```

1. 使用已校验的当前会话 workspace，或解析命令中明确给出的 workspace。用稳定 `workspace_id` 核对目标的 `工作区.md`，并将明确给出的名称解析为实际目录名。两者都没有时提示用户明确指定 workspace 或先执行 `list`/`pull`。本命令不写会话状态。
2. 从已安装的 skill 目录调用本地导出器。首次使用按 [HTML 导出](../references/html.md) 安装依赖。

   ```sh
   node "<skill 目录>/src/html.mjs" --root "<知识库路径>" --workspace "<实际目录名>" --workspace-id "<已验证的 ID>" --open
   ```

3. 导出器先用当前本地 Markdown 更新固定位置的 `index.html`，再打开默认浏览器。报告 HTML 路径；浏览器打开失败时仍返回可手动打开的文件路径。

此命令只读知识库内容，无需 Git 同步、运行 `compile` 或调用 Obsidian。后续 `compile` 成功时会刷新同一个 HTML 文件，浏览器刷新即可读到更新后的快照。
