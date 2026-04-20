# list

## 命令

```bash
/workspace-sync list
```

## 作用

列出当前后端中已保存的 workspace，列出后直接引导用户选一个恢复，不需要再手动输入 pull。

## 执行步骤

### Step 1: 运行列表脚本

```bash
WS_SKILL_DIR="$HOME/.claude/skills/workspace-sync"
chmod +x "$WS_SKILL_DIR/scripts/ws-list.sh"
bash "$WS_SKILL_DIR/scripts/ws-list.sh"
```

脚本输出 `name|version|updated_at` 格式，每行一条；出错时打印 ❌ 提示并 exit 1。

### Step 2: 展示列表并引导选择

将脚本输出整理为编号列表展示，**展示后立即追加选择引导**：

```
1. feature-x     (v3, 2026-04-17T18:20:00+08:00)
2. bugfix-login  (v1, 2026-04-16T09:10:00+08:00)

回复序号或 workspace 名称继续恢复；回复 cancel 只查看。
```

列表为空时：明确告知当前 backend 下没有可恢复的 workspace，停止。

即使列表里只有一个 workspace，也先展示再确认，不擅自 pull。

### Step 3: 解析用户选择 → 进入 Pull 流程

用户回复序号或精确名称 → 等价于 `/workspace-sync pull <name>`，进入 `action/pull.md`。
序号或名称不合法时，明确报错并要求重新选择。
