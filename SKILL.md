---
name: workspace-sync
description: 个人开发知识库与跨设备工作空间管理。知识库是一个用户配置的 Git 仓库，仓库内每个文件夹都是相互隔离的开发迭代（workspace）。支持 config、pull、list、compile、push；compile 将规划工具或当前会话中的原始开发资料整理成 Karpathy LLM Wiki 风格的开发任务图谱。用户提到 workspace-sync、换设备继续开发、选择迭代、个人开发知识库、开发任务图谱或 compile 时使用本 skill。
---

# workspace-sync

## 使命

`workspace-sync` 管理的是个人开发知识库，不是当前代码项目的副本，也不是对话备份服务。知识库由用户配置的一个 Git 仓库承载，并同时作为 Obsidian Vault：

- 一个顶层 workspace 文件夹代表一个开发迭代。
- 新建 workspace 使用中文的用户可读名称；稳定 `workspace_id` 不随文件夹改名变化。
- 一个 workspace 可以关联多个代码项目、系统和分支。
- 不同 workspace 的原始资料、图谱、任务、决策和历史默认完全隔离。
- `workspace-sync` 自己的仓库就是个人开发知识库，不再维护第二份 workspace 快照或独立存储对象。

本 skill 是一个以文档为接口的深模块：调用方只需要选择命令并建立当前会话的 workspace 边界，复杂的 Git 同步、项目现场采集、图谱编译和健康检查由下面的流程完成。

## 不可违反的规则

1. **先建立当前会话 workspace 边界**：任何依赖知识库事实的操作都必须先解析当前会话缓存或显式 workspace，并按稳定 `workspace_id` 校验目标 `工作区.md`。没有有效会话上下文且没有经验证的显式 workspace 时，通常停止读取知识库事实并要求用户选择；但 `list`/`pull` 允许一个严格的预边界发现例外：只能列出 Vault 根目录候选文件夹并读取候选 `工作区.md` 的 `workspace_id`、显示名称、生命周期和 `updated_at` 控制元数据，不能读取图谱、workspace 正文、links/backlinks/files/search、关系、任务、架构或其他上下文，也不能写缓存或 fallback state。用户明确选择后，必须重新读取所选 `工作区.md` 并验证稳定 ID，验证通过后才能执行焦点检查、缓存绑定、打开总览或其他 workspace-scoped reads；如果 `session_id` 或 `run_dir` 不可用，经验证的显式 workspace 只允许本次一次性操作，不写任何回退状态；不读取全局 `current_workspace_*`，不猜测名称，也不借用其他 workspace。
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
| `pull` | `/workspace-sync pull [工作区名称]` | 同步知识库 Git 仓库并选择/恢复当前 workspace；仅在 `session_id`、`run_dir` 均有效且会话缓存可写时绑定当前会话缓存，否则显式用户选择仅本次生效、非持久化，不写用户级或全局回退状态；完成选择后打开图谱总览 |
| `list` | `/workspace-sync list` | 从本地 Vault 列出 workspace，不自动 pull；仅在 `session_id`、`run_dir` 均有效且会话缓存可写时将用户选择绑定到当前会话缓存，否则显式用户选择仅本次生效、非持久化，不写用户级或全局回退状态；完成选择后打开图谱总览 |
| `migrate` | `/workspace-sync migrate [工作区名称]` | 将当前会话 workspace 的旧英文目录、节点类型和链接安全迁移为中文布局；可用显式 workspace 做单次覆盖 |
| `compile` | `/workspace-sync compile [工作区名称]` | 在 AI 对话中把当前会话 workspace 的原始资料或已确认会话结论编译为开发图谱；可用显式 workspace 做单次覆盖 |
| `push` | `/workspace-sync push [工作区名称]` | 采集当前会话 workspace 关联项目现场，提交当前 workspace 的知识变更并推送 Git 远端；可用显式 workspace 做单次覆盖 |

