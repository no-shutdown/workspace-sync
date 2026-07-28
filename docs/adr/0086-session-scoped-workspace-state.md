# 当前 workspace 和聚焦任务改为会话级缓存

---
status: accepted
---

共享知识库事实、用户/设备配置和 `project_paths` 继续保持原有边界；变化的是“当前 workspace”和“当前会话聚焦任务”的默认来源。它们改为保存在当前运行目录下的会话文件：

```text
<run_dir>/.workspace-sync-cache/sessions/<session-id>.json
```

会话缓存只保存 `version`、`session_id`、`workspace_id`、`workspace_name` 和 `focus_task_id`。所有依赖知识库事实的默认读取都先解析该文件，再用 `workspace_id` 回到知识库中的 `工作区.md` 做稳定身份校验。

`focus_task_id` 严格绑定同一缓存中的 `workspace_id`，只能指向该 workspace 中经验证的正式 `任务` 节点。保留焦点前必须同时匹配 workspace ID 和任务校验；切换 workspace 时清为 `null`，除非本次命令明确提供了所选 workspace 中有效的替代焦点。`.workspace-sync-cache` 是否加入 Git ignore 由用户自行决定，skill 不自动修改 `.gitignore` 或 `.git/info/exclude`。

ADR-0045 建立的是当前 workspace 只属于本机/当前会话上下文、不进入共享知识库的历史边界，并未规定由某个共享本地状态文件承载的具体实现。本 ADR 保留该 local-only 边界，并在实现层面取代 ADR-0045 未具体规定的本地 current pointer 机制，统一使用当前运行目录下的会话缓存。

与 ADR-0062 的关系是：`list` 仍只通过 Obsidian CLI 读取本地 Vault 中的 workspace 并让用户选择，不执行远端同步；该 local-Vault-only list/selection 边界保持不变，但选择结果现在绑定当前会话缓存，而不是绑定一个未具体规定的设备级 current pointer。

与 ADR-0085 的关系仅限于焦点来源优先级：本 ADR 仅取代其旧的焦点来源优先级表述，保留其有界上下文闭包设计。当前优先级固定为“用户明确指定焦点 > 当前会话中已验证且作用域为所选 workspace 的 `focus_task_id` > 当前对话明确确认 > `总览.md` 活动任务”。这只是澄清会话状态的来源，不修改 ADR-0085 的历史文本。

## Consequences

- 同一 `run_dir` 下的多个会话可以绑定不同 workspace，不会互相覆盖默认 workspace 或聚焦任务。
- 旧 `local-state.json` 中的 `current_workspace_*` 只作为历史字段保留并忽略；`project_paths` 继续作为用户/设备级路径映射。
- 缓存缺失、损坏、workspace 删除、ID 不匹配、session ID 非法或其他 workspace 身份无效时，依赖默认会话边界的行为安全停止并要求重新选择，不猜测、不跨会话回退。如果 `session_id` 或 `run_dir` 不可用，经验证的显式 workspace 可以完成一次非持久化操作，不写任何回退状态；既没有有效会话上下文也没有显式 workspace 时停止。
- `config` 不再承担当前 workspace 指针写入；`list`、`pull` 或显式 workspace 成功后，只有在 `session_id` 和 `run_dir` 均有效且会话缓存可写时才更新当前会话缓存；否则本次显式操作仅作为一次性、非持久化操作，不写用户级、全局或其他回退状态。
