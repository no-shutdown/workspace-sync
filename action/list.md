# list

## 命令

```text
/workspace-sync list
```

## 目标

列出当前本地 Obsidian Vault 根目录下的 workspace 文件夹，并在用户选择后将该 workspace 绑定到当前会话、打开该 workspace 的 `图谱/总览.md`。

## 边界

- `list` 只读取本地 Vault，不执行 Git fetch、pull 或远端目录查询。
- 不读取其他 workspace 的图谱内容，只读取每个 workspace 的 `工作区.md` 元数据用于列表。
- 不自动选择 workspace；用户必须回复序号或名称。
- 归档 workspace 保留并显示，但标注 `archived`，不会默认当作活动 workspace。
- 默认通过 `<run_dir>/.workspace-sync-cache/sessions/<session-id>.json` 持久化当前会话选择；缺少 `session_id` 或 `run_dir` 时，只允许本次显式选择生效，不创建共享缓存，也不回退到用户级 current workspace。

## 步骤

1. 读取本地配置和设备级状态，确认知识库路径；设备级状态只用于 `project_paths` 等本机信息，不读取 `current_workspace_*` 作为默认来源。
2. 通过 Obsidian CLI 的 `folders` 命令列出 Vault 根目录的一级文件夹，并读取候选文件夹内的 `工作区.md`。
3. 只保留包含有效 `workspace_id` 和生命周期的 workspace。
4. 展示名称、生命周期、更新时间，例如：

   ```text
   1. 数据导入迭代     active    updated 2026-07-27
   2. 发布清理         paused    updated 2026-07-20
   3. 旧版迁移         archived  updated 2026-06-01
   ```

5. 提示用户回复序号或名称。用户选择后：
   - 优先将稳定 `workspace_id`、显示名称和保留的 `focus_task_id` 写入当前会话缓存；写入时使用临时文件加原子替换，不创建共享 `current.json` 或其他全局指针；
   - 如果运行环境缺少 `session_id` 或 `run_dir`，或无法创建/读取会话缓存目录，则把这次选择视为一次性操作：继续打开目标 workspace，但明确告知“会话状态不可持久化”，后续命令仍需再次显式选择；
   - 通过 Obsidian CLI 打开该 workspace 的 `图谱/总览.md`；
   - 告知后续 compile/push/migrate 只有在当前会话缓存成功写入后才会默认作用于此 workspace；否则本次只作为非持久化选择。

如果没有 workspace，进入新建流程：要求用户输入名称，初始化 `工作区.md`、`原始资料/`、四类 `图谱/节点/`、任务根页 `图谱/节点/任务/任务-开发总任务.md`、`图谱/视图/`、`图谱/说明/` 和 `图谱/候选/` 结构，然后按同样规则写入当前会话缓存或报告本次选择不可持久化。不要猜测名称。
