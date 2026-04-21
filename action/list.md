# list

## 命令

```bash
/workspace-sync list
```

## 作用

列出当前后端中已保存的 workspace，列出后直接引导用户选一个恢复，不需要再手动输入 pull。

## 执行步骤

### Step 1: 读取本地缓存（无网络）

```bash
WS_SKILL_DIR="$HOME/.claude/skills/workspace-sync"
chmod +x "$WS_SKILL_DIR/scripts/ws-list.sh"
bash "$WS_SKILL_DIR/scripts/ws-list.sh"
```

脚本从本地缓存目录读取，**不做 git pull / 网络请求**，输出 `name|version|updated_at` 格式，每行一条。

**输出情况处理：**

| 输出内容 | 含义 | 处理 |
|---|---|---|
| 正常列表行 | 本地有缓存 | 展示列表，进入 Step 2 |
| 空输出 | 本地缓存为空 | 提示用户，询问是否获取远端列表 → Step 1b |
| `__NO_LOCAL_CACHE__` | 首次使用/无缓存目录 | 提示用户，询问是否获取远端列表 → Step 1b |

### Step 1b: 获取远端列表（仅当本地无缓存时）

用户确认后执行：

```bash
bash "$WS_SKILL_DIR/scripts/ws-list.sh" --remote
```

远端列表版本号显示为 `-`（仅列名，不下载内容）。若远端也为空，明确告知并停止。

### Step 2: 展示列表并引导选择

将脚本输出整理为编号列表展示，**展示后立即追加选择引导**：

```
1. feature-x     (v3, 2026-04-17T18:20:00+08:00)
2. bugfix-login  (v1, 2026-04-16T09:10:00+08:00)

回复序号或 workspace 名称继续恢复；回复 q 只查看不恢复。
```

即使列表里只有一个 workspace，也先展示再确认，不擅自 pull。

用户回复 `q` / `cancel` / `quit` → 停止，不执行 pull。

### Step 3: 解析用户选择 → 进入 Pull 流程

用户回复序号或精确名称 → 等价于 `/workspace-sync pull <name>`，进入 `action/pull.md`。
序号或名称不合法时，明确报错并要求重新选择。
