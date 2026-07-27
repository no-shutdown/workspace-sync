---
name: workspace-sync
description: 个人开发知识库与跨设备工作空间管理。知识库是一个用户配置的 Git 仓库，仓库内每个文件夹都是相互隔离的开发迭代（workspace）。支持 config、pull、list、compile、push；compile 将规划工具或当前会话中的原始开发资料整理成 Karpathy LLM Wiki 风格的开发任务图谱。用户提到 workspace-sync、换设备继续开发、选择迭代、个人开发知识库、开发任务图谱或 compile 时使用本 skill。
---

# workspace-sync

## 使命

`workspace-sync` 管理的是个人开发知识库，不是当前代码项目的副本，也不是对话备份服务。知识库由用户配置的一个 Git 仓库承载，并同时作为 Obsidian Vault：

- 一个顶层 workspace 文件夹代表一个开发迭代。
- 一个 workspace 可以关联多个代码项目、系统和分支。
- 不同 workspace 的原始资料、图谱、任务、决策和历史默认完全隔离。
- `workspace-sync` 自己的仓库就是个人开发知识库，不再维护第二份 workspace 快照或独立存储对象。

本 skill 是一个以文档为接口的深模块：调用方只需要选择命令和当前 workspace，复杂的 Git 同步、项目现场采集、图谱编译和健康检查由下面的流程完成。

## 不可违反的规则

1. **先选 workspace**：任何依赖知识库事实的操作都必须有当前 workspace。没有当前 workspace 时，进入新建流程并让用户输入名称；不猜测名称，不借用其他 workspace。
2. **workspace = iteration**：workspace 是开发迭代本身，不是一次会话、一个代码项目或一份临时总结。
3. **硬隔离**：默认只读取和写入当前 workspace；不跨 workspace 自动加载、解析或创建图谱语义链接。
4. **单一 Git 知识库**：配置只有一个个人开发知识库 Git 仓库。`pull`、`compile`、`push` 都直接作用于这个仓库，不复制出另一份 workspace 内容。
5. **Obsidian CLI 是 Vault 内容接口**：对 Vault 内 Markdown 的读取、创建、修改、搜索、链接查询和打开统一使用官方 Obsidian CLI。Git 只负责仓库版本和远端同步，不解释 Wiki 语义。
6. **原始资料自由且不可覆盖**：原始资料只要求 Markdown 扩展名，不要求固定章节、frontmatter 或模板。新的规划记录追加为新文档，不覆盖旧资料；原始资料冲突时保留双方。
7. **图谱是共享维护层**：用户和 AI 都可以维护节点页面；`总览.md`、`索引.md` 和 `视图/` 是 compile 生成页面，不是人工事实编辑入口。
8. **任务状态需要确认**：AI 可以提出候选任务和状态变更，但不能仅凭推断、子任务完成、依赖变化或代码提交静默修改正式任务状态。
9. **代码不进入知识库**：只记录项目身份、Git remote、分支、HEAD 和 dirty 状态；不复制代码、不保存未提交代码内容。
10. **远端同步不强制覆盖**：push 遇到远端变化先同步并整合；冲突停止，禁止 force push。pull 遇到本地知识库未提交变化也停止，不覆盖现场。

## 命令接口

| 命令 | 接口 | 作用 |
| --- | --- | --- |
| `config` | `/workspace-sync config` | 配置一个知识库 Git 仓库、分支、本地 Vault 路径和 Obsidian Vault 名称 |
| `pull` | `/workspace-sync pull [workspace-name]` | 同步知识库 Git 仓库，选择/恢复当前 workspace，并打开图谱总览 |
| `list` | `/workspace-sync list` | 从本地 Vault 列出 workspace；选择后设置本地当前指针并打开图谱总览，不自动 pull |
| `migrate` | `/workspace-sync migrate` | 将当前 workspace 的旧英文目录、节点类型和链接安全迁移为中文布局 |
| `compile` | `/workspace-sync compile` | 在 AI 对话中把当前 workspace 的原始资料或已确认会话结论编译为开发图谱 |
| `push` | `/workspace-sync push` | 采集当前 workspace 关联项目现场，提交当前 workspace 的知识变更并推送 Git 远端 |

