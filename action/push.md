# push

## 命令

```bash
/workspace-sync push <workspace-name>
```

## 作用

把当前会话的工作上下文保存为一个 workspace，并上传到已配置的远端后端。

保存内容：
- 对话摘要
- 对话备份
- 当前会话涉及项目的 git 指针信息
- 其他 skill 通过 contract 导出的 portable 状态

## 适用场景

- 你准备离开当前设备
- 你希望在另一台设备继续当前任务
- 你想把当前阶段性成果固化为一个可恢复的 workspace

## 执行前要求

- 相关 git 项目工作区必须是干净的
- 当前分支必须已配置 upstream
- 本地提交必须已推送到上游
- `workspace-sync` 已完成后端配置

## 执行步骤

### Step 1: 加载配置

```bash
CONFIG="$HOME/.claude/skills/workspace-sync/config.json"
WS_SKILL_DIR="$HOME/.claude/skills/workspace-sync"

CACHE_DIR=$(python3 -c "
import json
d = json.load(open('$CONFIG'))
print(d.get('cache_dir') or '~/.claude/workspace-cache')
" 2>/dev/null || echo "~/.claude/workspace-cache")
CACHE_DIR="${CACHE_DIR/#\~/$HOME}"
```

### Step 2: 定位当前 session jsonl

```bash
WIN_PWD=$(cygpath -w "$PWD" 2>/dev/null || echo "$PWD")
ENCODED_CWD=$(echo "$WIN_PWD" | sed 's|[:\\/]|-|g')
SESSIONS_DIR="$HOME/.claude/projects/$ENCODED_CWD"
SESSION_JSONL=$(ls -t "$SESSIONS_DIR"/*.jsonl 2>/dev/null | head -1)
[[ -z "$SESSION_JSONL" ]] && { echo "❌ 未找到当前会话 jsonl"; exit 1; }
```

### Step 3: 识别涉及的项目

```bash
chmod +x "$WS_SKILL_DIR/scripts/detect-projects.sh"
PROJECTS_JSON=$(bash "$WS_SKILL_DIR/scripts/detect-projects.sh" "$SESSION_JSONL")
```

### Step 4: 展示确认 & 校验名称

展示检测到的项目列表：

```
检测到本次对话涉及 N 个项目:
  [1] shanks-manage  (feature/import)
  ...
工作空间名称: <用户传入或建议名称>
确认推送? [Y/n]
```

N=0 → 纯讨论模式，继续。

按 SKILL.md 中的 `validate_ws_name` 校验 `$WS_NAME`。

### Step 5: 准备 staging 目录

```bash
STAGE_ROOT="$CACHE_DIR/staging"
STAGE_DIR="$STAGE_ROOT/$WS_NAME"
[[ "$STAGE_DIR" == "$STAGE_ROOT/"* ]] || { echo "❌ 非法 staging 路径"; exit 1; }
rm -rf -- "$STAGE_DIR"
mkdir -p "$STAGE_DIR/projects"
cp "$SESSION_JSONL" "$STAGE_DIR/conversation.jsonl"
```

### Step 6: 读取远端版本（乐观并发基线）

调用 backend-specific 读取（见 `references/gitlab.md` 或 `references/minio.md` 中的"读取版本号"）：

```bash
CURRENT_REMOTE_VERSION=0
CURRENT_REMOTE_CREATED_AT=""
# backend-specific: 读远端 manifest.json 的 version 和 created_at
# 不存在则保持 0 / 空字符串
# 读取失败但远端对象存在时直接报错
```

### Step 7: 校验每个项目状态

```bash
for each detected project:
  cd "$PROJECT_PATH"

  [[ -z "$(git status --porcelain)" ]] || {
    echo "❌ 项目 $PROJECT_NAME 存在未提交改动，请先 commit/push 后再执行 workspace-sync push"
    exit 1
  }

  UPSTREAM=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)
  [[ -n "$UPSTREAM" ]] || {
    echo "❌ 项目 $PROJECT_NAME 当前分支没有上游分支，请先 push -u"
    exit 1
  }

  git fetch --prune
  COUNTS=$(git rev-list --left-right --count HEAD...@{u})
  AHEAD=$(echo "$COUNTS" | awk '{print $1}')
  BEHIND=$(echo "$COUNTS" | awk '{print $2}')
  [[ "$AHEAD" == "0" && "$BEHIND" == "0" ]] || {
    echo "❌ 项目 $PROJECT_NAME 与上游不同步(ahead=$AHEAD behind=$BEHIND)"
    exit 1
  }
done
```

