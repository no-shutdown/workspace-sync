# Git 知识库仓库适配器

## 接口

workspace-sync 只支持一个知识库 Git 仓库。Git adapter 的接口很小：

1. `connect()`：验证本地路径、remote、凭据和分支；必要时 clone。
2. `fetch()`：读取远端变化，不改写工作树。
3. `integrate()`：在干净工作树上 fast-forward 或按流程 rebase；冲突返回停止状态。
4. `commit(scope, message)`：只提交调用方明确指定的路径范围。
5. `push(branch)`：推送已整合的本地分支；禁止 force。

Git 适配器不读取 Markdown 语义、不生成节点、不解析 Wiki 链接。Vault 内容行为由 Obsidian CLI 适配器负责。

## 安全规则

- 所有路径先解析为绝对路径，并确认位于配置的知识库路径内。
- 不对知识库路径执行 `reset --hard`、`clean -fd` 或 force push。
- 不用 Git remote URL 保存 token；优先 SSH 或 Git Credential Manager。
- push 前检查远端变化；远端领先时先整合，冲突就停止。
- `compile` 的本地 commit 和 `push` 的远端推送是两个动作。
- `push` 的提交范围默认是 `<workspace>/`，不包括其他 workspace、根 `SCHEMA.md` 或无关根文件。

## 允许的 Git 操作

```text
clone
status
remote get-url
branch / symbolic-ref
rev-parse
fetch
pull --ff-only 或受控 rebase
add <明确路径>
commit
push
```

不允许用 Git 命令直接代替 Obsidian CLI 读取、创建或修改 Vault 页面内容。Git 可以用来判断变更范围和版本状态。

## 配置、设备状态与会话缓存

Git 知识库仓库路径、分支和 Obsidian Vault 名称写入本机配置；`state_file` 只保存设备级 `project_paths` 等映射，不再承担当前 workspace 指针。

当前 workspace 和 focus task 的默认来源是当前运行目录下的会话缓存：

```text
<run_dir>/.workspace-sync-cache/sessions/<session-id>.json
```

- `config` 只配置知识库连接与本地 Vault 信息，不选择 workspace。
- 会话缓存只保存 `workspace_id`、`workspace_name` 和 `focus_task_id` 等会话边界，不进入共享知识库 Git，也不写入 Obsidian。
- 旧 `current_workspace_*` 只作为历史字段保留并忽略；不同设备、不同会话和同一目录下的并行 worktree 都可以保留各自的 workspace 选择与项目路径解析结果。