`compile` 和 `migrate` 是 AI 对话中的工作指令，不要求独立 Shell 进程推断当前聊天内容。`migrate` 只在用户明确确认后执行。`push` 不自动触发 compile；用户要先编译再推送时，依次执行 `compile`、`push`。

## 本地配置与仓库配置

本地配置默认位于当前 CLI 状态目录的 `skills/workspace-sync/config.json`。它只保存本机访问知识库所需的信息，不写入知识库事实：

```json
{
  "repository": {
    "url": "git@gitlab.example.com:me/dev-knowledge.git",
    "branch": "main",
    "path": "C:/Users/me/Obsidian/dev-knowledge"
  },
  "obsidian": {
    "vault": "dev-knowledge"
  },
  "state_file": null
}
```

- `repository.url`：个人开发知识库 Git 远端链接，支持 SSH 或 HTTPS；认证交给 Git Credential Manager、SSH agent 或系统 Git 配置，不把 token 写进知识库。
- `repository.branch`：知识库同步分支，默认 `main`。
- `repository.path`：本机 Git clone，同时作为 Obsidian Vault 路径。
- `obsidian.vault`：Obsidian CLI 使用的 Vault 名称；若 CLI 以路径定位，则使用 `repository.path`。
- `state_file`：本地状态文件路径；为空时使用当前 CLI 状态目录下的 `workspace-sync/local-state.json`。

本地状态文件只保存设备本地信息，例如：

```json
{
  "version": 1,
  "current_workspace_id": "ws-20260727-abc123",
  "current_workspace_name": "task-graph",
  "project_paths": {
    "gitlab.example.com/team/api": "C:/work/api"
  }
}
```

`current_workspace_*` 和项目本地路径不能写入共享 Git 知识库；不同设备可以同时选择不同 workspace。

## 知识库仓库结构

```text
knowledge-base/
├── SCHEMA.md
└── <workspace-name>/
    ├── 工作区.md
    ├── 原始资料/
    │   └── *.md
    └── 图谱/
        ├── 总览.md
        ├── 索引.md
        ├── 日志.md
        ├── 节点/
        │   ├── 项目/
        │   ├── 系统/
        │   ├── 能力/
        │   ├── 能力缺口/
        │   ├── 任务/
        │   └── 决策/
        ├── 视图/
        │   ├── 系统架构.md
        │   ├── 能力缺口.md
        │   ├── 开发任务.md
        │   └── 系统联调.md
        └── 候选/
```

### `SCHEMA.md`

根目录共享规则，定义节点类型、关系语义、状态值、原始资料/图谱边界和编译约束；不保存任何 workspace 事实。

### `工作区.md`

workspace 根目录的元数据页，至少保存稳定 `workspace_id`、名称、生命周期（`active`、`paused`、`archived`）、创建/更新时间和归档原因。文件夹改名不改变 `workspace_id`。

### `原始资料/`

规划工具（例如 superpowers、grill-with-docs）或用户提供的自由格式 Markdown。原始资料是输入证据，不要求格式，不被 compile 覆盖。新一轮规划追加新文件；完整对话不是 v1 的必需输入。

### `图谱/节点/`

正式开发图谱节点。正式类型收敛为：项目、系统、能力、能力缺口、任务、决策。联调不再单独建节点，使用系统之间的“需要联调”关系；技术决策是支撑对象，不默认进入主架构视图。

节点文件名统一为 `类型-名字.md`，例如 `系统-订单平台.md`、`能力缺口-订单导入缺少幂等校验.md`。文件名和标题面向用户使用中文；frontmatter 中的稳定 `id` 仍用于追踪身份，节点改名时不改变它。若同一类型下出现同名节点，不自动合并，文件名在中文名称后追加稳定 ID 短后缀并报告重复候选。

每个节点是一个 Markdown 文件，YAML 只保存身份、类型、状态、时间和来源；语义关系写在正文中：

