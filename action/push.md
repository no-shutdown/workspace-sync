# push

## 命令

```bash
/workspace-sync push <workspace-name>
```

## 目标

把当前工作上下文保存成一个可在另一台设备恢复的 workspace。

## 执行步骤

### Step 1: 校验名称与配置

- 按 `SKILL.md` 的 `validate_ws_name` 校验 `WS_NAME`
- 读取当前实际生效的 `config.json`
- `backend` 为空或缺字段时，转入 `references/setup.md`

### Step 2: 确认本次涉及的项目

**三个来源全部检查，合并去重**（不因找到一个就停止）：

1. 用户在命令中明确提到的仓库
2. 当前 cwd 所在 git 仓库（不在任何 git 仓库内则跳过）
3. 当前对话中实际改动过的仓库——扫描对话里出现的分支名、仓库名、文件路径等线索

不要为了"自动检测"去跑复杂脚本；用已有上下文（文件路径、分支名、commit 记录）推断即可。

**强制确认**：无论候选列表有几个项目，都必须把识别结果展示给用户确认，再继续。格式示例：

> 检测到以下项目涉及本次 workspace，请确认是否完整：
> - `shanks-manage-frontend`（当前 cwd，branch: dev-xinlin.huang-46）
> - `shanks-manage`（对话中有改动，branch: dev-xinlin.huang-361）
>
> 是否还有遗漏？

项目列表为空时，按"纯讨论模式"继续。

### Step 3: 收集并校验每个项目的 git 指针

对每个项目直接用标准 git 命令读取：

- `remote.origin.url`
- 当前分支
- upstream
- `HEAD`
- 工作区是否干净
- 本地与 upstream 是否同步

默认保守规则：

- 有未提交改动：停止
- 没有 upstream：停止
- ahead / behind upstream：停止

不要把脏代码当作可恢复状态写进 workspace。

### Step 4: 生成 `summary.md`

`summary.md` 必须让另一个从未参与当前对话的人也能接上工作，且必须包含以下固定章节：

1. 整体目标与验收标准
2. 背景、约束与风险边界
3. 讨论脉络（按时间顺序）
4. 关键决策（含备选方案和放弃原因）
5. 每个项目当前停点（分支、HEAD、已完成、进行中、阻塞）
6. 未决问题与待确认事项
7. 下一步最具体动作（微观，可直接执行）
8. 所属 Epic 与上下游任务（宏观全景）

**章节 8 说明**：

这一章节回答”这个 workspace 是更大目标的哪一块”，以及”完成后下一步要做什么”。

必须包含：

- **所属 Epic / 里程碑**：这个 workspace 属于哪个更大任务？写出名称或 issue 链接（例如 Epic #48「招聘域重构」）
- **本 workspace 定位**：是 Epic 的第几个 Task？负责哪个子问题？
- **Epic 已完成**：在本 workspace 之前，Epic 里哪些 task 已经做完了（包含其他 workspace 或已关闭 issue）
- **Epic 待完成**：本 workspace 之后，Epic 里还有哪些 task 尚未开始或进行中，按优先级列出（写 issue 编号 + 一句话描述）
- **下一个 workspace 的入口**：完成本 workspace 验收标准后，直接可以开始的下一件事是什么

如果 Epic 范围在对话中未明确提到：
- 优先查 GitLab/GitHub issue tracker（如果有项目配置）
- 其次询问用户”这个任务属于更大的 epic 或 milestone 吗”
- 确实无上下游时，写”独立任务，无 Epic 关联”，不允许留空

质量门槛（默认强制）：

- 纯讨论模式：不少于 `60` 行有效内容
- 涉及项目模式：不少于 `100` 行有效内容
- “下一步最具体动作”（章节 7）必须至少包含 `1` 条可直接执行的命令或文件级操作
- “所属 Epic 与上下游任务”（章节 8）必须列出 Epic 待完成任务，不允许只写”待确认”或留空
- 不允许只写笼统结论；每个章节都要有可验证的事实或决定

如果这是更新已有 workspace：

- 保留历史背景与已确认决策
- 追加本次新增讨论（按时间顺序）
- 替换”进行中 / 下一步”为当前真实状态
- 同步更新章节 8 的 Epic 已完成/待完成状态

### Step 5: 读取远端基线版本

调用当前 backend 的 `read_version(WS_NAME)`，得到：

- `CURRENT_REMOTE_VERSION`（workspace 不存在时为 `0`）
- `CURRENT_REMOTE_CREATED_AT`（workspace 不存在时为空）

后续步骤凭此计算 `NEXT_VERSION = CURRENT_REMOTE_VERSION + 1`。

### Step 6: 生成 `manifest.json`

至少写入：

- `name`
- `version = NEXT_VERSION`
- `previous_version = CURRENT_REMOTE_VERSION`
- `conversation_id`
- `source_device`
- `source_cwd`
- `created_at`：首次 push 时 = now；更新已有 workspace 时保留 `CURRENT_REMOTE_CREATED_AT`
- `updated_at = now`
- `projects`
- `skill_states`
- `conversation_saved`：`true|false`
- `conversation_status`：`full|missing_by_env|missing_by_user_opt_in`

### Step 7: 保存 `conversation.jsonl`

默认要求保存完整对话文件 `conversation.jsonl`：

- 能读取会话备份文件时，必须复制完整文件到 workspace
- 读取失败时，默认停止 `push`，并向用户说明失败原因
- 仅当用户明确接受“降级保存（无完整对话）”时，才允许继续

降级保存时必须同时满足：

- `manifest.json` 标记 `conversation_saved=false`
- `manifest.json` 标记 `conversation_status=missing_by_user_opt_in`
- `summary.md` 顶部显式声明“本版本缺失完整对话文件，仅供临时交接”

### Step 8: 导出 portable skill states

对本次涉及到的 skill：

1. 查找 `workspace-sync.contract.json`
2. 只处理 `portability=portable` 的 state
3. 优先按 `sync_paths` 复制或打包
4. 只有 contract 明确要求时，才调用该 skill 自己的 `export_command`

不要依赖 `workspace-sync` 仓库自己的 runner 脚本。

### Step 9: 组装 staging 目录

把 `summary.md`、`manifest.json`、`projects/`、`skill-states/` 整理到一个临时 `STAGE_DIR`，准备上传。
`conversation.jsonl` 默认必须存在；只有在 Step 7 明确进入降级保存时才允许缺失。

### Step 10: 并发校验

再次调用 backend 的 `read_version(WS_NAME)`。

如果远端版本已不等于 Step 5 读到的 `CURRENT_REMOTE_VERSION`，向用户说明冲突并确认是否继续。

### Step 11: 上传到 backend

调用当前 backend 的 `push(WS_NAME, STAGE_DIR, NEXT_VERSION)`：

- Local: `references/local.md`
- GitHub: `references/github.md`
- GitLab: `references/gitlab.md`
- MinIO: `references/minio.md`

### Step 12: 展示结果

至少汇报：

- workspace 名称
- backend
- 版本号
- 涉及项目数
- `conversation.jsonl` 是否成功保存（是否为降级保存）
- skill-state 导出结果

并提醒用户在另一台设备执行：

```bash
/workspace-sync pull <workspace-name>
```