`compile` 和 `migrate` 是 AI 对话中的工作指令，不要求独立 Shell 进程推断当前聊天内容。`migrate` 只在用户明确确认后执行。`compile`、`push` 和 `migrate` 默认读取当前会话缓存，也支持显式 workspace 作为单次覆盖。`push` 不自动触发 compile；用户要先编译再推送时，依次执行 `compile`、`push`。

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
- `state_file`：设备级状态文件路径；为空时使用当前 CLI 状态目录下的 `workspace-sync/local-state.json`。它只保存用户/设备级配置和 `project_paths`；会话缓存契约见 `references/session-state.md`。

本地状态文件只保存设备本地信息，例如：

```json
{
  "version": 1,
  "project_paths": {
    "gitlab.example.com/team/api": "C:/work/api"
  }
}
```

旧 `current_workspace_*` 只作为历史字段保留并忽略；项目本地路径不能写入共享 Git 知识库。当前 workspace 与聚焦任务改为当前运行目录下的会话缓存，例如：

```json
{
  "version": 1,
  "session_id": "session-A",
  "workspace_id": "ws-20260727-abc123",
  "workspace_name": "数据导入迭代",
  "focus_task_id": null
}
```

缓存路径固定为 `<run_dir>/.workspace-sync-cache/sessions/<session-id>.json`。会话启动时确定 `run_dir`；后续命令不随 Vault 路径迁移缓存。两个会话可以选择同一个 workspace，但不能共享同一个会话文件。`focus_task_id` 的作用域固定为缓存中的 `workspace_id`：只允许保存并使用该 workspace 内经验证的正式 `任务` 节点 ID，切换 workspace 时不得未经验证地沿用；没有明确且有效的新焦点时写入 `null`，由用户随后选择，不能推断。

## 知识库仓库结构

```text
knowledge-base/
├── SCHEMA.md
└── <工作区名称>/
    ├── 工作区.md
    ├── 原始资料/
    │   └── *.md
    └── 图谱/
        ├── 总览.md
        ├── 索引.md
        ├── 日志.md
        ├── 节点/
        │   ├── 系统/
        │   ├── 能力/
        │   ├── 缺口/
        │   └── 任务/
        │       └── 任务-开发总任务.md
        ├── 视图/
        │   ├── 架构地图.md
        │   ├── 开发路线.md
        │   ├── 开发任务.md
        │   └── 系统联调.md
        ├── 说明/
        │   ├── 项目/
        │   ├── 决策/
        │   └── 联调/
        └── 候选/
```

### `SCHEMA.md`

根目录共享规则，定义节点类型、关系语义、状态值、原始资料/图谱边界和编译约束；不保存任何 workspace 事实。

### `工作区.md`

workspace 根目录的元数据页，至少保存稳定 `workspace_id`、名称、生命周期（`active`、`paused`、`archived`）、创建/更新时间和归档原因。文件夹改名不改变 `workspace_id`。

### `原始资料/`

规划工具（例如 superpowers、grill-with-docs）或用户提供的自由格式 Markdown。原始资料是输入证据，不要求格式，不被 compile 覆盖。新一轮规划追加新文件；完整对话不是 v1 的必需输入。

### `图谱/节点/`

正式开发图谱节点。正式类型只有：系统、能力、缺口、任务。项目和决策属于 `图谱/说明/` 下的支撑记录，不进入正式节点索引和主 Mermaid 图；联调使用系统之间的“需要联调”关系。

`图谱/说明/项目/`、`图谱/说明/决策/` 和 `图谱/说明/联调/` 下的页面是支撑记录，不使用正式节点 `type`；目录语义就是它们的类别。遇到 `项目`、`决策`、`联调点`、`integration`、`epic`、`architecture`、`development-task` 等未知或旧类型时，不得把它们当成第五类正式节点或 `task_role` 值；保留原页面并迁移到支撑记录或 `图谱/候选/`，等待明确映射。

节点文件名统一为 `类型-名字.md`，例如 `系统-业务平台.md`、`缺口-数据导入缺少幂等校验.md`。frontmatter 的 `type` 使用同样的中文值。文件名和标题面向用户使用中文；稳定 `id` 仍用于追踪身份，节点改名时不改变它。若同一类型下出现同名节点，不自动合并，文件名在中文名称后追加稳定 ID 短后缀并报告重复候选。

