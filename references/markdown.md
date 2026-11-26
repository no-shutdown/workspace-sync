# Markdown 内容接口

默认直接使用本地文件系统读取、搜索、创建、修改和移动 Markdown。知识库 Git 仓库同时可作为 Obsidian Vault，通过 [Obsidian CLI](obsidian-cli.md) 使用现有的操作流程。HTML 导出独立读取同一份文件，详见 [HTML 导出](html.md)。

## 选择内容接口

- 新配置默认使用本地文件。配置 `obsidian.enabled: true` 和 `obsidian.vault` 可选择使用现有 Obsidian CLI。旧配置只写 `obsidian.vault` 时，也可在 CLI 可用的情况下继续使用；设为 `obsidian.enabled: false` 明确使用本地文件。
- 在操作开始前检查可选的 CLI 是否能定位此知识库路径。不可用或路径不匹配时提示一次，并使用本地文件。在一次写入中途遇到错误时报告错误、保留执行现场，避免自动切换接口重试。
- 同一次操作的 workspace 校验、读写和链接健康范围适用于所选接口。Git 只处理同步和版本，不负责内容语义。

## 读取与查询

- `pull`/`list` 选择前只枚举知识库根的一级目录，并从候选 `工作区.md` 的开头 frontmatter 提取 `workspace_id`、`name`、`lifecycle` 和 `updated_at`。选择后重新读取并校验目标的稳定 ID。
- 读取、搜索和遍历使用已校验的 workspace 路径。根 `SCHEMA.md` 作为规则文件单独读取。拒绝路径越界及指向 workspace 之外的符号链接，不借用其他 workspace 的同名页面。
- 查询出链和反链时，分别读取节点正文的链接、检查当前 workspace 内指向该节点的链接。按正文语义区分 `分解为`、`依赖` 等关系。目标可用文件名、workspace 内的相对路径或 frontmatter 的稳定 ID/别名匹配，多个同名目标视为未解析。跳过代码块、行内代码和 frontmatter 样例。
- 健康检查只扫描 `图谱/节点/` 的正式页面。记录无法解析、孤立、无出链和树结构等问题，保留原文并按编译流程报告。

## 写入

- 使用 UTF-8。原始资料用新文件名创建。保留既有节点身份、来源和历史；日志只追加。
- 重建生成页面时在同目录写临时文件并原子替换。
