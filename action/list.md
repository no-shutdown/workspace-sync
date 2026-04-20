# list

## 命令

```bash
/workspace-sync list
```

## 作用

列出当前后端中已经保存的 workspace，并在列出后允许你直接选择一个继续恢复，不需要再手动输入一次 `pull`。

## 适用场景

- 你忘了之前保存过哪些 workspace
- 你需要确认远端是否已经存在某个 workspace
- 你准备执行 `pull` 或 `clean`
- 你想先看列表，再从里面挑一个继续当前工作

## 执行步骤

### Step 1: 读取 workspace 列表

从 backend 获取所有 workspace 列表：
- GitLab：见 `references/gitlab.md` #List
- MinIO：见 `references/minio.md` #List

两种后端均返回 `name|version|updated_at` 格式，每行一条。

### Step 2: 展示列表并引导选择

整理成编号列表展示，**展示后立即追加选择引导**：

```
1. feature-x     (v3, 2026-04-17T18:20:00+08:00)
2. bugfix-login  (v1, 2026-04-16T09:10:00+08:00)

回复序号或 workspace 名称继续恢复；回复 cancel 只查看。
```

列表为空时：明确告知当前 backend 下没有可恢复的 workspace，停止。

即使列表里只有一个 workspace，也先展示再确认，不擅自 pull。

### Step 3: 解析用户选择

用户可以回复：
- 列表**序号**（映射到当前刚展示的列表项）
- workspace **精确名称**

序号或名称不合法时，明确报错并要求重新选择。

### Step 4: 进入 Pull 流程

直接把用户选择等价为 `/workspace-sync pull <selected-workspace>`，进入 `action/pull.md` 的执行步骤。

## 示例

```bash
/workspace-sync list
```

看到列表后，可以直接回复：

```text
2
```

或者：

```text
feature-import
```

Claude 会把这次选择直接当作 `/workspace-sync pull feature-import` 处理。
