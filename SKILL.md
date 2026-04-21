---
name: workspace-sync
description: 跨设备同步 Claude Code 工作空间(对话摘要 + 涉及的 git 项目状态)。支持 Local/GitHub/GitLab/MinIO 四种存储后端,首次使用会引导配置,也支持通过 /workspace-sync config 随时重配。无论用户明确输入 /workspace-sync 命令,还是只是提到"换台设备继续工作""下班想回家接着弄""把今天的进展同步到云端""记录一下工作状态以便切换设备",都应进入本 skill。list 不只是查看,列出后立即引导用户选一个 workspace 继续工作,不要等用户手动再打一遍 pull。
---

# Workspace Sync

## 概述

把当前对话的工作状态(对话摘要 + 涉及的所有 git 项目的 branch/upstream/HEAD)打包上传到云端。另一台设备 pull 下来后,Claude 读摘要就能恢复上下文;代码侧只恢复到已提交并已推送的状态,不搬运本地未推/未提交改动。

自动适配三种场景(不需要区分模式):
- **纯讨论**:projects 为空,只存摘要和对话
- **单项目**:一次对话只改了一个 git 仓库
- **多项目**:一次对话修改了前端+后台等多个仓库

## 存储后端

支持四种,选一即可(首次使用时配置):

| 后端 | 前置条件 |
|------|---------|
| **Local** | 本地目录,配合 Dropbox/OneDrive/iCloud 自动跨设备;零 API 配置 |
| **GitHub** | 一个已存在的仓库 + 有 repo scope 的 Personal Access Token |
| **GitLab** | 一个已存在的空仓库 + 有 read/write 权限的 Personal Access Token |
| **MinIO** | 一个已存在的 bucket + 有读写权限的密钥 + 本机已装 `mc` 客户端 |

skill 不会自动创建仓库/bucket/目录,目标不存在时直接报错。

## 配置文件

`<当前 CLI 状态目录>/skills/workspace-sync/config.json`(参考 `templates/config.json.example`):

```json
{
  "backend": "local",
  "local": {
    "path": "~/Dropbox/claude-workspaces"
  },
  "gitlab": {
    "host": "your.gitlab.com",
    "token": "glpat-xxx",
    "project_path": "namespace/repo-name",
    "branch": "main"
  },
  "github": {
    "token": "ghp_xxxxxxxxxxxx",
    "repo": "your-username/claude-workspaces",
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
  "cache_dir": null,
  "local_paths_file": null,
  "scan_roots": ["D:/work", "D:/src"]
}
```

`backend` 为 `null` 或对应 backend 必填字段为空时,进入首次配置流程(见 `references/setup.md`)。

补充说明:

- `cache_dir` 为 `null` 或空时,默认使用当前 CLI 状态目录下的 `workspace-cache`
- `local_paths_file` 为 `null` 或空时,默认使用当前 CLI 状态目录下的 `skills/workspace-sync/local-paths.json`
- 当前 CLI 状态目录示例: Claude 为 `~/.claude`, Codex 为 `~/.codex`

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

摘要的目标是：**让一个从未参与过这次对话的人，读完后能理解"我们在讨论什么问题、为什么这样做、讨论了哪些方案、得出了什么结论、停在哪里、下一步做什么"**。不只是进度记录，更是上下文的完整还原。

```markdown
# 工作空间:<name>

## 整体目标
<清晰描述在做什么、为什么做。首次 push 从对话提炼；后续 push 保留并更新，不要缩减>

## 背景与约束
<跨 session 必须保留的关键信息：架构决策、技术选型原因、已知的坑/限制、外部依赖。
有则宁多勿少；没有可省略>

## 讨论脉络
<所有场景必填，不区分是否有代码任务。记录本次对话的核心讨论内容：
- 讨论了哪些话题/问题
- 探讨了哪些方案或思路（包括被否定的，及原因）
- 达成了哪些共识或结论
- 尚未解决或待确认的问题>

## 关键决策
<已明确拍板的决策，每条格式：
- **[决策内容]** — 原因：[为什么这样选]>
<没有明确决策时可省略此节>

## 项目:<project-name>
- **背景**:<该项目相关的重要上下文，跨 session 需要记住的>
- **分支**:feature/import
- **已完成**:<具体列表>
- **进行中**:<当前停在哪，越具体越好，包括卡点或疑问>
- **下一步**:<必须具体，如"继续写 XXController 的 handleSubmit 方法">
- **关键文件**:path:line
- **注意事项**:<坑、约束、需要特别留意的地方>
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
WS_SKILL_DIR="<当前实际使用的 workspace-sync skill 目录>"
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

补充原则:

- 这里的关键是“读到当前实际生效的 config.json”，不是假设一定在某个固定的状态目录路径下。
- 如果脚本与运行环境存在 Git Bash / WSL / MSYS / Windows 路径差异，优先修正解析方式，而不是重复执行同一条失败命令。
- 低风险只读操作优先语义正确和快速返回，不要被某个脚本调用形式绑死。

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

额外约束:

- `list` 的本质是“本地缓存只读查询”。
- 默认优先从本地缓存直接得到结果；如果用户说“没看到想要的”“想不起名字”“给我完整列表/远端列表”，立刻补查远端轻量列表。
- `ws-list.sh` 是推荐实现，不是唯一合法实现。若脚本因环境兼容问题不可用，可直接遍历缓存目录和 `manifest.json` 做等价读取。

---

# Config 流程

> 详细步骤见 `action/config.md`

额外约束:

- `/workspace-sync config` 不是首次安装专用，而是长期存在的重配置入口。
- `config` 与首次配置必须复用 `references/setup.md` 中的同一套提问顺序、验证逻辑和写入方式。
- 保存时只更新当前选择 backend 的字段和 `backend` 本身；其他字段保留。

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
| push 时项目有未提交改动 | 告警 + 询问,用户确认后继续,manifest 记录 `code_status=dirty` |
| push 时项目无 upstream | 报错,要求先 `git push -u`(无法记录远端指针,不可跳过) |
| push 时与 upstream 不同步 | 告警 + 询问,用户确认后继续,manifest 记录 `code_status=out_of_sync` |
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

接口规范见 `references/backend-interface.md`，各后端实现：

- Local:  `references/local.md`
- GitHub: `references/github.md`
- GitLab: `references/gitlab.md`
- MinIO:  `references/minio.md`

---

# 暂未实现

- S3 后端
- workspace 版本历史浏览与回滚
