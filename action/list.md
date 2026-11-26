# list

## 命令

```text
/workspace-sync list
```

## 目标

列出当前本地知识库根目录下的 workspace 文件夹，并在用户选择后将该 workspace 绑定到当前会话；启用且可用时通过 Obsidian 打开该 workspace 的 `图谱/总览.md`。

## 边界

- `list` 只读取本地 Vault，不执行 Git fetch、pull 或远端目录查询。
- 不读取其他 workspace 的图谱内容，只读取每个 workspace 的 `工作区.md` 元数据用于列表。
- 不自动选择 workspace；用户必须回复序号或名称。
- 归档 workspace 保留并显示，但标注 `archived`，不会默认当作活动 workspace。
- 默认通过 `<run_dir>/.workspace-sync-cache/sessions/<session-id>.json` 持久化当前会话选择；缺少、损坏或无法验证的会话缓存不能作为默认来源。缺少 `session_id` 或 `run_dir` 时，只有经验证的显式 workspace 选择可以本次生效，不创建共享缓存，也不回退到用户级 current workspace。

## 步骤

1. 读取本地配置和设备级状态，确认知识库路径；设备级状态只用于 `project_paths` 等本机信息，不读取 `current_workspace_*` 作为默认来源。
2. 在当前会话 workspace 尚未建立时，按 `references/markdown.md` 的预边界规则列出知识库根目录的一级文件夹，并对每个候选文件夹内的 `工作区.md` 只读取用于选择的控制元数据：稳定 `workspace_id`、显示名称、生命周期和 `updated_at`。这些元数据不属于知识库事实；用户选择并完成稳定 ID 验证前，不读取候选 workspace 的图谱页面、workspace 正文、links/backlinks/files/search 结果、任务、架构或其他上下文事实，也不写会话缓存或 fallback state。
3. 只保留控制元数据包含有效稳定 `workspace_id` 和生命周期的候选 workspace；这一步不替代用户选择。用户选择后重新读取所选 `工作区.md`，验证其稳定 `workspace_id` 与所选候选一致，验证失败则停止，不打开总览或读取 workspace 上下文。
4. 展示名称、生命周期、更新时间，例如：

   ```text
   1. 数据导入迭代     active    updated 2026-07-27
   2. 发布清理         paused    updated 2026-07-20
   3. 旧版迁移         archived  updated 2026-06-01
   ```

5. 提示用户回复序号或名称。用户选择后：
   - 先重新读取所选 workspace 的 `工作区.md`，验证稳定 `workspace_id` 与所选候选一致；只有验证通过后，才执行焦点校验、缓存绑定、打开总览或其他 workspace-scoped reads；不能用候选目录名或其他 workspace 事实替代稳定 ID 验证；
   - 读取当前会话缓存中已有的 `workspace_id`，并与所选 workspace 的稳定 `workspace_id` 比较。只有两者相同，且 `focus_task_id` 已在所选 workspace 中验证为正式 `任务` 节点时，才保留该焦点；不满足任一条件时不保留；
   - 切换 workspace 时将 `focus_task_id` 清为 `null`，除非本次命令明确提供了所选 workspace 中有效的替代焦点。缓存焦点无效时清除并报告 warning；告诉用户可以随后选择新的焦点，不能按名称、活动状态、最近更新时间或其他 workspace 推断；
   - 仅在 `session_id`、`run_dir` 均有效且会话缓存可写的有效会话上下文中，将稳定 `workspace_id`、显示名称和按上述规则确定的 `focus_task_id` 写入当前会话缓存；写入时使用临时文件加原子替换，不创建共享 `current.json` 或其他全局指针；条件不满足时按下一条无缓存分支处理；
   - 如果运行环境缺少 `session_id` 或 `run_dir`，或无法创建/读取会话缓存目录，则把这次已明确选择视为一次性操作：继续打开目标 workspace，但明确告知“会话状态不可持久化”，后续命令仍需再次显式选择；不写任何用户级或全局回退状态；
   - 已启用且可用时通过 Obsidian CLI 打开该 workspace 的 `图谱/总览.md`；浏览器入口为 `html`；
   - 告知后续 compile/push/migrate/html 只有在当前会话缓存成功写入后才会默认作用于此 workspace；否则本次只作为非持久化选择。

如果没有 workspace，进入新建流程：要求用户输入名称，初始化 `工作区.md`、`原始资料/`、四类 `图谱/节点/`、任务根页 `图谱/节点/任务/任务-开发总任务.md`、`图谱/视图/`、`图谱/说明/` 和 `图谱/候选/` 结构，然后按同样的 workspace/focus 绑定规则写入当前会话缓存或报告本次选择不可持久化。不要猜测名称，也不要从新 workspace 的活动任务推断 `focus_task_id`。
