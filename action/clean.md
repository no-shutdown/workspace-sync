# clean

## 命令

```bash
/workspace-sync clean <workspace-name>
/workspace-sync clean --all
```

## 作用

删除远端 workspace，并清理本地 staging 缓存。

## 执行步骤

### Step 1: 校验名称

按 SKILL.md 中的 `validate_ws_name` 校验 `$WS_NAME`（`--all` 时跳过）。

### Step 2: 二次确认

单个 workspace：
```
将删除以下内容:
  - 远端 workspace: <name>
  - 本地 staging 缓存: <name>

确认继续? [y/N]
```

`--all`（必须使用更强确认）：
```
这会删除当前 backend 下的全部 workspace 及本地缓存。
请明确回复: DELETE ALL
```

### Step 3: 运行删除脚本

用户确认后：

```bash
WS_SKILL_DIR="$HOME/.claude/skills/workspace-sync"
chmod +x "$WS_SKILL_DIR/scripts/ws-clean.sh"
bash "$WS_SKILL_DIR/scripts/ws-clean.sh" "$WS_NAME"
```

脚本同时处理远端删除 + 本地缓存清理，成功后输出 `✓ 已清理 workspace: <name>`。

目标不存在时脚本输出 `nothing to clean: <name>` 并正常退出。

### Step 4: 展示结果

直接把脚本输出展示给用户。
