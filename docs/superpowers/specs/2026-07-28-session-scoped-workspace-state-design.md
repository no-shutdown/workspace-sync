# 会话级 workspace 状态缓存设计

- 状态：accepted
- 日期：2026-07-28
- 基于：当前 workspace 选择只保存在本地上下文、允许会话选择聚焦任务

## 背景

当前 `workspace-sync` 把 `current_workspace_id` 和
`current_workspace_name` 放在 CLI 状态目录下的共享 `local-state.json`。这在单会话使用时可以工作，但多个 AI 会话同时运行时会产生竞态：会话 A 选择 workspace A，会话 B 选择 workspace B，B 会覆盖共享指针，A 后续的 `compile` 或 `push` 可能误操作 workspace B。

workspace 内容仍然属于共享知识库 Git 仓库；需要隔离的是“本次会话默认操作哪个 workspace”以及“本次会话聚焦哪个任务”。

## 目标

- 将当前 workspace 和会话焦点任务改为会话级状态。
- 允许同一运行目录下的多个会话同时绑定不同 workspace。
- 将会话缓存放在当前运行目录的 `.workspace-sync-cache` 下。
- 保留用户/设备级知识库连接配置和 `project_paths`。
- 让缺失、损坏或无效的会话状态安全失败，不根据旧指针或名称猜测 workspace。
- 不修改用户项目的 `.gitignore` 或 `.git/info/exclude`。

## 非目标

- 不复制 workspace 内容，不为每个会话创建知识库副本。
- 不把会话缓存提交到知识库 Git，也不让它成为 Obsidian 内容。
- 不改变 workspace、节点、任务或关系的共享事实模型。
- 不自动清理会话缓存；缓存清理由用户自行决定。
- 不要求 `workspace-sync` 自动修改代码项目的 Git 忽略配置。

## 设计

### 1. 状态分层

状态分为三层：

| 层级 | 内容 | 存储位置 | 作用域 |
| --- | --- | --- | --- |
| 知识库事实 | workspace、节点、任务、关系、原始资料、项目支撑记录 | 配置的知识库 Git 仓库 | 所有会话共享 |
| 用户/设备配置 | 知识库 URL、分支、本机 Vault 路径、Obsidian Vault 名称、`project_paths` | CLI 本地配置和设备状态文件 | 用户/设备共享 |
| 会话状态 | 当前 workspace、焦点任务、会话临时状态 | 当前运行目录 `.workspace-sync-cache` | 单个会话 |

用户级状态文件不再承担当前 workspace 指针。旧文件中的 `current_workspace_id` 和 `current_workspace_name` 只作为历史字段保留并忽略；`project_paths` 继续保留和使用。

### 2. 会话缓存位置和格式

运行环境向 Skill 提供当前会话的 `session_id` 和会话启动时的当前运行目录 `run_dir`。缓存路径固定为：

```text
<run_dir>/.workspace-sync-cache/sessions/<session-id>.json
```

例如：

```text
/Users/ocean/project/.workspace-sync-cache/sessions/session-A.json
```

缓存文件只保存会话选择，不保存图谱事实：

```json
{
  "version": 1,
  "session_id": "session-A",
  "workspace_id": "ws-20260727-abc123",
  "workspace_name": "数据导入迭代",
  "focus_task_id": null
}
```

规则如下：

- `workspace_id` 是唯一身份来源；`workspace_name` 只是显示缓存。
- 每次依赖知识库事实的命令都通过 `workspace_id` 回到该 workspace 的 `工作区.md` 校验名称和生命周期。
- `focus_task_id` 只影响当前会话的上下文装配，不修改任务状态或共享的“当前任务”。`list`/`pull` 绑定 workspace 时，只有缓存的 `workspace_id` 等于所选 workspace，且该焦点 ID 已在所选 workspace 中验证为正式 `任务`，才保留 `focus_task_id`；切换 workspace 时清为 `null`，除非本次命令明确提供了所选 workspace 中有效的替代焦点。无效焦点清除并告知用户随后选择，不能跨 workspace 搬运或推断。
- `session_id` 必须经过路径安全校验，不能包含路径分隔或路径穿越片段。
- 写入会话文件时使用临时文件加原子替换，避免同一会话的并发写入留下半个 JSON。
- 不创建共享的 `current.json`，不同会话永远不能写同一个默认指针。

