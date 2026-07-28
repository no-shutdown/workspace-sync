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
- 未带名称时，按 `references/obsidian-cli.md` 的预边界元数据发现规则，通过 Obsidian CLI 列出 Vault 根目录文件夹，并从每个候选 `工作区.md` 读取用于选择的稳定 `workspace_id`、显示名称、生命周期和 `updated_at`；这些是控制元数据，不是知识库事实。用户选择前不读取候选 workspace 的图谱页面、workspace 正文、links/backlinks/files/search 结果、任务、架构或其他上下文事实，也不根据最近修改时间自动猜测或写入缓存、fallback state。
- 用户明确选择后，无论来自命令参数还是交互选择，都必须重新读取所选 `工作区.md` 并验证其稳定 `workspace_id` 与用户明确选择的目标一致；验证通过前不得打开总览或组装上下文，验证失败则停止，不回退到其他 workspace。
- 没有可选 workspace 时，要求用户输入新名称并初始化一个 workspace。
- 缓存缺失、损坏或 workspace 身份校验失败时，默认选择行为停止并要求用户重新明确选择；不回退到用户级 `current_workspace_*`、目录名或其他会话。运行环境缺少 `session_id` 或 `run_dir` 时，只有经验证的显式 workspace（命令参数或用户明确选择）可以完成一次非持久化操作；既没有有效会话上下文也没有显式 workspace 时停止。

### 4. 绑定当前会话缓存（条件写入）

- 比较当前会话缓存的 `workspace_id` 与所选 workspace 的稳定 `workspace_id`。只有两者相同，且缓存中的 `focus_task_id` 已在所选 workspace 中验证为正式 `任务` 节点时，才保留该焦点。
- 切换 workspace 时将 `focus_task_id` 清为 `null`，除非本次命令明确提供了所选 workspace 中有效的替代焦点；不得按名称、活动状态、最近更新时间或其他 workspace 推断焦点。
- 如果缓存中的 `focus_task_id` 对所选 workspace 无效，先清除为 `null` 并报告 warning，再继续焦点选择行为；告诉用户可以随后选择新的焦点。
- 在有效会话上下文中，将稳定 `workspace_id`、显示名称和按上述规则确定的 `focus_task_id` 写入 `<run_dir>/.workspace-sync-cache/sessions/<session-id>.json`；写入时使用临时文件加原子替换，不创建全局 current pointer。
- workspace 文件夹改名后，后续命令仍以 `工作区.md` 中的稳定 ID 重新绑定。
- 如果缺少 `session_id`、`run_dir`，或缓存目录不可写，则不创建用户级替代状态；对已经验证的显式 workspace 继续本次操作，但明确报告“知识库已同步，但会话 workspace 未持久化”。

### 5. 打开接手入口

通过 Obsidian CLI：

1. 打开知识库 Vault；
2. 打开 `<workspace>/图谱/总览.md`；
3. 读取并向用户呈现目标、架构面包屑、任务面包屑、当前任务、阻塞、缺口、联调和下一步；需要展开任务时进入 `<workspace>/图谱/视图/开发任务.md`。

同步完成后，按“用户明确指定焦点 > 当前会话缓存中属于所选 `workspace_id` 且已验证的 `focus_task_id` > 当前对话明确确认 > `总览.md` 活动任务”的优先级装配局部上下文闭包：任务父级链、直接子任务、直接依赖/未完成直接依赖者、架构邻域、联调关系和直接支撑记录。缓存焦点无效时已清除并报告 warning，再按剩余优先级继续；没有明确焦点时只呈现活动任务摘要并要求选择，不自动进入最近修改或名称相似的任务；原始资料和完整历史按需展开。

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
