---
name: workspace-sync
description: 跨设备同步 Claude Code 工作空间(对话摘要 + 涉及的 git 项目状态)。支持 GitLab 或 MinIO 两种存储后端,首次使用会引导配置。无论用户明确输入 /workspace-sync 命令,还是只是提到"换台设备继续工作""下班想回家接着弄""把今天的进展同步到云端""记录一下工作状态以便切换设备",都应进入本 skill。list 不只是查看,列出后立即引导用户选一个 workspace 继续工作,不要等用户手动再打一遍 pull。
---

# Workspace Sync

## 概述

把当前对话的工作状态(对话摘要 + 涉及的所有 git 项目的 branch/upstream/HEAD)打包上传到云端。另一台设备 pull 下来后,Claude 读摘要就能恢复上下文;代码侧只恢复到已提交并已推送的状态,不搬运本地未推/未提交改动。

自动适配三种场景(不需要区分模式):
- **纯讨论**:projects 为空,只存摘要和对话
- **单项目**:一次对话只改了一个 git 仓库
- **多项目**:一次对话修改了前端+后台等多个仓库

## 存储后端

支持两种,二选一(首次使用时配置):

| 后端 | 前置条件 |
|------|---------|
| **GitLab** | 一个已存在的空仓库 + 有 read/write 权限的 Personal Access Token |
| **MinIO** | 一个已存在的 bucket + 有读写权限的密钥 + 本机已装 `mc` 客户端 |

skill 不会自动创建仓库或 bucket,目标不存在时直接报错。

## 配置文件

`~/.claude/skills/workspace-sync/config.json`(参考 `templates/config.json.example`):

```json
{
  "backend": "gitlab",
  "gitlab": {
    "host": "your.gitlab.com",
    "token": "glpat-xxx",
    "project_path": "namespace/repo-name",
    "branch": "main"
  },
  "minio": {
    "endpoint": "https://minio.example.com",
    "access_key": "xxx",
    "secret_key": "xxx",
    "bucket": "claude-workspaces",
    "prefix": "workspaces/",
    "mc_alias": "claude-workspace-sync"
  },
  "cache_dir": "~/.claude/workspace-cache",
  "local_paths_file": "~/.claude/skills/workspace-sync/local-paths.json",
  "scan_roots": ["D:/work", "D:/src"]
}
```

`backend` 为 `null` 或对应 backend 必填字段为空时,进入首次配置流程(见 `references/setup.md`)。

## 工作空间目录结构

```
<workspace-name>/
├── manifest.json
├── summary.md
├── conversation.jsonl
├── projects/
│   └── <project-name>/
│       └── meta.json
└── skill-states/              (含 skill 状态时才有)
    └── <skill-name>/
        └── <scope>-<state-name>/
            ├── manifest.json
            └── state.tgz
```

## 关键数据格式

### manifest.json

```json
{
  "name": "存量名单导入重构",
  "version": 3,
  "previous_version": 2,
  "conversation_id": "71fc3842-...",
  "source_device": "company-pc",
  "source_cwd": "D:\\A-ukon-work\\shanks-manage",
  "created_at": "2026-04-15T18:00:00+08:00",
  "updated_at": "2026-04-17T10:30:00+08:00",
  "projects": [
    {
      "name": "shanks-manage",
      "remote": "git@your.gitlab.com:namespace/your-project.git",
      "upstream": "origin/feature/import",
      "branch": "feature/import",
      "head": "abc123"
    }
  ],
  "skill_states": []
}
```

字段说明:
- `created_at`: workspace 首次创建时间,不随版本更新变化
- `updated_at`: 每次 push 时更新为当前时间,list 命令展示此字段
- `version` / `previous_version`: 乐观并发控制,每次 push 递增

### summary.md 格式

```markdown
# 工作空间:<name>

## 整体目标
<1-2 句>

## 讨论脉络
<纯讨论场景:共识/待议/决策>

## 项目:shanks-manage
- **分支**:feature/import
- **已完成**:...
- **进行中**:(卡在哪)
- **下一步**:<必须具体,如"继续写 XXController">
- **关键文件**:path:line
```

### local-paths.json 格式