```md
---
id: task-xxxx
type: 任务
title: 实现订单导入
aliases:
  - task-xxxx
status: 待开始
created_at: 2026-07-27T10:00:00+08:00
updated_at: 2026-07-27T10:00:00+08:00
source_refs:
  - ../../../原始资料/2026-07-27-planning.md
---

## 关系

- 解决：[[能力缺口-订单导入缺少幂等校验]]
- 关联项目：[[项目-订单服务]]
```

关系必须是有语义的 workspace 内部 Wiki 链接；不在 YAML 中维护第二份关系表。

### `图谱/候选/`

compile 从明确来源推导出的待确认候选。候选有临时身份、来源、推导理由和项目/节点关联，但不属于正式图谱、正式任务统计或健康检查。用户确认后创建新的正式节点，候选页保留“已转化”或“已拒绝”历史。

### `总览.md`、`索引.md`、`日志.md` 和 `视图/`

- `总览.md`：生成的当前接手视图，汇总目标、分层视图入口、能力缺口、任务状态、阻塞、待确认项、健康 warning 和下一步。
- `索引.md`：生成的完整节点目录、状态、来源数量以及候选/冲突/健康提示。
- `日志.md`：追加式操作审计日志。健康问题只在首次出现、状态变化或解决时追加；重复检查不制造日志噪声。
- `视图/系统架构.md`：只展示系统层级、系统提供的能力和项目实现映射。
- `视图/能力缺口.md`：展示系统、能力缺口和解决任务的链路。
- `视图/开发任务.md`：只展示任务分解、状态和依赖关系。
- `视图/系统联调.md`：只展示系统之间的需要联调关系及其关联任务。

`总览.md`、`索引.md` 和 `视图/` 可以重建，不能作为人工事实编辑入口。`日志.md` 只能追加，不能覆盖历史。

## 开发图谱规则

图谱优先于任务树，但默认不把所有类型放进同一张图。系统架构、能力缺口、开发任务和系统联调分别生成视图；整体图谱仍允许跨项目、跨系统和跨任务连接。

### 节点与关系

- 项目是代码开发对象；任务可以关联多个项目。
- 系统是可提供/消费能力并需要与其他系统交互的边界；一个系统可由多个项目共同实现。
- 能力描述系统应提供或需要的行为。
- 能力缺口描述目标能力与当前实际能力之间的缺失。
- 任务是可执行、可跟踪的工作节点，通常从能力缺口或系统联调需要派生。
- 技术决策记录已经确认的实现选择与理由，是支撑对象而不是主架构层。

关系使用明确词汇，例如：包含、提供、缺少、目标能力、需要联调、关联系统、解决/实现、派生自、依赖、关联项目、受决策约束、分解为、取代。`包含`只用于系统架构层级；`分解为`只用于任务层级；依赖与任务分解是不同关系。系统联调使用“需要联调”关系，不创建联调点节点。

编译前按“中文类型 + 规范化标题”检查重复；发现完全重复或高度疑似同义节点时，只生成 `图谱/候选/` 中的重复候选，列出来源和合并理由，不自动删除或合并。

正式任务状态固定为：`待开始`、`进行中`、`已阻塞`、`已完成`、`已取消`。状态变更、任务修订、替代、软删除、重开和项目关联变化都追加历史；整体改写目标时保留旧任务并创建新任务。

## compile 工作流

执行 `/workspace-sync compile` 时：

