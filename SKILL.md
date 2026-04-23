---
name: workspace-sync
description: 跨设备同步 Claude Code 工作空间(对话摘要 + 涉及的 git 项目状态)。支持 Local/GitHub/GitLab/MinIO 四种存储后端,首次使用会引导配置,也支持通过 /workspace-sync config 随时重配。无论用户明确输入 /workspace-sync 命令,还是只是提到"换台设备继续工作""下班想回家接着弄""把今天的进展同步到云端""记录一下工作状态以便切换设备",都应进入本 skill。list 不只是查看,列出后立即引导用户选一个 workspace 继续工作,不要等用户手动再打一遍 pull。
---

# Workspace Sync

## 核心原则

- 这是一个默认**无仓库脚本依赖**的 skill。优先直接使用 shell、git、文件读写、HTTP API 和当前模型已有工具完成任务。
- 不要假设本仓库根目录下存在 `scripts/` 运行时脚本。即使仓库源码里曾经有过，也不应把它们当作执行入口。
- 只有当其他 skill 自己的 `workspace-sync.contract.json` 明确声明了 `export_command` / `import_command` 时，才调用**那个 skill 自己**的脚本。
- `list` 优先本地缓存，远端只做轻量补查。
- `push` / `pull` 的目标是恢复上下文和已提交代码指针，不搬运本地未提交改动。
- 默认要求同时保留：`conversation.jsonl`（完整对话）+ `summary.md`（可接手上下文）。缺失完整对话只能在用户明确同意降级时继续。

## 同步边界

会同步：

- `summary.md`
- `conversation.jsonl`（完整对话）
- `manifest.json`
- 每个项目的 `remote / upstream / branch / head`
- 其他 skill 显式声明为 `portable` 的状态

不会同步：

- 未提交改动
- 已提交但未 push 的本地提交
- `.gitignore` 忽略文件
- 未声明或声明为 `nonportable` 的 skill 状态
- 机器绑定缓存、锁、tmp、daemon 运行态、token

## 路径约定

以**当前实际安装并生效的 skill 目录**为准：

- `WS_SKILL_DIR=<当前实际使用的 workspace-sync skill 目录>`
- `CONFIG=$WS_SKILL_DIR/config.json`

`STATE_ROOT` 按下面顺序推断：

1. 如果 `WS_SKILL_DIR` 形如 `.../skills/workspace-sync`，则 `STATE_ROOT` 为它上两级目录
2. 否则优先看环境变量，例如 `CODEX_HOME`、`CLAUDE_HOME`
3. 否则在常见目录里找已存在的状态目录，例如 `~/.codex`、`~/.claude`

默认路径：

- `cache_dir` 为空时，使用 `$STATE_ROOT/workspace-cache`
- `local_paths_file` 为空时，使用 `$STATE_ROOT/skills/workspace-sync/local-paths.json`

不要把状态目录硬编码成某个固定 CLI。

## 配置文件

`config.json` 示例见 `templates/config.json.example`。核心字段：

```json
{
  "backend": "local",
  "local": {
    "path": "~/Dropbox/claude-workspaces"
  },
  "github": {
    "token": "ghp_xxxxxxxxxxxx",
    "repo": "owner/repo",
    "branch": "main"
  },
  "gitlab": {
    "host": "gitlab.com",
    "token": "glpat-xxx",
    "project_path": "group/repo",
    "branch": "main",
    "protocol": "https"
  },
  "minio": {
    "endpoint": "https://minio.example.com",
    "access_key": "xxx",
    "secret_key": "xxx",
    "bucket": "claude-workspaces",
    "prefix": "workspaces/",
    "mc_alias": "claude-workspace-sync"
  },
  "cache_dir": null,
  "local_paths_file": null,
  "scan_roots": [
    "D:/work",
    "D:/src"
  ]
}
```

`backend` 为空，或当前 backend 的必填字段缺失时，进入 `references/setup.md` 的配置流程。

## 工作空间结构

```text
<workspace-name>/
├── manifest.json
├── summary.md
├── conversation.jsonl
├── projects/
│   └── <project-name>/
│       └── meta.json
└── skill-states/
    └── <skill-name>/
        └── <state-id>/
            ├── manifest.json
            └── ...
```

`manifest.json` 至少应包含：

```json
{
  "name": "feature-import",
  "version": 3,
  "previous_version": 2,
  "conversation_id": "71fc3842-...",
  "source_device": "office-pc",
  "source_cwd": "D:/work/shanks-manage",
  "created_at": "2026-04-15T18:00:00+08:00",
  "updated_at": "2026-04-17T10:30:00+08:00",
  "projects": [],
  "skill_states": [],
  "conversation_saved": true,
  "conversation_status": "full"
}
```

其中：

- `conversation_saved`: 是否保存了完整 `conversation.jsonl`
- `conversation_status`: `full|missing_by_env|missing_by_user_opt_in`

## workspace 名称校验

所有涉及 `WS_NAME` 的动作都先做这组校验：

```bash
validate_ws_name() {
  local name="$1"
  local bad_chars='[[:space:][:cntrl:]/\\<>:"|?*]'
  [[ -n "$name" ]] || return 1
  [[ "$name" != "." && "$name" != ".." ]] || return 1
  [[ ! "$name" =~ $bad_chars ]] || return 1
}
```

非法名称直接报错并停止，不做任何写操作。

## 项目路径映射

不同设备上的同一个仓库，本地路径可能完全不同。恢复项目时不要依赖源设备路径，要依赖：

- 规范化后的 git remote
- `local-paths.json`
- `scan_roots`

remote key 规范化规则：

1. 去掉协议头，例如 `https://`、`ssh://`
2. 去掉用户信息，例如 `git@`
3. host 转小写
4. 去掉结尾 `.git`
5. 把 `host:path` 统一成 `host/path`

例如：

- `git@gitlab.yc.com:ukon/shanks-manage.git`
- `ssh://git@gitlab.yc.com/ukon/shanks-manage.git`
- `https://gitlab.yc.com/ukon/shanks-manage.git`

都归一到：

```text
gitlab.yc.com/ukon/shanks-manage
```

`local-paths.json` 结构：

```json
{
  "version": 1,
  "projects": {
    "gitlab.yc.com/ukon/shanks-manage": {
      "path": "D:/work/ukon/shanks-manage",
      "repo_name": "shanks-manage",
      "last_verified_at": "2026-04-16T10:00:00+08:00"
    }
  }
}
```

## push

详细步骤见 `action/push.md`。

## pull

详细步骤见 `action/pull.md`。

## list

详细步骤见 `action/list.md`。

## config

详细步骤见 `action/config.md`。

## clean

详细步骤见 `action/clean.md`。

## Skill State 同步

通过 `docs/skill-state-contract.md` 的标准接口完成。

导出顺序：

1. 找到本次 workspace 涉及的 skill
2. 读取对应 skill 目录下的 `workspace-sync.contract.json`
3. 只处理 `portability=portable` 的 state
4. 优先使用 `sync_paths`
5. 只有 contract 明确给了 `export_command` / `import_command` 时，才调用该 skill 自己的命令

状态值：

- `exported` / `restored`
- `skipped`
- `not_exported`
- `deferred`

`workspace-sync` 不猜其他 skill 的私有目录结构。

## Backend 实现

接口规范见 `references/backend-interface.md`。

- Local: `references/local.md`
- GitHub: `references/github.md`
- GitLab: `references/gitlab.md`
- MinIO: `references/minio.md`

## 暂不实现

- S3 backend
- workspace 历史版本浏览与回滚