```json
{
  "version": 1,
  "projects": {
    "gitlab.yc.com/ukon/shanks-manage": {
      "path": "D:\\A-yc-work\\ukon\\shanks-manage",
      "repo_name": "shanks-manage",
      "last_verified_at": "2026-04-16T10:00:00+08:00"
    }
  }
}
```

remote key 用 `ws_normalize_remote`(来自 `scripts/workspace-sync-lib.sh`)规范化:去掉协议头/用户信息,host 转小写,去掉 `.git` 后缀,`host:path` 统一为 `host/path`。

---

# 通用执行入口

## Step 0: 加载配置 & 校验

```bash
WS_SKILL_DIR="$HOME/.claude/skills/workspace-sync"
CONFIG="$WS_SKILL_DIR/config.json"

BACKEND=$(python3 -c "
import json, sys
try:
    d = json.load(open('$CONFIG'))
    print(d.get('backend') or '')
except Exception:
    print('')
" 2>/dev/null || echo "")
```

`BACKEND` 为空或对应 backend 必填字段缺失 → 读取 `references/setup.md` 执行首次配置,完成后继续当前命令。

**validate_ws_name**(所有涉及 WS_NAME 的命令在操作前先调用):

```bash
validate_ws_name() {
  local name="$1"
  local bad_chars='[[:space:][:cntrl:]/\<>:"|?*]'
  [[ -n "$name" ]] || return 1
  [[ "$name" != "." && "$name" != ".." ]] || return 1
  [[ ! "$name" =~ $bad_chars ]] || return 1
}

validate_ws_name "$WS_NAME" || {
  echo "❌ 非法工作空间名称: $WS_NAME"
  echo "   支持中文命名,不允许空白、路径分隔符、控制字符或 Windows 非法文件名字符"
  exit 1
}
```

---

# Push 流程

> 详细步骤见 `action/push.md`

---

# Pull 流程

> 详细步骤见 `action/pull.md`

---

# List 流程

> 详细步骤见 `action/list.md`

---

# Clean 流程

> 详细步骤见 `action/clean.md`

---

# Skill State 同步

通过 `docs/skill-state-contract.md` 中的标准接口实现。

Push 时:遍历涉及的 skill,对 `portability=portable` 的 state 导出;
优先使用 `scripts/export-skill-states.sh` 统一编排。

Pull 时:读 manifest.skill_states,调用对应 skill 的 import;
优先使用 `scripts/import-skill-states.sh` 统一编排。

状态值:
- `exported` / `restored`: 成功
- `skipped`: 当前环境不满足
- `not_exported`: 该 workspace 未启用该 skill 同步
- `deferred`: 产物存在但目标设备未安装对应 skill

---

# 边界处理

| 情况 | 处理 |
|------|------|
| config 不完整 | 进入首次配置流程(`references/setup.md`) |
| GitLab token 无效(401) | 报错退出,提示重新配置 |
| GitLab 仓库不存在(404) | 报错退出,提示先去 GitLab 创建空仓库 |
| MinIO bucket 不存在 | 验证失败,提示先创建 bucket |
| mc 未安装(minio 后端) | 报错,给出三平台安装命令 |
| detect-projects 返回空 | 按纯讨论模式继续 |
| push 时项目有未提交改动 | 报错,要求先 commit/push |
| push 时项目无 upstream | 报错,要求先 `git push -u` |
| push 时与 upstream 不同步 | 报错,要求先同步代码 |
| push 时远端版本已变化 | 告警并询问是否基于最新版本继续提交 |
| 项目路径未映射(pull 时) | 交互询问用户,写入 local-paths.json |
| 记录的 head 不存在 | 跳过该项目并告知用户 |
| pull 时本地有未提交改动 | 跳过该项目,不覆盖当前工作区 |
| skill 未安装或不兼容 | 记为 skipped/deferred,不影响上下文恢复 |
| skill 无 contract | 记为 not_exported,不猜目录结构 |
| clean 目标不存在 | 提示 nothing to clean,不报致命错误 |
| workspace 名称非法 | 立即报错,不做任何操作 |

---

# Backend 实现

- GitLab: `references/gitlab.md`
- MinIO: `references/minio.md`

---

# 暂未实现

- GitHub / S3 后端
- workspace 版本历史浏览与回滚