每个 workspace 的正式任务树只有一个根任务：`图谱/节点/任务/任务-开发总任务.md`。它仍使用正式类型 `任务`，只额外标记 `task_role: 根任务`；`task_role` 是任务元数据，不是新的正式节点类型。除根任务外，每个正式任务必须通过且只能通过一条 `分解为` 路径归属任务树；`依赖` 可以跨分支，但不改变父子层级。

每个节点是一个 Markdown 文件，YAML 只保存身份、类型、任务角色（仅根任务需要）、状态、时间和来源；语义关系写在正文中：

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

- 解决：[[缺口-数据导入缺少幂等校验]]
- 涉及系统：[[系统-业务平台]]
```

关系必须是有语义的 workspace 内部 Wiki 链接；项目关联和决策引用属于支撑信息，不作为架构关系；不在 YAML 中维护第二份正式关系表。

项目记录保存于 `图谱/说明/项目/`，负责 remote、分支、HEAD、upstream 和 dirty 状态；本机路径仍只保存于本地 state。决策记录保存于 `图谱/说明/决策/`，保留技术选择及理由。需要追溯时可以引用这些说明，但它们不参与主图谱视图。

### `图谱/候选/`

compile 从明确来源推导出的待确认候选。候选有临时身份、来源、推导理由和项目/节点关联，但不属于正式图谱、正式任务统计或健康检查。用户确认后创建新的正式节点，候选页保留“已转化”或“已拒绝”历史。

### `总览.md`、`索引.md`、`日志.md` 和 `视图/`

- `总览.md`：生成的当前接手视图，汇总目标、当前架构位置、分层视图入口、缺口、任务状态、阻塞、待确认项、健康 warning 和下一步。
- `索引.md`：生成的四类正式节点目录、支撑记录、状态、来源数量以及候选/冲突/健康提示。
- `日志.md`：追加式操作审计日志。健康问题只在首次出现、状态变化或解决时追加；重复检查不制造日志噪声。
- `视图/架构地图.md`：只展示系统层级、系统提供的能力和各系统缺口摘要。
- `视图/开发路线.md`：只作为架构与任务之间的桥接索引，按系统/缺口列出解决任务，不建立第二套任务层级。
- `视图/开发任务.md`：从 `任务-开发总任务` 展开任务树，展示任务状态、依赖、涉及系统、解决缺口、支撑记录和下一步。
- `视图/系统联调.md`：只展示系统之间的需要联调关系及其关联任务。

`总览.md`、`索引.md` 和 `视图/` 可以重建，不能作为人工事实编辑入口。`日志.md` 只能追加，不能覆盖历史。

## 开发图谱规则

正式图谱事实分成三个互补的阅读投影：`架构地图.md` 是系统、能力和缺口组成的架构图；`开发任务.md` 是以 `任务-开发总任务` 为根的任务树；`开发路线.md` 是从架构对象指向解决任务的桥接索引。`系统联调.md` 单独呈现系统协作关系；总览页同时给出架构面包屑和任务面包屑。默认不把所有类型和所有关系塞进同一张图，支撑记录也不进入主图。

### 节点与关系

- 系统是可提供/消费能力并需要与其他系统交互的边界；一个系统可由多个项目共同实现。
- 能力描述系统应提供或需要的行为。
- 缺口描述目标能力与当前实际能力之间已确认的缺失。
- 任务是可执行、可跟踪的工作节点，通常从缺口或系统联调需要派生。

关系使用明确词汇：包含、提供、存在缺口、目标能力、解决、涉及系统、需要联调、分解为、依赖。`包含`只用于系统架构层级；`分解为`只用于任务到任务的父子层级；`依赖`只表示跨任务前置条件，不改变任务树；`解决`、`涉及系统`和`需要联调`是跨域定位或协作关系，不作为任务父子线。规划资料中“从缺口/联调需要派生任务”只是来源描述，不自动写成 `派生自` 正式关系。`取代`、`派生自`、`参考决策`只用于历史或支撑追溯，不进入主视图。系统联调使用“需要联调”关系，不创建联调点节点。

任务树编译必须验证：根任务恰好一个、每个非根任务恰好一个父任务、`分解为` 无环且所有端点都是任务、每个任务都能从根任务到达。缺失父任务、多父任务、循环或不可达任务只生成健康 warning 和候选归属，不自动补父级、不把 `依赖` 改成 `分解为`，也不改写用户确认的任务状态。

编译前按“中文类型 + 规范化标题”检查重复；发现完全重复或高度疑似同义节点时，只生成 `图谱/候选/` 中的重复候选，列出来源和合并理由，不自动删除或合并。

正式任务状态固定为：`待开始`、`进行中`、`已阻塞`、`已完成`、`已取消`。状态变更、任务修订、替代、软删除、重开和项目关联变化都追加历史；整体改写目标时保留旧任务并创建新任务。

## compile 工作流

执行 `/workspace-sync compile` 时：

1. 先解析当前会话缓存或显式 workspace 覆盖，并按稳定 `workspace_id` 校验目标 `工作区.md`。默认解析要求存在并通过校验的当前会话缓存；缓存缺失、损坏、workspace 不存在或 ID 不匹配时，默认行为停止并要求重新选择。不读取旧用户级 `current_workspace_*` 或其他全局 current pointer；如果 `session_id` 或 `run_dir` 不可用，经验证的显式 workspace 只允许本次一次性、非持久化操作，不写任何回退状态；既没有有效会话上下文也没有显式 workspace 时停止。
2. 通过 Obsidian CLI 读取已校验 workspace 的原始资料、图谱节点、候选和 `SCHEMA.md`；不读取其他 workspace。
3. 发现新增/变化的原始资料时，保留原文并编译受影响的节点、关系、冲突、待确认项和候选。原始资料为自由格式，不强行套模板。
4. 如果没有原始资料，但当前会话已经形成用户明确确认的开发任务或规划结论，先生成一份新的原始资料 Markdown，再继续编译；没有确认的想法只能保留为待确认项，不能成为正式事实。
5. 只把明确陈述写入当前图谱；“可能、考虑、待确认”等不确定内容进入待确认项。原始资料冲突时保留双方，未冲突内容仍可增量编译。
6. 候选任务必须等待用户明确确认；不能因为 AI 推导、子任务完成或代码提交自动创建/完成正式任务。只有输入明确给出任务内容时才可创建任务；“有几个任务”这类数量描述不能生成占位任务。
7. 通过 Obsidian CLI 重建 `图谱/总览.md`、`图谱/索引.md` 和 `图谱/视图/` 下的分层视图；先验证任务树根、唯一父级、可达性和无环性，再生成 `开发任务.md`。架构图只读取架构关系，`开发路线.md` 只生成架构对象到解决任务的桥接索引。对当前 workspace `图谱/节点/` 页面执行链接健康检查；未解析链接、孤立节点、无出链节点、未定位任务和任务树 warning 不自动创建占位节点、补父级或修复人工页面。
8. 健康问题使用稳定指纹追踪生命周期；只有首次出现、状态变化或解决时记录 `图谱/日志.md`。没有知识或健康状态变化时不创建空 commit。
9. 有实际变更时创建本地 Git commit；warning 不阻断 commit。发生 CLI/写入等执行错误时不自动 commit，并报告现场。
10. compile 不推送远端；需要跨设备同步时再执行 `push`。显式 workspace 覆盖成功后，只有在 `session_id` 和 `run_dir` 均有效且会话缓存可写时，才可以更新当前会话缓存；否则本次操作仅作为一次性、非持久化操作，不写用户级、全局或其他回退状态。

## push 工作流

`push` 只作用于当前 workspace：

1. 先解析当前会话缓存或显式 workspace 覆盖，并按稳定 `workspace_id` 校验目标 workspace。默认解析要求存在并通过校验的当前会话缓存；缓存缺失、损坏、workspace 不存在或身份不匹配时，默认行为安全停止并要求重新选择。不读取用户级 `current_workspace_*` 或其他全局 current pointer；如果 `session_id` 或 `run_dir` 不可用，经验证的显式 workspace 只允许本次一次性、非持久化操作，不写任何回退状态；既没有有效会话上下文也没有显式 workspace 时停止。
2. 读取当前 workspace 的正式项目关联，并把当前 cwd 或当前 `run_dir` 中发现但未关联的仓库列为候选，要求确认；不扫描整台机器。
3. 对已确认项目采集规范化 Git remote、当前分支、HEAD、upstream 和 dirty 状态。dirty 项目仍允许保存知识库，但只记录 dirty，不复制代码。
4. 检查知识库 Git 远端变化；需要时先 fetch/rebase，冲突就停止，不 force push。
5. 只把当前 workspace 目录的知识库变更加入本次提交。其他 workspace 或根目录 `SCHEMA.md` 的变化单独警告，不静默带入。
6. 提交并推送当前知识库 Git 分支。push 不自动 compile。显式 workspace 覆盖成功后，只有在 `session_id` 和 `run_dir` 均有效且会话缓存可写时，才可以更新当前会话缓存；否则本次操作仅作为一次性、非持久化操作，不写用户级、全局或其他回退状态。

## pull 工作流

`pull` 同步同一个知识库 Git 仓库，不复制 workspace 快照：

1. 检查本地知识库是否有未提交变更；有则停止并要求先处理。
2. fetch 并以安全方式整合配置分支；冲突停止，不覆盖本地图谱。
3. 若指定 workspace，验证其 `工作区.md` 并按稳定 `workspace_id` 选择它；否则列出本地 workspace 并让用户明确选择。没有 workspace 时进入新建流程并让用户命名。缓存缺失、损坏或 workspace 身份校验失败时，默认行为停止并要求重新选择，不使用旧指针；如果 `session_id` 或 `run_dir` 不可用，只有经验证的显式 workspace 可以继续一次非持久化操作，不写任何回退状态。
4. `pull` 绑定 workspace 时，只有在当前会话缓存的 `workspace_id` 等于所选 `workspace_id`，且其中的 `focus_task_id` 已在所选 workspace 中验证为正式 `任务` 节点时，才保留该焦点。切换 workspace 时将 `focus_task_id` 清为 `null`，除非本次命令明确提供了所选 workspace 中有效的替代焦点；缓存焦点无效时先清除并报告 warning，再按焦点选择规则继续。只有在 `session_id`、`run_dir` 均有效且会话缓存可写的有效会话上下文中，才使用临时文件加原子替换写入当前会话缓存，不创建用户级或全局回退指针；否则所选显式 workspace 仅作为本次一次性、非持久化操作，不写任何回退指针。通过 Obsidian CLI 打开 Vault 和该 workspace 的 `图谱/总览.md`。
5. 按记录的项目 remote/分支/HEAD 尝试恢复本地干净代码项目；路径解析顺序为用户明确提供的路径、当前 cwd 或 `run_dir` 中匹配 remote 的仓库、用户级 `project_paths`；无法唯一定位、dirty、路径缺失或 commit 缺失时跳过并报告。

## list 工作流

`list` 只查看本地 Vault 中的 workspace 文件夹，不自动 pull。尚未建立 workspace 边界时，只能通过预边界规则读取候选控制元数据供用户选择；用户选择后必须重新读取所选 `工作区.md` 并验证稳定 ID，验证前不得执行焦点检查、缓存绑定、打开总览或其他 workspace-scoped reads。验证通过后，只有在缓存的 `workspace_id` 与所选 workspace 相同且 `focus_task_id` 已验证为该 workspace 的正式 `任务` 时才保留焦点。切换 workspace 时将焦点清为 `null`，除非本次命令明确提供了所选 workspace 中有效的替代焦点；缓存焦点无效时清除并报告 warning，告诉用户可以随后选择新的焦点，不能推断焦点。只有在 `session_id`、`run_dir` 均有效且会话缓存可写时，才将选择绑定到当前会话缓存；否则显式用户选择仅作为一次性、非持久化操作，不写用户级或全局回退状态。`list` 仍只打开 `图谱/总览.md`，需要远端变化时明确执行 `pull`。

## 新 AI 会话启动与局部上下文装配

新会话开始工作前必须先解析当前会话缓存或接受显式 workspace。上下文按以下固定顺序装配：

1. **建立边界**：优先读取 `<run_dir>/.workspace-sync-cache/sessions/<session-id>.json`，或接受显式 workspace 作为单次覆盖，并用 `workspace_id` 校验目标 `工作区.md`。缓存缺失、损坏、workspace 不存在、ID 不匹配或其他 workspace 身份无效时，默认行为停止并要求重新选择；不回退到用户级 `current_workspace_*`。当运行环境缺少 `session_id` 或 `run_dir` 时，经验证的显式 workspace 只执行一次非持久化操作，不写任何回退状态；既没有有效会话上下文也没有显式 workspace 时停止。
2. **选择焦点**：焦点优先级固定为“用户明确指定 > 当前会话缓存中属于当前 `workspace_id` 且已验证的 `focus_task_id` > 当前对话明确确认 > `总览.md` 标记的活动任务”。`focus_task_id` 必须是当前 workspace 中已确认的正式 `任务` 节点；缓存焦点不存在、类型不对、workspace 作用域不符或关系不健康时清除并报告 warning，再按剩余优先级继续，不自动创建、挂接、跨 workspace 搬运或推断焦点。没有可确认焦点时，只展示活动任务摘要并要求用户选择。
3. **读取任务闭包**：以焦点任务为种子读取其正文、状态、来源和关系；沿 `分解为` 反向追溯到 `任务-开发总任务` 的完整父级链，读取直接子任务、直接依赖，以及反向依赖它的未完成直接依赖者。`分解为` 只表达任务父子，`依赖` 只表达跨分支前置条件；不把依赖当父级，不默认递归二阶依赖或加载完整任务树。
4. **读取架构闭包**：沿焦点任务的 `解决`、`涉及系统` 读取缺口、目标能力和系统；沿系统 `包含` 读取架构祖先和直接子系统；读取邻域系统的 `提供` 能力、`存在缺口`，以及明确的 `需要联调` 关系和关联任务入口。没有 `解决` 或 `涉及系统` 时报告“任务缺少架构定位”，不按名称或页面邻近关系猜测。
5. **读取直接支撑**：只读取焦点任务或其架构邻域直接关联的 `图谱/说明/项目/`、`图谱/说明/决策/` 和 `图谱/说明/联调/` 页面。节点 `source_refs` 指向的原始资料按需展开；完整原始资料、历史和无关 workspace 只在需要追溯时读取。

向 AI 呈现上下文时保持“工作空间边界 → 目标与健康状态 → 任务面包屑与当前任务 → 子任务/依赖/阻塞/后续影响 → 架构面包屑/能力/缺口/联调 → 项目/决策/联调支撑 → 原始资料与历史”的顺序。`图谱/总览.md`、`视图/开发任务.md`、`视图/架构地图.md` 和 `视图/开发路线.md` 只提供摘要、入口和导航，不是事实源；若生成视图与节点正文不一致，以正式节点和正文关系为准，并报告页面过期。

遇到任务树或架构关系不健康、未解析 Wiki 链接或上下文过大时，保留 warning 并继续读取可确认的局部内容：链接文本不能当作事实；上下文过大时保留完整面包屑、直接关系和链接，延迟二阶依赖、完整历史和无关节点。AI 不自动补父级、推断依赖、推断状态或写回缺失关系。

## 项目现场恢复规则

项目支撑记录存储规范化 Git remote；本机路径只存放在设备级状态文件。路径解析顺序为用户明确提供的路径、当前 cwd 或 `run_dir` 中匹配 remote 的仓库、用户级 `project_paths`、要求用户确认；不扫描所有代码仓库。pull 只在代码工作区干净且目标 commit 可用时切分支/恢复 HEAD，绝不强制覆盖未提交代码。

## 相关文档

- 命令流程：`action/config.md`、`action/list.md`、`action/pull.md`、`action/compile.md`、`action/push.md`
- 迁移流程：`action/migrate.md`
- Git 知识库仓库：`references/setup.md`、`references/git-repository.md`
- 会话状态契约：`references/session-state.md`
- Obsidian CLI：`references/obsidian-cli.md`
- workspace 布局：`references/workspace-layout.md`
- 分层视图：`references/layered-views.md`
- 项目现场：`references/project-state.md`
