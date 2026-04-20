# Backend 接口规范

所有 backend 实现必须提供以下 5 个操作，行为保持一致。
新增 backend 时以本文件为参照，逐项实现。

---

## 1. connect

验证凭据，准备本地缓存（如需 clone 则 clone）。

- 失败时：打印具体错误原因，`exit 1`
- 不要在 connect 阶段创建远端仓库或 bucket

---

## 2. read_version(ws_name) → CURRENT_REMOTE_VERSION, CURRENT_REMOTE_CREATED_AT

读取远端 workspace 的 `manifest.json` 中的 `version` 和 `created_at`。

- workspace 不存在：`CURRENT_REMOTE_VERSION=0`，`CURRENT_REMOTE_CREATED_AT=""`
- workspace 存在但 manifest 不可读：`exit 1`，不要静默返回 0

此操作在 push 流程中调用两次：Step 6（基线）和 Step 11（并发校验）。

---

## 3. push(ws_name, stage_dir, next_version)

将 `stage_dir` 的内容上传为远端 `ws_name`，覆盖已有版本。

- 路径校验：确认 `ws_dir` 在允许的目录范围内，防止路径穿越
- 并发控制由调用方（push-flow Step 11）负责；push 本身不做额外校验
- 失败时：打印原因，`exit 1`

---

## 4. pull(ws_name, stage_dir)

将远端 `ws_name` 下载到 `stage_dir`。

- workspace 不存在：打印错误，`exit 1`
- 下载前 `stage_dir` 已由调用方清空并创建

---

## 5. list() → name|version|updated_at

列出当前 backend 下所有 workspace，每行一条，格式：

```
feature-x|3|2026-04-17T18:20:00+08:00
bugfix-login|1|2026-04-16T09:10:00+08:00
```

- 读不到 `version` 或 `updated_at` 时该字段输出 `-`
- 无 workspace 时输出空（不报错）

---

## 6. clean(ws_name | --all)

删除指定 workspace 或全部 workspace。

- 目标不存在时：打印 `nothing to clean: <name>`，`exit 0`（不报致命错误）
- 路径校验：同 push，防止路径穿越
- `--all` 时只删 workspace 目录，不删 backend 的根仓库或 bucket 本身

---

## 各 backend 实现文件

| Backend | 实现文件 | 配置字段 |
|---------|---------|---------|
| GitLab  | `references/gitlab.md` | `gitlab.host / token / project_path / branch` |
| GitHub  | `references/github.md` | `github.token / repo / branch` |
| MinIO   | `references/minio.md`  | `minio.endpoint / access_key / secret_key / bucket / prefix` |
| Local   | `references/local.md`  | `local.path` |
