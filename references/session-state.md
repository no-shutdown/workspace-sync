# 会话状态缓存契约

## 运行时输入

会话级 workspace 状态依赖运行环境提供两个值：

```text
session_id + run_dir 由运行环境提供
cache = <run_dir>/.workspace-sync-cache/sessions/<session-id>.json
```

- `session_id` 是当前会话的稳定标识，不由 workspace 名称、项目名称或时间戳推断。
- `run_dir` 是会话启动时确定的当前运行目录；后续命令继续使用这个目录，即使 Vault 路径或当前代码项目路径变化，也不迁移缓存位置。

## 缓存文件格式

会话缓存只保存当前会话的选择边界，不保存图谱事实：

```json
{
  "version": 1,
  "session_id": "session-A",
  "workspace_id": "ws-20260727-abc123",
  "workspace_name": "数据导入迭代",
  "focus_task_id": null
}
```

- `workspace_id` 是唯一身份来源。
- `workspace_name` 只是显示缓存；每次依赖知识库事实的命令都必须回到目标 workspace 的 `工作区.md`，按 `workspace_id` 校验名称和生命周期。
- `focus_task_id` 只影响当前会话的上下文装配，不修改共享任务状态或全局“当前任务”。

## 安全与并发要求

- `session_id` 必须通过路径安全校验，不能包含路径分隔符、`..` 或其他路径穿越片段。
- 写入会话缓存时必须使用临时文件加原子替换，避免留下半个 JSON。
- 不创建共享的 `current.json` 或其他全局当前指针。
- 两个会话可以选择同一个 workspace，但不能共享同一个会话文件；同一 `run_dir` 下的不同会话只读写各自的 `<session-id>.json`。

## 默认读取与安全失败

`compile`、`push`、`migrate` 等依赖知识库事实的默认行为只读取当前会话缓存，或接受显式 workspace 作为单次覆盖。

遇到以下情况时必须安全停止并要求重新选择，不能根据旧指针、文件名、最近更新时间或其他会话猜测 workspace：

- 缓存文件不存在；
- 缓存 JSON 损坏或无法解析；
- workspace 已不存在；
- `工作区.md` 中的稳定 ID 与缓存 `workspace_id` 不匹配；
- `session_id` 非法。

如果运行环境没有 `session_id`，不能回退到用户级 `current_workspace_*` 或其他共享默认值。此时用户可以显式指定 workspace 完成单次操作，但该操作不写共享缓存；后续命令仍需再次显式指定，直到运行环境提供稳定的会话 ID。

如果没有 `run_dir`，或无法创建/读取 `<run_dir>/.workspace-sync-cache/sessions/`，报告“会话状态不可持久化”；不创建用户级替代缓存。

## 旧状态兼容

设备级 `local-state.json` 继续存在，但只保存用户/设备范围的信息：

```json
{
  "version": 1,
  "project_paths": {
    "gitlab.example.com/team/api": "C:/work/api"
  }
}
```

- 保留 `project_paths` 和其他设备级配置。
- 旧 `current_workspace_id`、`current_workspace_name` 只作为历史字段保留并忽略。
- 不把旧全局指针自动复制到任何会话缓存。

## 项目路径解析优先级

项目路径解析顺序固定为：

1. 用户在本次操作中明确提供的路径；
2. 当前会话的 `run_dir` 或当前 cwd 中与 remote 匹配的代码仓库；
3. 用户/设备级 `project_paths`；
4. 无法唯一定位时要求用户确认。

本次会话的路径选择不覆盖其他会话，也不自动改写用户级映射。
