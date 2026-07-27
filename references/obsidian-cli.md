# Obsidian CLI 适配器

官方 Obsidian CLI 是知识库 Vault 的唯一内容交互接口。使用前确保 Obsidian CLI 已安装，并按本机 Obsidian 版本要求运行 Obsidian；CLI 的具体命令和安装要求以[官方 CLI 文档](https://obsidian.md/help/cli)为准。

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

## 读取边界

每次调用显式带当前 workspace 路径或在读取结果后按 workspace 根目录过滤。禁止用 Vault 全局搜索结果直接写入当前 workspace；跨 workspace 的结果只能被忽略或作为用户显式请求的普通参考。

## 写入边界

- 原始资料创建后不覆盖；新输入使用新文件名。
- 正式节点修改必须保留稳定 ID、来源和历史。
- 总览、索引和视图可整体重建。
- 日志只能追加；健康问题重复检查不追加无变化记录。
- 健康检查只扫描 `图谱/节点/`，是只读的，不创建占位节点、不修复人工页面。

## CLI 失败

CLI 不可调用、Vault 无法定位、命令返回写入错误时，compile/pull/list 等相关操作明确失败并报告原因。不要悄悄切换到自定义文件读写接口，以免形成第二套 Vault 事实来源。
