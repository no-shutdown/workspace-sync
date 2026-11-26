# Obsidian CLI 适配器

Obsidian CLI 是可选的 Markdown 内容接口，启用规则见 [Markdown 内容接口](markdown.md)。使用前确保 Obsidian CLI 已安装，并按本机 Obsidian 版本要求运行 Obsidian；具体命令和要求见 [官方 CLI 文档](https://obsidian.md/help/cli)。HTML 导出独立读取本地文件。

## 适配器职责

Obsidian CLI 适配器负责：

- 打开 Vault 和指定 workspace 页面；
- 读取、创建、追加和修改 Markdown；
- 搜索原始资料、节点和候选页面；
- 查询 links、backlinks、unresolved、orphans、deadends；
- 执行 Obsidian 原生命令；
- 返回可供 compile 生成总览、索引、分层视图和健康报告的结果。

Git 适配器负责 clone、fetch、commit、rebase 和 push，不与本适配器交换 Wiki 语义。

## 命令形态示例

具体参数以本机 CLI 版本为准，以下只表达调用意图：

```text
obsidian vault="dev-knowledge" open path="数据导入迭代/图谱/总览.md"
obsidian vault="dev-knowledge" read path="数据导入迭代/工作区.md"
obsidian vault="dev-knowledge" create path="数据导入迭代/原始资料/2026-07-27-规划.md" content="..."
obsidian vault="dev-knowledge" append path="数据导入迭代/图谱/日志.md" content="..."
obsidian vault="dev-knowledge" folders folder=""
obsidian vault="dev-knowledge" files folder="数据导入迭代" ext=md
obsidian vault="dev-knowledge" search query="数据导入迭代"
obsidian vault="dev-knowledge" unresolved
obsidian vault="dev-knowledge" orphans
obsidian vault="dev-knowledge" deadends
obsidian vault="dev-knowledge" open path="数据导入迭代/图谱/视图/开发任务.md"
obsidian vault="dev-knowledge" links path="数据导入迭代/图谱/节点/任务/任务-开发总任务.md"
obsidian vault="dev-knowledge" links path="数据导入迭代/图谱/节点/任务/任务-实现订单导入.md"
obsidian vault="dev-knowledge" backlinks path="数据导入迭代/图谱/节点/任务/任务-实现订单导入.md"
```

## workspace 选择前的预边界发现

当前会话 workspace 尚未建立时，Obsidian CLI 的读取仅限于预边界的控制元数据发现：使用 `folders folder=""` 列出 Vault 根目录一级文件夹，并读取每个候选 workspace 的 `工作区.md` 中用于选择的稳定 `workspace_id`、显示名称、生命周期和 `updated_at`。这些字段只用于控制选择，不属于知识库事实。

在用户选择候选并重新读取、验证所选 `工作区.md` 的稳定 `workspace_id` 之前，不得读取候选 workspace 的图谱页面、workspace 正文、links/backlinks/files/search 结果、任务、架构或其他上下文事实。选择前也不读取用户级 `current_workspace_*`，不写会话缓存、共享 current pointer 或其他 fallback state；验证通过后才可建立当前 workspace 边界并执行正常的 workspace-scoped reads。

## 局部上下文查询意图

建立当前会话 workspace 边界后，开始任何 workspace-scoped 的 links/backlinks/files/search/read 查询前，必须：

- 默认读取 `<run_dir>/.workspace-sync-cache/sessions/<session-id>.json`；
- 或接受显式 workspace 作为单次覆盖；
- 缓存缺失、损坏、workspace 不存在、稳定 ID 不匹配，或运行环境缺少 `session_id` / `run_dir` 且又没有显式 workspace 时，都必须停止读取知识库事实；
- 不回退到用户级 `current_workspace_*`，也不从 Vault 全局结果猜测当前 workspace。

上下文装配时，查询结果必须限定在当前 workspace，并按关系语义使用：

- `links path=<焦点任务>`：读取焦点任务正文中的出边，识别 `分解为`、`依赖`、`解决` 和 `涉及系统` 的直接端点；再对端点页面执行 `links`，读取架构的 `目标能力`、`提供`、`存在缺口`、`包含` 和 `需要联调`。
- `backlinks path=<焦点任务>`：读取任务的反向链接，沿标注为 `分解为` 的链接追溯父级链，并筛选标注为 `依赖` 且状态未完成的直接依赖者；不能把普通 backlink 或页面相邻当作父子关系。
- `files folder=<当前 workspace>`、`search query=<来源或支撑关键词>`：只在当前 workspace 范围内查找 `source_refs` 指向的原始资料和直接关联的项目/决策/联调说明；结果需要回到页面正文或 frontmatter 验证。
- `unresolved`、`orphans`、`deadends`：用于健康检查和 warning；未解析链接的显示文本不是事实，也不能因此创建占位节点或自动修复关系。

生成视图的查询只用于导航和摘要。若视图内容与正式节点正文或语义 Wiki 链接不一致，以节点页面为准并报告生成页面过期；不要通过全 Vault 搜索把其他 workspace 的结果带入当前上下文。

## 读取边界

除上述预边界控制元数据发现外，每次调用显式带当前 workspace 路径或在读取结果后按 workspace 根目录过滤。没有当前会话 workspace 时，停止读取知识库事实，不执行 Vault 范围内的 links/backlinks/files/search 推断。禁止用 Vault 全局搜索结果直接写入当前 workspace；跨 workspace 的结果只能被忽略或作为用户显式请求的普通参考。

## 写入边界

- 原始资料创建后不覆盖；新输入使用新文件名。
- 正式节点修改必须保留稳定 ID、来源和历史。
- 总览、索引和视图可整体重建。
- 日志只能追加；健康问题重复检查不追加无变化记录。
- 健康检查只扫描 `图谱/节点/`，是只读的，不创建占位节点、不修复人工页面。

## CLI 失败

操作开始前发现 CLI 不可用或无法定位正确 Vault 时，报告原因并使用文件接口。使用 CLI 执行写入后遇到错误时报告现场，避免自动切换接口重试整次操作。
