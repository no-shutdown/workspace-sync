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

## 本地状态

Git 知识库仓库路径、分支和 Obsidian Vault 名称写入本机配置；当前 workspace 指针和代码项目路径映射写入本机 state。它们都不进入共享知识库，以便不同设备选择不同 workspace 和项目路径。
