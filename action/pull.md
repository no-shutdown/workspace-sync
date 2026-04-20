# pull

## 命令

```bash
/workspace-sync pull <workspace-name>
```

## 作用

从远端下载指定 workspace，并在当前设备恢复工作上下文。

## 适用场景

- 在新设备继续之前的任务
- 恢复某个已保存的工作现场
- 把上下文、摘要和相关项目位置切回到保存时的状态

## 依赖条件

- 本地已安装 `workspace-sync`
- 已完成后端配置
- 本地能找到对应项目，或能够通过配置的扫描路径识别项目

## 执行步骤

### Step 1: 校验 & 下载

校验 WS_NAME（参考 SKILL.md 中的 `validate_ws_name`）。

准备 staging 目录：

```bash
CONFIG="$HOME/.claude/skills/workspace-sync/config.json"
WS_SKILL_DIR="$HOME/.claude/skills/workspace-sync"

CACHE_DIR=$(python3 -c "
import json
d = json.load(open('$CONFIG'))
print(d.get('cache_dir') or '~/.claude/workspace-cache')
" 2>/dev/null || echo "~/.claude/workspace-cache")
CACHE_DIR="${CACHE_DIR/#\~/$HOME}"

STAGE_ROOT="$CACHE_DIR/staging"
STAGE_DIR="$STAGE_ROOT/$WS_NAME"
[[ "$STAGE_DIR" == "$STAGE_ROOT/"* ]] || { echo "❌ 非法 staging 路径"; exit 1; }
rm -rf -- "$STAGE_DIR"
mkdir -p "$STAGE_DIR"
```

然后调用 backend-specific 下载：
- GitLab：见 `references/gitlab.md` #Pull
- MinIO：见 `references/minio.md` #Pull

### Step 2: 定位本地项目路径

读 `$STAGE_DIR/manifest.json`，对每个 project：

1. 把 `project.remote` 用 `ws_normalize_remote`（来自 `scripts/workspace-sync-lib.sh`）规范化为 `remote_key`

2. 查 `local-paths.json`：
   - 命中 → 校验路径存在、是 git 仓库、`git config --get remote.origin.url` 规范化后与 `remote_key` 一致
   - 校验通过 → 直接使用
   - 校验失败 → 删除旧映射，进入下一步

3. 扫描 `scan_roots`（来自 config.json），对每个候选仓库按 `remote_key` 精确匹配

4. 根据匹配结果：
   - **唯一命中** → 自动选用，写回 `local-paths.json`
   - **多个命中** → 展示候选（path/branch/是否干净/是否含 head），用户确认后写回
   - **无命中** → 询问用户提供本地路径，校验通过后写入

   使用 `scripts/resolve-project-path.sh` 和 `scripts/set-local-path.sh` 辅助实现。

**约束**：只允许 `remote_key` 唯一命中时自动恢复，不凭 project.name、branch、source_cwd 单独决定路径。

### Step 3: 校验 & 切换代码

```bash
cd "$PROJECT_PATH"

# 本地有未提交改动 → 跳过，不覆盖
[[ -z "$(git status --porcelain)" ]] || {
  echo "⚠ 项目 $PROJECT_NAME 有未提交改动，跳过代码恢复"
  continue
}

git fetch --all --prune

# 校验 head 存在
git cat-file -e "${HEAD}^{commit}" 2>/dev/null || {
  echo "⚠ 项目 $PROJECT_NAME 记录的 head $HEAD 不存在，跳过"
  continue
}

git checkout -B "$BRANCH" "$HEAD"
[[ -n "$UPSTREAM" ]] && git branch --set-upstream-to="$UPSTREAM" "$BRANCH" 2>/dev/null || true
```

### Step 4: 导入 skill states

```bash
bash "$WS_SKILL_DIR/scripts/import-skill-states.sh" \
  --workspace-name "$WS_NAME" \
  --stage-dir "$STAGE_DIR" \
  --manifest "$STAGE_DIR/manifest.json"
```

恢复规则：
- skill 未安装 → `deferred`
- contract 缺失 → `deferred`
- contract 存在但 state 不兼容 → `skipped`
- import 成功 → `restored`
- workspace 没有该 skill 的导出记录 → `missing`

### Step 5: 注入上下文 & 汇报

Claude 用 Read 工具读 `$STAGE_DIR/summary.md`，向用户说明恢复了什么：

```
✓ 工作空间已恢复: <name> (v<version>)

  上下文摘要: 已读取

  项目代码:
    - shanks-manage: exact (HEAD=abc123, branch=feature/import)
    - shanks-admin: skipped (本地有未提交改动)

  skill 状态:
    - sdd: restored
    - ccb: deferred (未安装)
```

如果某个项目被 skip，必须明确告知用户：这些项目的代码现场未完全恢复，summary 中与它相关的内容只能作为参考，不能当作当前代码事实。

## 注意事项

- `workspace-sync` 恢复的是已提交且已推送的代码位置
- 它不会替你恢复未提交的本地改动
- 如果某些 skill 未安装，对应状态会被标记为 deferred

## 示例

```bash
/workspace-sync pull feature-import
```