1. 确认本地当前 workspace。不存在时要求用户输入名称并初始化 workspace 目录。
2. 通过 Obsidian CLI 读取当前 workspace 的原始资料、图谱节点、候选和 `SCHEMA.md`；不读取其他 workspace。
3. 发现新增/变化的原始资料时，保留原文并编译受影响的节点、关系、冲突、待确认项和候选。原始资料为自由格式，不强行套模板。
4. 如果没有原始资料，但当前会话已经形成用户明确确认的开发任务或规划结论，先生成一份新的原始资料 Markdown，再继续编译；没有确认的想法只能保留为待确认项，不能成为正式事实。
5. 只把明确陈述写入当前图谱；“可能、考虑、待确认”等不确定内容进入待确认项。原始资料冲突时保留双方，未冲突内容仍可增量编译。
6. 候选任务必须等待用户明确确认；不能因为 AI 推导、子任务完成或代码提交自动创建/完成正式任务。
7. 通过 Obsidian CLI 重建 `图谱/总览.md`、`图谱/索引.md` 和 `图谱/视图/` 下的分层视图，并对当前 workspace `图谱/节点/` 页面执行链接健康检查。未解析链接、孤立节点、无出链节点是 warning，不自动创建占位节点或修复人工页面。
8. 健康问题使用稳定指纹追踪生命周期；只有首次出现、状态变化或解决时记录 `图谱/日志.md`。没有知识或健康状态变化时不创建空 commit。
9. 有实际变更时创建本地 Git commit；warning 不阻断 commit。发生 CLI/写入等执行错误时不自动 commit，并报告现场。
10. compile 不推送远端；需要跨设备同步时再执行 `push`。

## push 工作流

`push` 只作用于当前 workspace：

1. 读取当前 workspace 的正式项目关联，并把当前 cwd 中发现但未关联的仓库列为候选，要求确认；不扫描整台机器。
2. 对已确认项目采集规范化 Git remote、当前分支、HEAD、upstream 和 dirty 状态。dirty 项目仍允许保存知识库，但只记录 dirty，不复制代码。
3. 检查知识库 Git 远端变化；需要时先 fetch/rebase，冲突就停止，不 force push。
4. 只把当前 workspace 目录的知识库变更加入本次提交。其他 workspace 或根目录 `SCHEMA.md` 的变化单独警告，不静默带入。
5. 提交并推送当前知识库 Git 分支。push 不自动 compile。

## pull 工作流

`pull` 同步同一个知识库 Git 仓库，不复制 workspace 快照：

1. 检查本地知识库是否有未提交变更；有则停止并要求先处理。
2. fetch 并以安全方式整合配置分支；冲突停止，不覆盖本地图谱。
3. 若指定 workspace，选择它；否则列出本地 workspace 并让用户选择。没有 workspace 时进入新建流程并让用户命名。
4. 设置本地当前 workspace 指针，并通过 Obsidian CLI 打开 Vault 和该 workspace 的 `图谱/总览.md`。
5. 按记录的项目 remote/分支/HEAD 尝试恢复本地干净代码项目；dirty、路径缺失或 commit 缺失时跳过并报告。

## list 工作流

`list` 只查看本地 Vault 中的 workspace 文件夹，不自动 pull。展示 workspace 名称、生命周期和最近更新时间；用户选择后设置本地当前指针并打开 `图谱/总览.md`。需要远端变化时明确执行 `pull`。

## 新 AI 会话启动上下文

新会话开始工作前必须确认当前 workspace。默认加载：根 `SCHEMA.md`、当前 workspace 的 `工作区.md`、`图谱/总览.md`、活动任务及其关联项目/系统/缺口/决策节点。原始资料和完整历史按需展开；若用户指定会话焦点任务，则优先加载该任务的局部子图，不自动猜测焦点。

## 项目现场恢复规则

项目节点存储规范化 Git remote；本机路径只存放在本地状态文件。路径解析顺序为已保存映射、当前 cwd、用户明确提供的路径；不扫描所有代码仓库。pull 只在代码工作区干净且目标 commit 可用时切分支/恢复 HEAD，绝不强制覆盖未提交代码。

## 相关文档

- 命令流程：`action/config.md`、`action/list.md`、`action/pull.md`、`action/compile.md`、`action/push.md`
- 迁移流程：`action/migrate.md`
- Git 知识库仓库：`references/setup.md`、`references/git-repository.md`
- Obsidian CLI：`references/obsidian-cli.md`
- workspace 布局：`references/workspace-layout.md`
- 分层视图：`references/layered-views.md`
- 项目现场：`references/project-state.md`
