# clean

## 命令

```bash
/workspace-sync clean <workspace-name>
/workspace-sync clean --all
```

## 目标

删除远端 workspace，并清理本地缓存与待导入状态缓存。

## 执行步骤

### Step 1: 校验目标

- `clean <name>`：按 `SKILL.md` 的 `validate_ws_name` 校验
- `clean --all`：跳过名称校验，但必须进入强确认

### Step 2: 二次确认

单个 workspace：

```text
将删除以下内容:
  - 远端 workspace: <name>
  - 本地缓存: <name>
  - 待导入 skill-state 缓存: <name>

确认继续? [y/N]
```

`--all`：

```text
这会删除当前 backend 下的全部 workspace 以及本地缓存。
请明确回复: DELETE ALL
```

### Step 3: 直接执行删除

不要依赖仓库脚本，直接根据当前 backend 做删除：

- Local: 删除目标目录
- GitHub / GitLab: 删除远端对应 workspace 目录或对象
- MinIO: 删除对象前缀

同时删除本地 `cache_dir` 中对应 workspace 缓存，以及待导入 skill-state 缓存。

### Step 4: 展示结果

目标不存在时返回：

```text
nothing to clean: <name>
```

成功时明确列出删除结果即可。
