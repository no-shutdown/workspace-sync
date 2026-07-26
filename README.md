# workspace-sync

`workspace-sync` 是一个个人开发知识库 skill：把开发迭代、任务、系统能力、能力缺口、联调点、技术决策和代码项目现场组织成可被人和 AI 共同使用的 Obsidian Markdown 图谱。

知识库由用户配置的一个 Git 仓库承载。仓库本身就是 Obsidian Vault；其中每个顶层文件夹都是一个独立 workspace，也就是一个开发迭代。一个 workspace 可以同时关联多个代码项目，不与任何单一项目一一绑定。

## 核心体验

规划阶段可以使用 superpowers、grill-with-docs 或其他方式产生自由格式 raw Markdown。规划结束后，在 AI 对话中执行一行：

```text
/workspace-sync compile
```

如果已有 raw，compile 会将其增量整理成 Wiki 节点和开发图谱；如果没有 raw，但当前会话已经明确确认了开发任务，compile 会先生成 raw，再继续编译。原始资料保留，Wiki 由 LLM 持续维护，`overview.md` 和 `index.md` 自动生成。

## 命令

```text
/workspace-sync config
/workspace-sync pull [workspace-name]
/workspace-sync list
/workspace-sync compile
/workspace-sync push
```

- `config`：配置个人开发知识库 Git 仓库。
- `pull`：同步仓库、选择/恢复 workspace，并打开接手入口。
- `list`：列出本地 workspace，选择后设置当前 workspace；不自动同步远端。
- `compile`：把当前 workspace 的 raw 或已确认会话结论编译成开发图谱。
- `push`：采集关联项目 Git 现场，提交当前 workspace 的知识库变更并推送远端。

每次涉及知识库事实的工作都必须先有当前 workspace。没有时会要求输入名称并新建；不自动猜测，也不跨 workspace 读取。

## 仓库结构

```text
knowledge-base/
├── SCHEMA.md
└── <workspace-name>/
    ├── workspace.md
    ├── raw/
    │   └── *.md
    └── wiki/
        ├── overview.md
        ├── index.md
        ├── log.md
        ├── nodes/
        │   ├── projects/
        │   ├── systems/
        │   ├── capabilities/
        │   ├── gaps/
        │   ├── integrations/
        │   ├── tasks/
        │   └── decisions/
        └── candidates/
```

raw 是不可覆盖的自由格式输入；节点页面是正式图谱事实；候选页面等待用户确认；`overview.md`、`index.md` 是可重建的生成视图；`log.md` 是追加式操作记录。

## 图谱模型

图谱不是严格任务树。节点类型包括：

- 项目、系统、能力
- 能力缺口、联调点
- 任务、技术决策

关系使用正文中的语义 Wiki 链接，例如：

```md
- 缺少：[[gap-user-import]]
- 需要联调：[[integration-order-api]]
- 依赖：[[task-auth-refactor]]
```

任务可以通过“分解为”形成树形视图，但依赖、项目关联和系统协作关系可以跨越树层级。正式任务状态为：待开始、进行中、已阻塞、已完成、已取消。

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
