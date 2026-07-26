# list

## 命令

```text
/workspace-sync list
```

## 目标

列出当前本地 Obsidian Vault 根目录下的 workspace 文件夹，并在用户选择后设置本地当前 workspace 指针、打开该 workspace 的 `wiki/overview.md`。

## 边界

- `list` 只读取本地 Vault，不执行 Git fetch、pull 或远端目录查询。
- 不读取其他 workspace 的 Wiki 内容，只读取每个 workspace 的 `workspace.md` 元数据用于列表。
- 不自动选择 workspace；用户必须回复序号或名称。
- 归档 workspace 保留并显示，但标注 `archived`，不会默认当作活动 workspace。

## 步骤

1. 读取本地配置和本地状态，确认知识库路径。
2. 通过 Obsidian CLI 的 `folders` 命令列出 Vault 根目录的一级文件夹，并读取候选文件夹内的 `workspace.md`。
3. 只保留包含有效 `workspace_id` 和生命周期的 workspace。
4. 展示名称、生命周期、更新时间，例如：

   ```text
   1. task-graph       active    updated 2026-07-27
   2. release-cleanup  paused    updated 2026-07-20
   3. old-migration     archived  updated 2026-06-01
   ```

5. 提示用户回复序号或名称。用户选择后：
   - 将稳定 `workspace_id` 和名称写入本地状态文件；
   - 通过 Obsidian CLI 打开该 workspace 的 `wiki/overview.md`；
   - 告知后续 compile/push 将默认作用于此 workspace。

如果没有 workspace，进入新建流程：要求用户输入名称，初始化 `workspace.md`、`raw/`、`wiki/` 结构，并将新 workspace 设为当前 workspace。不要猜测名称。
