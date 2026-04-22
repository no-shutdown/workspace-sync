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

优先按下面顺序确定项目列表：

1. 用户明确提到的仓库
2. 当前 cwd 所在 git 仓库
3. 当前对话里最近实际改动过的仓库

不要为了"自动检测"优先去跑复杂仓库脚本；如果不确定，就先把识别结果展示给用户确认。

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

`summary.md` 必须让另一个从未参与当前对话的人也能接上工作，至少写出：

- 整体目标
- 背景与约束
- 讨论脉络
- 关键决策
- 每个项目当前停点
- 下一步最具体的动作

如果这是更新已有 workspace：

- 保留历史背景与已确认决策
- 追加本次新增讨论
- 替换"进行中 / 下一步"为当前真实状态

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

### Step 7: 保存 `conversation.jsonl`

如果当前环境能读到会话备份文件，就复制一份到 workspace。
如果当前环境拿不到原始对话文件，也要继续保存 `summary.md` 和 `manifest.json`，但需要明确说明缺失了原始 `conversation.jsonl`。

### Step 8: 导出 portable skill states

对本次涉及到的 skill：

1. 查找 `workspace-sync.contract.json`
2. 只处理 `portability=portable` 的 state
3. 优先按 `sync_paths` 复制或打包
4. 只有 contract 明确要求时，才调用该 skill 自己的 `export_command`

不要依赖 `workspace-sync` 仓库自己的 runner 脚本。

### Step 9: 组装 staging 目录

把 `summary.md`、`conversation.jsonl`（若有）、`manifest.json`、`projects/`、`skill-states/` 整理到一个临时 `STAGE_DIR`，准备上传。

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
- `conversation.jsonl` 是否成功保存
- skill-state 导出结果

并提醒用户在另一台设备执行：

```bash
/workspace-sync pull <workspace-name>
```
