# pull

## 命令

```text
/workspace-sync pull [工作区名称]
```

## 目标

同步唯一的个人开发知识库 Git 仓库，并选择一个 workspace 绑定到当前会话。`pull` 不复制出 workspace 快照；本地 clone 本身就是 Obsidian Vault。

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

- 命令带 `<工作区名称>` 时，验证该文件夹和 `工作区.md` 存在，并按稳定 `workspace_id` 直接绑定该 workspace。
- 未带名称时，通过 Obsidian CLI 列出 workspace 元数据，让用户选择；不要根据最近修改时间自动猜测。
- 没有可选 workspace 时，要求用户输入新名称并初始化一个 workspace。
- 运行环境缺少 `session_id` 时，不回退到用户级 `current_workspace_*`；本次允许通过显式名称或用户选择完成一次性操作，但必须说明该绑定不会持久化到后续命令。

### 4. 写入当前会话缓存

- 将稳定 `workspace_id`、显示名称和保留的 `focus_task_id` 写入 `<run_dir>/.workspace-sync-cache/sessions/<session-id>.json`；写入时使用临时文件加原子替换，不创建全局 current pointer。
- workspace 文件夹改名后，后续命令仍以 `工作区.md` 中的稳定 ID 重新绑定。
- 如果缺少 `session_id`、`run_dir`，或缓存目录不可写，则不创建用户级替代状态；继续本次操作，但明确报告“知识库已同步，但会话 workspace 未持久化”。

### 5. 打开接手入口

通过 Obsidian CLI：

1. 打开知识库 Vault；
2. 打开 `<workspace>/图谱/总览.md`；
3. 读取并向用户呈现目标、架构面包屑、任务面包屑、当前任务、阻塞、缺口、联调和下一步；需要展开任务时进入 `<workspace>/图谱/视图/开发任务.md`。

同步完成后，如果用户明确指定焦点任务，按“用户明确指定 > 当前对话明确确认 > `总览.md` 活动任务”的优先级装配该任务的局部上下文闭包：任务父级链、直接子任务、直接依赖/未完成直接依赖者、架构邻域、联调关系和直接支撑记录。没有明确焦点时只呈现活动任务摘要并要求选择，不自动进入最近修改或名称相似的任务；原始资料和完整历史按需展开。

### 6. 恢复代码项目现场

根据 workspace `图谱/说明/项目/` 支撑记录中的规范化 Git remote 查找本机项目：

1. 优先使用用户在本次操作中明确提供的路径；
2. 其次检查当前 `run_dir` 或当前 cwd 中与 remote 匹配的仓库；
3. 再使用设备级状态中的 `project_paths`；
4. 仍无法唯一定位时要求用户确认；不扫描整台机器。

对于每个已解析项目：

- remote 不匹配：跳过并报告；
- 工作树 dirty：不切分支、不 checkout、不覆盖，报告跳过；
- 工作树干净且目标分支存在：切到记录分支并尝试恢复记录 HEAD；
- 目标 commit 不存在：保留当前代码现场并报告。

代码恢复失败不撤销知识库 Git pull；必须明确告诉用户“知识库已同步，但代码现场未完整恢复”。

## 结果

至少报告：

- Git 同步结果和是否存在冲突；
- 选择的 workspace、生命周期、总览路径，以及会话缓存是否已成功持久化；
- 每个代码项目的 restored/skipped 结果及原因；
- 当前 workspace 后续可执行的 compile、开发或 push 动作。
