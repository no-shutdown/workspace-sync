# pull

## 命令

```bash
/workspace-sync pull <workspace-name>
```

## 作用

从远端下载指定 workspace，自动恢复代码位置、skill 状态，并向用户呈现对话上下文。

## 执行步骤

### Step 1: 运行 fetch 脚本（含版本比较）

校验 WS_NAME（参考 SKILL.md 中的 `validate_ws_name`），然后：

```bash
WS_SKILL_DIR="$HOME/.claude/skills/workspace-sync"
chmod +x "$WS_SKILL_DIR/scripts/ws-pull-fetch.sh"
bash "$WS_SKILL_DIR/scripts/ws-pull-fetch.sh" "$WS_NAME"
```

脚本内部执行以下版本比较逻辑（**无需 git pull 即可完成**）：
- 读取本地缓存版本号
- 通过 API（GitLab/GitHub）或直接读文件获取远端版本号
- 根据比较结果决定行为

**版本决策矩阵：**

| 本地 | 远端 | 行为 |
|---|---|---|
| 有 (vL) | 有 (vR ≥ vL) | 从远端拉取（正常路径）|
| 有 (vL) | 有 (vR < vL) | **退出码 4**，返回冲突 JSON → 进入 Step 1b |
| 有 | 无 | 直接从本地缓存恢复，`source: "local_only"` |
| 无 | 有 | 从远端拉取 |
| 无 | 无 | 退出码 1，报错 workspace 不存在 |

脚本完成拉取后还会对每个 project：查 `local-paths.json` + 扫 `scan_roots` 自动匹配本地路径：
- 唯一命中 → `git checkout` 切到记录的 branch/HEAD，自动写回 `local-paths.json`
- 本地有未提交改动 → `skipped_dirty`，不覆盖当前工作区
- HEAD 不存在 → `skipped_head_missing`
- 导入 skill states

脚本输出 JSON：

```json
{
  "stage_dir": "...",
  "summary_path": "/path/to/staging/ws_name/summary.md",
  "source": "remote",
  "manifest": {"name": "...", "version": 3, "source_device": "...", "updated_at": "..."},
  "project_results": [
    {"name": "shanks-manage", "status": "restored", "head": "abc123", "branch": "feature/import", "path": "..."},
    {"name": "shanks-web",    "status": "skipped_dirty"}
  ],
  "unresolved": [],
  "skill_states": "done"
}
```

**退出码 1（下载失败）** → 展示 error 字段给用户。

**退出码 3（有未解析路径）** → `unresolved` 非空，进入 Step 2。

**退出码 4（本地比远端新）** → 进入 Step 1b。

**退出码 0** → 直接进入 Step 3。

### Step 1b: 版本冲突确认（仅 exit 4 时执行）

脚本输出冲突 JSON：

```json
{"conflict": true, "local_version": 5, "remote_version": 3, "workspace": "feature-x"}
```

向用户明确提示：

```
⚠ 版本冲突：本地 feature-x 为 v5，远端为 v3（本地更新）。
  用远端 v3 覆盖本地会丢失本地未推送的内容。

  是否仍要用远端版本覆盖本地？(y/n)
```

- 用户回复 `y` / `yes` → 重新执行：
  ```bash
  bash "$WS_SKILL_DIR/scripts/ws-pull-fetch.sh" "$WS_NAME" --force
  ```
  然后继续正常流程（Step 2 / Step 3）。
- 用户回复 `n` / `no` / 取消 → 停止，告知用户可用 `/workspace-sync push` 先推送本地内容。

### Step 2: 处理未解析的项目路径（仅 exit 3 时执行）

对每个 `unresolved` 项目：
- 若有多个候选（`candidates` 非空）→ 展示候选列表，请用户选择
- 若无候选 → 询问用户提供本地路径

用户提供路径后，校验该路径：
- 是有效 git 仓库
- `git config --get remote.origin.url` 规范化后与 `remote_key` 一致

校验通过 → 用 `scripts/set-local-path.sh` 写入 `local-paths.json`，然后对该项目单独执行 `git checkout`（同 Step 1 脚本的逻辑）。

### Step 3: 读取 summary.md，呈现上下文

Claude 用 Read 工具读 `summary_path`，向用户呈现完整上下文：

```
✓ 工作空间已恢复: <name> (v<version>，来自 <source_device>)
  来源: 远端拉取 / 本地缓存（仅本地存在）

  上下文摘要：
  <summary.md 中整体目标 / 背景与约束 / 各项目状态的要点>

  代码恢复:
    - shanks-manage: ✓ HEAD=abc123, branch=feature/import
    - shanks-web:    ⚠ 跳过（本地有未提交改动）

  skill 状态: <done/skipped 汇总>
```

若 `source` 为 `local_only`，额外提示：
> 此 workspace 仅存在于本地缓存（远端无对应记录）。恢复后如需同步到远端，请执行 `/workspace-sync push`。

若有 `skipped_dirty` 或 `skipped_head_missing` 的项目，明确提示用户：
- 这些项目的代码现场**未完全恢复**
- summary 中与它们相关的内容只能作为参考，不代表当前代码事实

呈现完毕后，直接进入上下文状态（可以立即继续工作），不需要用户再输入任何命令。
