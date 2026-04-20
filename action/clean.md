# clean

## 命令

```bash
/workspace-sync clean <workspace-name>
/workspace-sync clean --all
```

## 作用

删除远端 workspace，并清理本地 staging 缓存及待导入状态缓存。

## 适用场景

- 某个 workspace 已经过期，不再需要保留
- 你想清理测试数据
- 你要重建一套更干净的 workspace 集合

## 执行步骤

### Step 1: 校验名称 & 列出将删除内容

按 SKILL.md 中的 `validate_ws_name` 校验 `$WS_NAME`（`--all` 时跳过）。

向用户列出将要删除的内容：
- 远端 workspace（指定名称或全部）
- 本地 staging 缓存
- 本地 deferred skill state 缓存

### Step 2: 二次确认

单个 workspace：
```
将删除以下内容:
  - 远端 workspace: <name>
  - 本地缓存: <name>

确认继续? [y/N]
```

`--all`（必须使用更强确认）：
```
这会删除当前 backend 下的全部 workspace 及本地缓存。
请明确回复: DELETE ALL
```

### Step 3: 删除远端

根据 `BACKEND` 调用对应实现：
- GitLab：见 `references/gitlab.md` #Clean
- MinIO：见 `references/minio.md` #Clean

先删远端，再删本地缓存。

### Step 4: 删除本地缓存

```bash
CACHE_DIR="${CACHE_DIR:-$HOME/.claude/workspace-cache}"

if [[ "$WS_NAME" == "--all" ]]; then
  STAGE_ROOT="$CACHE_DIR/staging"
  [[ -d "$STAGE_ROOT" ]] && rm -rf -- "$STAGE_ROOT"/*
else
  STAGE_DIR="$CACHE_DIR/staging/$WS_NAME"
  [[ "$STAGE_DIR" == "$CACHE_DIR/staging/"* ]] || { echo "❌ 非法路径"; exit 1; }
  rm -rf -- "$STAGE_DIR"
fi
```

### Step 5: 报告结果

```
✓ 已清理 workspace: <name>
  - 远端: deleted
  - 本地缓存: deleted
```

目标不存在时：提示 `nothing to clean: <name>`，不报致命错误。

## 注意事项

- `clean --all` 会清空当前后端下的全部 workspace
- 这是破坏性操作，执行前应确认远端中没有仍需保留的数据

## 示例

```bash
/workspace-sync clean feature-import
/workspace-sync clean --all
```
