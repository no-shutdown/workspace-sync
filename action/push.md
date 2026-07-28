# push

## 命令

```text
/workspace-sync push [工作区名称]
```

## 目标

提交并推送当前 workspace 已经产生的个人开发知识库变更，同时记录关联代码项目的现场指针。push 不重新解释原始资料，不自动运行 compile，也不复制代码。

## 步骤

### 1. 确认当前 workspace

- 默认读取 `<run_dir>/.workspace-sync-cache/sessions/<session-id>.json` 中的当前会话 workspace。
- 命令带 `[工作区名称]` 时，先按该名称解析目标 workspace，再回到 `工作区.md` 用稳定 `workspace_id` 校验，并把它作为本次 push 的单次覆盖。
- 两者都没有时，停止并要求用户先执行 `list`/`pull` 选择 workspace，或在本次命令中显式提供名称。
- 会话缓存缺失、损坏、`session_id` 非法、workspace 已不存在、`工作区.md` 稳定 ID 不匹配，或运行环境缺少 `session_id` / `run_dir` 且又没有显式参数时，都必须安全停止；不读取用户级 `current_workspace_*`，不按最近使用或其他会话猜测。
- 所有默认读取和写入都限制在当前会话 workspace；显式覆盖只影响本次操作。

### 2. 识别涉及的代码项目

只检查有限来源：

1. 当前 workspace `图谱/说明/项目/` 中已登记的项目支撑记录；
2. 用户在本次操作中明确提供的 Git 仓库路径；
3. 当前 `run_dir` 或当前 cwd 中与目标 remote 匹配的 Git 仓库；
4. 设备级状态中的 `project_paths`。

定位优先级固定为“本次显式路径 > 当前 `run_dir` / 当前 cwd > 用户级 `project_paths`”。当前 cwd 或对话发现但尚未关联的仓库只能作为候选。展示候选并要求用户确认后才加入 workspace；不扫描整台机器，也不按最近访问自动加入。

### 3. 采集项目现场

对每个已确认项目只读采集：

- 规范化 Git remote；
- 当前分支和 upstream；
- HEAD commit；
- dirty 状态；
- 采集时间。

dirty 项目允许 push 知识库。只把 dirty 标志和指针写入对应项目支撑记录或 workspace 日志，不复制未提交文件、diff 或代码。

### 4. 检查知识库远端

- 使用 Git fetch 检查配置分支是否有远端变化。
- 本地知识库有未提交变更时，先保留现场并整理；不要用 pull 覆盖。
- 远端变化可以安全整合时，先 fast-forward 或 rebase；存在冲突时停止。
- 禁止 force push、reset --hard 或静默删除人工图谱页面。

### 5. 限定提交范围

本次 commit 默认只包含当前 workspace 文件夹内的知识库变更，包括其 `工作区.md`、原始资料、图谱节点、支撑记录、候选、生成页面和日志。

- 其他 workspace 的变更不自动加入；
- 根目录 `SCHEMA.md` 的变更不自动加入；
- 其他根目录文件变更不自动加入；
- 发现这些范围外的变更时，报告并要求用户单独处理。

如果当前 workspace 没有任何变更，返回 no-op，不创建空 commit。

### 6. 提交并推送

用明确的 commit message 提交当前 workspace，然后推送配置 Git 分支。commit 前后记录：

- workspace 名称和稳定 ID；
- 变更文件范围；
- 关联项目现场摘要；
- commit ID 和远端推送结果。

push 成功后不修改其他 workspace 的当前指针，也不自动打开其他页面。
显式 workspace 覆盖成功后，可以更新当前会话缓存；不能写入用户级 `current_workspace_*` 或其他共享默认值。

## 结果报告

至少汇报：

- workspace 名称和生命周期；
- commit 是否创建、commit ID；
- 远端是否推送成功；
- 每个项目的 remote/branch/HEAD/dirty 采集结果；
- 未纳入的候选项目和范围外变更；
- 若有冲突或失败，明确说明知识库和代码项目各自停在哪里。
