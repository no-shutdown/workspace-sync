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
- 默认通过 `<run_dir>/.workspace-sync-cache/sessions/<session-id>.json` 持久化当前会话选择；缺少、损坏或无法验证的会话缓存不能作为默认来源。缺少 `session_id` 或 `run_dir` 时，只有经验证的显式 workspace 选择可以本次生效，不创建共享缓存，也不回退到用户级 current workspace。

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
   - 读取当前会话缓存中已有的 `workspace_id`，并与所选 workspace 的稳定 `workspace_id` 比较。只有两者相同，且 `focus_task_id` 已在所选 workspace 中验证为正式 `任务` 节点时，才保留该焦点；不满足任一条件时不保留；
   - 切换 workspace 时将 `focus_task_id` 清为 `null`，除非本次命令明确提供了所选 workspace 中有效的替代焦点。缓存焦点无效时清除并报告 warning；告诉用户可以随后选择新的焦点，不能按名称、活动状态、最近更新时间或其他 workspace 推断；
   - 将稳定 `workspace_id`、显示名称和按上述规则确定的 `focus_task_id` 写入当前会话缓存；写入时使用临时文件加原子替换，不创建共享 `current.json` 或其他全局指针；
   - 如果运行环境缺少 `session_id` 或 `run_dir`，或无法创建/读取会话缓存目录，则把这次已明确选择视为一次性操作：继续打开目标 workspace，但明确告知“会话状态不可持久化”，后续命令仍需再次显式选择；不写任何用户级或全局回退状态；
   - 通过 Obsidian CLI 打开该 workspace 的 `图谱/总览.md`；
   - 告知后续 compile/push/migrate 只有在当前会话缓存成功写入后才会默认作用于此 workspace；否则本次只作为非持久化选择。

如果没有 workspace，进入新建流程：要求用户输入名称，初始化 `工作区.md`、`原始资料/`、四类 `图谱/节点/`、任务根页 `图谱/节点/任务/任务-开发总任务.md`、`图谱/视图/`、`图谱/说明/` 和 `图谱/候选/` 结构，然后按同样的 workspace/focus 绑定规则写入当前会话缓存或报告本次选择不可持久化。不要猜测名称，也不要从新 workspace 的活动任务推断 `focus_task_id`。
