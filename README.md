# workspace-sync

`workspace-sync` 是一个个人开发知识库 skill：把开发迭代、系统、能力、缺口和开发任务组织成可被人和 AI 共同使用的 Obsidian Markdown 图谱。代码项目和技术决策作为支撑记录，系统联调使用关系表达。

知识库由用户配置的一个 Git 仓库承载。仓库本身就是 Obsidian Vault；其中每个顶层文件夹都是一个独立 workspace，也就是一个开发迭代，新建时使用中文工作区名称。一个 workspace 可以同时关联多个代码项目，不与任何单一项目一一绑定。

## 核心体验

规划阶段可以使用 superpowers、grill-with-docs 或其他方式产生自由格式原始资料。规划结束后，在 AI 对话中执行一行：

```text
/workspace-sync compile
```

如果已有原始资料，compile 会将其增量整理成中文节点和分层开发图谱；如果没有原始资料，但当前会话已经明确确认了开发任务，compile 会先生成原始资料，再继续编译。原始资料保留，图谱由 LLM 持续维护，`图谱/总览.md`、`图谱/索引.md` 和 `图谱/视图/` 自动生成。

## 命令

```text
/workspace-sync config
/workspace-sync pull [工作区名称]
/workspace-sync list
/workspace-sync migrate [工作区名称]
/workspace-sync compile [工作区名称]
/workspace-sync push [工作区名称]
```

- `config`：配置个人开发知识库 Git 仓库。
- `pull`：同步仓库；选择/恢复当前会话 workspace，并打开接手入口；没有有效当前会话 workspace 时负责引导选择或新建。
- `list`：列出本地 workspace，选择后写入当前会话缓存；没有有效当前会话 workspace 时负责引导选择或新建；不自动同步远端。
- `migrate`：将已有 workspace 的旧英文目录、类型和链接迁移为中文布局；执行前需要确认。
- `compile`：把当前会话 workspace 的原始资料或已确认会话结论编译成开发图谱；也可显式传 workspace 名称做单次覆盖。
- `push`：采集关联项目 Git 现场，提交当前 workspace 的知识库变更并推送远端；也可显式传 workspace 名称做单次覆盖。

每次涉及知识库事实的工作都必须先有当前会话 workspace。`list`/`pull` 负责在没有有效当前会话 workspace 时引导选择或新建；`compile`/`push`/`migrate` 不自行进入选择或创建流程，没有有效当前会话缓存时必须显式传 workspace，否则停止。不自动猜测，也不跨 workspace 读取。多个会话可以在同一目录下通过各自的 `session_id` 使用不同 workspace；workspace-sync 会把选择写到 `<run_dir>/.workspace-sync-cache/sessions/<session-id>.json`，不会回退到用户级全局指针。

## 仓库结构

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

原始资料是不可覆盖的自由格式输入；节点页面是正式图谱事实；候选页面等待用户确认；总览、索引和分层视图是可重建的生成页面；日志是追加式操作记录。

## 图谱模型

正式图谱整体不是单一任务树；其中的任务子图以开发总任务为根形成严格任务树。正式节点类型只有四类：系统、能力、缺口、任务。项目和决策保存为支撑记录，不进入主图谱。节点文件名统一为 `类型-名字.md`，关系使用正文中的中文语义 Wiki 链接，例如：

```md
- 存在缺口：[[缺口-数据导入缺少幂等校验]]
- 涉及系统：[[系统-业务平台]]
- 解决：[[缺口-数据导入缺少幂等校验]]
- 依赖：[[任务-完成认证改造]]
```

系统使用“包含”形成架构层级；任务从唯一的 `任务-开发总任务` 根节点通过“分解为”形成任务树；任务通过“解决”缺口或“涉及系统”定位到架构，跨分支前置条件使用“依赖”。正式任务状态为：待开始、进行中、已阻塞、已完成、已取消。

compile 生成四个互相聚焦的视图：`架构地图`查看系统层级、能力和缺口，`开发任务`从开发总任务展开任务树，`开发路线`把系统/缺口桥接到解决任务，`系统联调`查看系统协作。`总览.md` 同时显示架构面包屑、任务面包屑、关键缺口和下一步任务。

人通过架构地图、开发任务和开发路线阅读不同投影；AI 不只读取其中一页，而是从总览和焦点任务装配局部上下文闭包。上下文中的任务层级、依赖、架构定位和联调关系都回到正式节点正文验证，生成页面只作为导航入口。

## Git 与代码项目边界

知识库 Git 仓库只保存 Markdown、Schema 和审计记录，不保存代码副本。workspace 会记录关联项目的规范化 remote、分支、HEAD 和 dirty 状态，帮助换设备后恢复代码现场。

- dirty 代码项目不会阻止知识库保存，但不会复制未提交内容。
- push 只提交当前 workspace；其他 workspace 和根 `SCHEMA.md` 的变更会被提示。
- pull 不强制覆盖 dirty 代码项目。
- Git 冲突停止处理，禁止 force push。

## Obsidian CLI

Vault 内 Markdown 的读取、创建、修改、搜索、链接查询和打开统一通过官方 Obsidian CLI；workspace-sync 不维护第二套图数据库或 Vault API。Git 只负责 clone、fetch、rebase、commit 和 push。

详细运行契约见 [`SKILL.md`](./SKILL.md)，命令流程见 [`action/`](./action/)，仓库和 CLI 约定见 [`references/`](./references/)。

## 安装

```bash
git clone https://github.com/<your-username>/workspace-sync
cd workspace-sync
./install.sh
```

安装后配置：

```text
/workspace-sync config
```

然后选择或创建当前 workspace：

```text
/workspace-sync pull
```

之后的 `list`/`pull` 选择只绑定当前会话；如果运行环境无法提供稳定 `session_id` 或 `run_dir`，显式 workspace 只对本次命令生效，后续命令仍需再次指定。`project_paths` 仍保留在设备级状态文件中，用于代码仓库路径恢复。

`.workspace-sync-cache/` 是否加入 `.gitignore` 或 `.git/info/exclude` 由用户自行决定；workspace-sync 不自动修改任何 Git ignore 文件。

安装脚本只安装 skill 文件，不创建或复制个人开发知识库内容。
