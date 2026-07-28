# 当前 workspace 和聚焦任务改为会话级缓存

---
status: accepted
---

共享知识库事实、用户/设备配置和 `project_paths` 继续保持原有边界；变化的是“当前 workspace”和“当前会话聚焦任务”的默认来源。它们改为保存在当前运行目录下的会话文件：

```text
<run_dir>/.workspace-sync-cache/sessions/<session-id>.json
```

会话缓存只保存 `version`、`session_id`、`workspace_id`、`workspace_name` 和 `focus_task_id`。所有依赖知识库事实的默认读取都先解析该文件，再用 `workspace_id` 回到知识库中的 `工作区.md` 做稳定身份校验。

没有 `session_id` 时，不回退到用户级全局 current workspace 指针；调用方只能执行显式 workspace 的单次操作。`.workspace-sync-cache` 是否加入 Git ignore 由用户自行决定，skill 不自动修改 `.gitignore` 或 `.git/info/exclude`。

本 ADR 补充并取代 ADR-0045 中“本机指针由共享本地状态文件承载”的实现语义，但不删除历史 ADR：ADR-0045 仍保留“当前 workspace 不进入共享知识库”的边界决策；本 ADR 只把默认指针的载体从设备级共享文件收窄为会话级缓存。

## Consequences

- 同一 `run_dir` 下的多个会话可以绑定不同 workspace，不会互相覆盖默认 workspace 或聚焦任务。
- 旧 `local-state.json` 中的 `current_workspace_*` 只作为历史字段保留并忽略；`project_paths` 继续作为用户/设备级路径映射。
- 缓存缺失、损坏、workspace 删除、ID 不匹配、session ID 非法或缺少 `run_dir` 时，相关命令安全停止并要求重新选择，不猜测、不跨会话回退。
- `config` 不再承担当前 workspace 指针写入；`list`、`pull` 和显式 workspace 成功后可以更新当前会话缓存。