会话启动时确定 `run_dir`；同一会话后续命令继续使用这个目录，即使知识库 Vault 路径或当前代码项目路径不同，也不把缓存迁移到知识库目录。

### 3. session ID 运行时契约

`session_id` 和 `run_dir` 是调用方运行上下文的一部分，不由 workspace 名称、项目名称或时间戳推断。

- 如果运行环境能提供有效的 `session_id` 和 `run_dir`，Skill 使用它们定位缓存文件。
- 如果运行环境无法提供 `session_id` 或 `run_dir`，不能回退到用户级 `current_workspace` 或其他全局指针。
- 缺少 `session_id` 或 `run_dir` 时，经验证的显式 workspace 可以执行一次非持久化操作；该操作不写会话缓存、用户级状态或其他回退状态，后续命令仍需显式指定 workspace，直到运行环境提供有效的会话上下文。既没有有效会话上下文也没有显式 workspace 时停止。
- 只有 `session_id` 和 `run_dir` 均有效且会话缓存可写时，显式 workspace 覆盖才可以更新会话缓存；无法创建/读取缓存目录时，对已经验证的显式 workspace 继续一次非持久化操作并报告会话状态不可持久化，不创建用户级替代缓存。

### 4. 命令行为

#### `config`

只配置知识库连接、分支、本机 Vault 和设备级路径信息，不设置或修改任何会话的当前 workspace。

#### 选择 workspace 前的预边界发现

在当前会话 workspace 尚未建立时，`list`/`pull` 只允许通过 Obsidian CLI 列出 Vault 根目录候选文件夹，并读取候选 `工作区.md` 的 `workspace_id`、显示名称、生命周期和 `updated_at` 控制元数据供用户明确选择。这些元数据不属于知识库事实；选择前不得读取候选 workspace 的图谱、正文、links/backlinks/files/search、任务、架构或其他上下文，也不得写会话缓存、全局指针或其他 fallback state。

用户选择后，必须重新读取所选 `工作区.md`，验证其稳定 `workspace_id` 与选择目标一致；验证通过前不得打开总览、执行焦点检查或装配 workspace 上下文。验证通过后才建立 workspace 边界并执行正常的 workspace-scoped reads；无有效会话上下文时仍按显式 workspace 的一次性非持久化规则处理。

#### `list`

通过 Obsidian CLI 列出本地 workspace。用户选择后，只有在缓存的 `workspace_id` 等于所选 workspace 且缓存焦点已验证为该 workspace 的正式 `任务` 时，才保留 `focus_task_id`；切换 workspace 时清为 `null`，除非本次命令明确提供有效的替代焦点。无效焦点清除并报告 warning，告诉用户可以随后选择新的焦点，不能推断。只有 `session_id`、`run_dir` 均有效且会话缓存可写时，才将稳定 `workspace_id`、显示名称和按上述规则确定的焦点写入当前会话缓存；否则本次选择仅作为一次性、非持久化操作，不写任何回退状态，并打开该 workspace 的 `图谱/总览.md`。

#### `pull [工作区名称]`

先按现有安全 Git 流程同步知识库。指定名称时绑定该 workspace；未指定时让用户选择。绑定时只有在缓存的 `workspace_id` 等于所选 workspace 且缓存焦点已验证为该 workspace 的正式 `任务` 时，才保留 `focus_task_id`；切换 workspace 时清为 `null`，除非本次命令明确提供有效的替代焦点。无效焦点清除并报告 warning，不能跨 workspace 搬运或推断。同步和选择完成后，仅在 `session_id`、`run_dir` 均有效且会话缓存可写时更新当前会话缓存；否则本次操作仅作为一次性、非持久化操作，不写任何回退状态，并打开接手入口。

#### `compile`、`push`、`migrate`

- 默认只读取当前会话缓存。
- 缓存不存在、无法解析、workspace 不存在或 workspace 身份校验失败时停止并要求选择。
- 不读取旧用户级 `current_workspace_*`。
- 支持显式 workspace 作为一次性覆盖；只有 `session_id`、`run_dir` 均有效且会话缓存可写时，覆盖操作成功后才可以更新当前会话缓存；否则本次操作仅作为一次性、非持久化操作，不写用户级、全局或其他回退状态。

