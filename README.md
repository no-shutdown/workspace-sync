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
/workspace-sync migrate
/workspace-sync compile
/workspace-sync push
```

- `config`：配置个人开发知识库 Git 仓库。
- `pull`：同步仓库、选择/恢复 workspace，并打开接手入口。
- `list`：列出本地 workspace，选择后设置当前 workspace；不自动同步远端。
- `migrate`：将已有 workspace 的旧英文目录、类型和链接迁移为中文布局；执行前需要确认。
- `compile`：把当前 workspace 的原始资料或已确认会话结论编译成开发图谱。
- `push`：采集关联项目 Git 现场，提交当前 workspace 的知识库变更并推送远端。

每次涉及知识库事实的工作都必须先有当前 workspace。没有时会要求输入名称并新建；不自动猜测，也不跨 workspace 读取。

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
        ├── 视图/
        │   ├── 架构地图.md
        │   ├── 开发路线.md
        │   ├── 任务清单.md
        │   └── 系统联调.md
        ├── 说明/
        │   ├── 项目/
        │   ├── 决策/
        │   └── 联调/
        └── 候选/
```

原始资料是不可覆盖的自由格式输入；节点页面是正式图谱事实；候选页面等待用户确认；总览、索引和分层视图是可重建的生成页面；日志是追加式操作记录。

## 图谱模型

图谱不是严格任务树。正式节点类型只有四类：系统、能力、缺口、任务。项目和决策保存为支撑记录，不进入主图谱。节点文件名统一为 `类型-名字.md`，关系使用正文中的中文语义 Wiki 链接，例如：

```md
- 存在缺口：[[缺口-数据导入缺少幂等校验]]
- 涉及系统：[[系统-业务平台]]
- 解决：[[缺口-数据导入缺少幂等校验]]
- 依赖：[[任务-完成认证改造]]
```

系统使用“包含”形成架构层级；任务通过“分解为”形成任务层级；任务通过“解决”缺口或“涉及系统”定位到架构。正式任务状态为：待开始、进行中、已阻塞、已完成、已取消。

compile 生成四个互相聚焦的视图：`架构地图`查看系统层级和能力，`开发路线`查看系统 → 缺口 → 任务，`任务清单`查看任务状态和依赖，`系统联调`查看系统协作。`总览.md` 显示当前开发位置面包屑、关键缺口和下一步任务。

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

安装脚本只安装 skill 文件，不创建或复制个人开发知识库内容。
