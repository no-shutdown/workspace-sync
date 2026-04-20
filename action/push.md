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

主路径（Claude Code 约定的编码规则）：

```bash
WIN_PWD=$(cygpath -w "$PWD" 2>/dev/null || echo "$PWD")
ENCODED_CWD=$(echo "$WIN_PWD" | sed 's|[:\\/]|-|g')
SESSIONS_DIR="$HOME/.claude/projects/$ENCODED_CWD"
SESSION_JSONL=$(ls -t "$SESSIONS_DIR"/*.jsonl 2>/dev/null | head -1)
```

若主路径找不到（平台差异/路径编码变体），执行 fallback：

```bash
if [[ -z "$SESSION_JSONL" ]]; then
  # 在所有 project 目录中，找最近修改且含有当前 PWD 记录的 jsonl
  # 策略：先按修改时间倒序扫描所有 jsonl，检查其中是否含 cwd 匹配当前工作目录
  SESSION_JSONL=$(
    find "$HOME/.claude/projects" -name "*.jsonl" -newer /dev/null 2>/dev/null \
    | xargs ls -t 2>/dev/null \
    | while read -r f; do
        if grep -qF "\"cwd\":\"$PWD\"" "$f" 2>/dev/null || \
           grep -qF "\"cwd\":\"$WIN_PWD\"" "$f" 2>/dev/null; then
          echo "$f"
          break
        fi
      done
  )
fi

[[ -z "$SESSION_JSONL" ]] && {
  echo "❌ 未找到当前会话 jsonl（路径: $SESSIONS_DIR/*.jsonl）"
  echo "   请确认 Claude Code 会话文件存在，或手动指定路径"
  exit 1
}
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

对每个检测到的项目，收集 `code_status`（不直接中断，汇总后再决策）：

```bash
CODE_WARNINGS=()   # 积累警告信息

for each detected project:
  cd "$PROJECT_PATH"
  PROJ_CODE_STATUS="clean"

  # 未提交/暂存改动
  if [[ -n "$(git status --porcelain)" ]]; then
    PROJ_CODE_STATUS="dirty"
    CODE_WARNINGS+=("⚠  $PROJECT_NAME: 存在未提交改动")
  fi

  # upstream 检查（致命：无 upstream 无法记录远端指针，直接报错）
  UPSTREAM=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)
  [[ -n "$UPSTREAM" ]] || {
    echo "❌ 项目 $PROJECT_NAME 当前分支没有上游分支，请先 git push -u"
    exit 1
  }

  # 未推送/落后检查
  git fetch --prune 2>/dev/null
  COUNTS=$(git rev-list --left-right --count HEAD...@{u} 2>/dev/null || echo "0 0")
  AHEAD=$(echo "$COUNTS" | awk '{print $1}')
  BEHIND=$(echo "$COUNTS" | awk '{print $2}')
  if [[ "$AHEAD" != "0" || "$BEHIND" != "0" ]]; then
    PROJ_CODE_STATUS="out_of_sync"
    CODE_WARNINGS+=("⚠  $PROJECT_NAME: 与上游不同步 (ahead=$AHEAD behind=$BEHIND)")
  fi

  PROJECT_CODE_STATUSES["$PROJECT_NAME"]="$PROJ_CODE_STATUS"
done
```

如果收集到任何警告，展示后询问用户：

```
以下项目的代码状态不是完全干净:
  ⚠  shanks-manage: 存在未提交改动
  ⚠  shanks-web: 与上游不同步 (ahead=2 behind=0)

此次 workspace 将只保存对话上下文，代码侧以当前已推送的 HEAD 为准。
在另一台设备 pull 后，上述代码改动不会被恢复。
是否仍然继续推送? [y/N]
```

用户选 N → 终止，提示先同步代码。
用户选 Y → 继续，manifest 中每个项目记录 `"code_status": "dirty"` 或 `"code_status": "out_of_sync"`，干净项目记录 `"code_status": "clean"`。

### Step 8: 生成 summary.md + manifest.json

Claude 用 Read 工具读 session jsonl，再根据是否存在旧摘要决定生成策略，最后用 Write 工具写入 `$STAGE_DIR/summary.md` 和 `$STAGE_DIR/manifest.json`。

**首次 push（CURRENT_REMOTE_VERSION == 0）：**
从 session jsonl 从头提炼，按 SKILL.md 中的 summary.md 格式生成完整摘要。

**更新 push（CURRENT_REMOTE_VERSION > 0）：**
先读取旧版摘要，再读 session jsonl，以旧摘要为基础做增量更新：

```bash
# 旧摘要位于 backend 的本地缓存，读取方式：
# GitLab: $LOCAL_REPO/$WS_NAME/summary.md
# MinIO:  $STAGE_DIR/summary.md（下载后已在 staging）
```

增量更新规则：
- `整体目标` 和 `背景与约束`：**原则上保留**，只有本次对话明确修正了目标或背景时才更新；不因本次只讨论了子任务就缩减
- 各项目段落：根据本次 session 更新"已完成""进行中""下一步"，新增本次涉及的文件
- 本次 session **未涉及**的项目段落：直接保留旧内容，不删除

**摘要质量要求：**
- "下一步"必须具体：写明方法名/文件名，避免"继续开发"这类无意义描述
- 宁可信息量多，不要为了简洁丢失关键背景
- 按项目分段：每个检测到的项目一段

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
  #   "head": "$(git rev-parse HEAD)",
  #   "code_status": "${PROJECT_CODE_STATUSES[$PROJECT_NAME]:-clean}"
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
  - 涉及项目: N 个 (dirty: M 个)
  - skill 状态: <exported/skipped 汇总>
  - 在另一设备用 /workspace-sync pull <name> 恢复
```

如有 dirty/out_of_sync 项目，在报告末尾补充提示：

```
⚠  提醒：以下项目有未同步的本地代码，pull 后需手动恢复:
   - shanks-manage (dirty)
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