所有默认读取和写入仍限制在选定 workspace。生成页面、节点关系、Git 提交范围和远端同步规则不因缓存位置改变。

### 5. 项目路径解析

`project_paths` 仍是用户/设备级默认映射，不写入会话缓存。为避免两个会话使用同一代码项目的不同 worktree 时误用路径，解析优先级为：

1. 用户在本次操作中明确提供的路径；
2. 当前会话的 `run_dir` 或当前 cwd 中与 remote 匹配的代码仓库；
3. 用户级 `project_paths`；
4. 无法唯一定位时要求用户确认。

本次会话使用的路径选择不覆盖其他会话，也不自动修改用户级映射。

### 6. 旧状态兼容

现有 `state_file` 配置继续指向用户/设备级状态文件，但其语义收窄为设备配置和 `project_paths`。迁移时：

- 保留 `project_paths` 和其他设备级配置；
- 忽略 `current_workspace_id`、`current_workspace_name`；
- 不把旧全局指针自动复制到任何会话缓存；
- 首次执行 `list`、`pull` 或显式 workspace 命令时建立会话绑定。

这样不会因为旧状态文件残留而把 workspace A 错误带入新会话。

### 7. 并发与错误处理

- 会话 A 和 B 即使在同一 `run_dir`，也只操作自己的 session 文件。
- 缓存 JSON 损坏、session ID 非法、workspace 缺失或 `工作区.md` 的 ID 不匹配时，只报告错误并要求重新选择；不按文件名或最近更新时间猜测。
- 同一 workspace 被多个会话选中是允许的；知识库 Git 的远端变化、冲突和 dirty 处理继续遵守既有安全规则。
- 缓存目录可能位于 Git 项目中；Skill 不修改任何 Git ignore 配置，用户自行决定是否忽略 `.workspace-sync-cache`。

## 数据流

```text
运行环境提供 session_id + run_dir
        │
        ▼
读取 <run_dir>/.workspace-sync-cache/sessions/<session-id>.json
        │
        ├─ 缺失/损坏/无效 ──► 停止并要求选择
        │
        ▼
用 workspace_id 校验知识库中的 工作区.md
        │
        ▼
仅读取/写入当前 workspace
        │
        ▼
仅在 session_id + run_dir 有效且缓存可写时，按需原子更新当前会话缓存；否则显式操作保持一次性、非持久化
```

知识库事实仍通过 Obsidian CLI 和 Git 仓库存取；会话缓存只负责选择边界，不成为第二份事实来源。

## 验收标准

- 同一运行目录的两个会话可以分别绑定 workspace A 和 workspace B；两者执行 `compile`、`push`、`migrate` 时不互相读取或修改默认 workspace。
- 新会话没有缓存时不读取旧全局 workspace，必须通过 `list`、`pull` 或显式指定 workspace 建立边界。
- 旧 `local-state.json` 的 `current_workspace_*` 不再生效，`project_paths` 仍可用于默认路径解析。
- 缓存缺失、JSON 损坏、workspace 被删除、ID 不匹配或 session ID 非法时安全停止，不猜测、不回退到其他会话。
- `config` 不改变任何会话的 workspace。
- 显式 workspace 在无 `session_id` 或 `run_dir` 时可以完成一次非持久化操作，但不会创建会话缓存、用户级状态或其他共享回退；只有两者有效且缓存可写时才更新当前会话缓存。
- 不修改用户项目的 `.gitignore` 或 `.git/info/exclude`。
- 相关 Skill、命令文档、ADR 和示例配置不再声称用户级状态文件保存共享的 current workspace。
- 文档变更通过 Markdown diff 检查、shell 语法检查和源文件/活动副本一致性检查。

## 取舍

会话缓存放在当前运行目录，而不是用户目录或知识库目录，能让运行环境自然携带工作上下文，也避免不同运行目录之间共享当前 workspace。代价是同一会话必须保持其 `run_dir` 和 `session_id` 可识别；运行环境无法提供这两个信息时，只能退化为显式 workspace 的单次操作，不能安全地恢复隐式上下文。