任何一个项目不满足 → 整个 push 终止。

### Step 8: 生成 summary.md + manifest.json

Claude 用 Read 工具读 session jsonl，然后用 Write 工具写入 `$STAGE_DIR/summary.md` 和 `$STAGE_DIR/manifest.json`。

**摘要生成原则：**
- 整体目标：从对话开头几条用户消息提炼，不超过 2 句
- 按项目分段：每个检测到的项目一段
- "下一步"必须具体：避免"继续开发"这类无意义描述

**manifest.json 写法：**

```json
{
  "name": "<WS_NAME>",
  "version": "<NEXT_VERSION，Step 11 后填入>",
  "previous_version": "<CURRENT_REMOTE_VERSION>",
  "conversation_id": "<从 session jsonl 提取>",
  "source_device": "<hostname>",
  "source_cwd": "<cwd>",
  "created_at": "<CURRENT_REMOTE_CREATED_AT 或 now（首次 push）>",
  "updated_at": "<now>",
  "projects": [...]
}
```

`created_at` 规则：首次 push（`CURRENT_REMOTE_VERSION=0`）设为当前时间；后续 push 从远端旧 manifest 读取并保留。

### Step 9: 记录项目 git 指针

```bash
for each detected project:
  PROJ_DIR="$STAGE_DIR/projects/$PROJECT_NAME"
  mkdir -p "$PROJ_DIR"
  cd "$PROJECT_PATH"
  # 用 Write 工具写 meta.json:
  # {
  #   "name": "$PROJECT_NAME",
  #   "remote": "$(git config --get remote.origin.url)",
  #   "upstream": "$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}')",
  #   "branch": "$(git rev-parse --abbrev-ref HEAD)",
  #   "head": "$(git rev-parse HEAD)"
  # }
done
```

### Step 10: 导出 skill states

```bash
bash "$WS_SKILL_DIR/scripts/export-skill-states.sh" \
  --workspace-name "$WS_NAME" \
  --stage-dir "$STAGE_DIR" \
  --projects-json "$PROJECTS_JSON"
```

失败时记录 `status=skipped`，不影响整个 push。

### Step 11: 乐观并发校验

再读一次远端版本（backend-specific）：

```bash
LATEST_REMOTE_VERSION=<backend-specific read>
```

如果 `LATEST_REMOTE_VERSION != CURRENT_REMOTE_VERSION`：

```
⚠ 并发冲突: 你本地基于版本 v${CURRENT_REMOTE_VERSION}，当前远端已是 v${LATEST_REMOTE_VERSION}
  你计划提交的新版本原本是 v$((CURRENT_REMOTE_VERSION + 1))
  如果继续，将基于最新远端版本提交 v$((LATEST_REMOTE_VERSION + 1))
  是否继续? [y/N]
```

用户确认 → `CURRENT_REMOTE_VERSION=$LATEST_REMOTE_VERSION`，重新计算 `NEXT_VERSION=$((CURRENT_REMOTE_VERSION + 1))`，用 Edit 工具更新 manifest.json 中的 `version`/`previous_version`，继续。
用户取消 → 停止。

`NEXT_VERSION=$((CURRENT_REMOTE_VERSION + 1))`

### Step 12: 上传

根据 `BACKEND` 调用对应实现：
- GitLab：见 `references/gitlab.md` #Push
- MinIO：见 `references/minio.md` #Push

### Step 13: 报告成功

```
✓ 工作空间已推送: <name>
  - 后端: <backend>
  - 版本: v<NEXT_VERSION> (previous v<CURRENT_REMOTE_VERSION>)
  - 涉及项目: N 个
  - skill 状态: <exported/skipped 汇总>
  - 在另一设备用 /workspace-sync pull <name> 恢复
```

## 常见失败原因

- 存在未提交改动
- 存在已暂存但未提交改动
- 当前分支没有 upstream
- 本地与 upstream 不同步
- 远端配置不完整

## 示例

```bash
/workspace-sync push feature-import
```
