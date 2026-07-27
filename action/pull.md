# pull

## 命令

```text
/workspace-sync pull [workspace-name]
```

## 目标

同步唯一的个人开发知识库 Git 仓库，并选择一个 workspace 作为本机当前工作空间。`pull` 不复制出 workspace 快照；本地 clone 本身就是 Obsidian Vault。

## 步骤

### 1. 检查本地知识库现场

- 读取 `config.json`，缺失时进入 `action/config.md`。
- 确认本地 Vault 路径对应配置的知识库 remote。
- 使用 Git 检查工作树；若存在未提交知识库变更，停止并要求用户先 commit、push 或明确处理，不能覆盖。

### 2. 同步 Git 仓库

- fetch 配置分支。
- 本地无未提交变更时，使用安全的 fast-forward 或明确的 rebase/merge 流程整合远端。
- 如果本地和远端无法自动整合，停止并报告冲突文件；禁止 force reset、force push 或静默丢弃本地 Wiki。
- 同步的是整个知识库仓库，但后续上下文只加载用户选定的 workspace。

### 3. 选择 workspace

- 命令带 `<workspace-name>` 时，验证该文件夹和 `工作区.md` 存在。
- 未带名称时，通过 Obsidian CLI 列出 workspace 元数据，让用户选择；不要根据最近修改时间自动猜测。
- 没有可选 workspace 时，要求用户输入新名称并初始化一个 workspace。

### 4. 设置本地当前 workspace

将稳定 `workspace_id` 和当前文件夹名称写入本地状态文件，不写入知识库 Git 仓库。workspace 文件夹改名后以 `工作区.md` 中的稳定 ID 重新绑定。

### 5. 打开接手入口

通过 Obsidian CLI：

1. 打开知识库 Vault；
2. 打开 `<workspace>/图谱/总览.md`；
3. 读取并向用户呈现目标、当前任务、阻塞、缺口、联调和下一步。

新 AI 会话默认只读取该 workspace 的 `SCHEMA.md`、`工作区.md`、`图谱/总览.md` 和活动任务子图；原始资料/历史按需展开。

### 6. 恢复代码项目现场

根据 workspace 节点/项目状态中的规范化 Git remote 查找本机项目：

1. 优先使用本地状态中的 remote→path 映射；
2. 其次检查当前 cwd；
3. 再使用用户明确提供的路径；不扫描整台机器。

对于每个已解析项目：

- remote 不匹配：跳过并报告；
- 工作树 dirty：不切分支、不 checkout、不覆盖，报告跳过；
- 工作树干净且目标分支存在：切到记录分支并尝试恢复记录 HEAD；
- 目标 commit 不存在：保留当前代码现场并报告。

代码恢复失败不撤销知识库 Git pull；必须明确告诉用户“知识库已同步，但代码现场未完整恢复”。

## 结果

至少报告：

- Git 同步结果和是否存在冲突；
- 选择的 workspace、生命周期和总览路径；
- 每个代码项目的 restored/skipped 结果及原因；
- 当前 workspace 后续可执行的 compile、开发或 push 动作。
