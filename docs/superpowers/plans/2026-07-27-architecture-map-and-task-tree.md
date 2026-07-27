# Architecture Map and Rooted Task Tree Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 workspace-sync 的架构视图与开发任务视图彻底分离：架构地图保持图结构，开发任务以 `任务-开发总任务` 为唯一根生成任务树。

**Architecture:** 保留系统、能力、缺口、任务四类正式节点。系统的 `包含`/`提供`/`存在缺口`关系只投影到 `架构地图.md`；任务的 `分解为` 是唯一树层级，`依赖` 作为跨树枝前置关系投影到 `开发任务.md`。`开发路线.md` 收缩为缺口到任务的桥接索引，不产生第二套层级。

**Tech Stack:** Markdown、YAML frontmatter、Mermaid、Obsidian CLI 规范、Git、Shell 文档一致性检查。

## Global Constraints

- 正式节点类型仍固定为：`系统`、`能力`、`缺口`、`任务`。
- 每个 workspace 的正式任务树只能有一个带 `task_role: 根任务` 的根任务，文件名为 `任务-开发总任务.md`。
- `分解为` 只能连接任务到任务；每个非根任务必须恰好有一个父任务；`依赖` 不改变父子关系。
- 没有确认父级、多个根、循环或不可达任务只生成 warning/candidate，不自动挂接、合并或改变状态。
- `架构地图.md` 不绘制任务树结构边；`开发任务.md` 不绘制系统层级结构边。
- `开发路线.md` 只做系统/缺口到任务的交叉导航，不生成第二棵任务树或大型 Mermaid 图。
- 项目、决策仍是支撑记录；项目在任务树中最多作为纯文本支撑信息，不作为节点或树边。
- 原始资料、正式节点和稳定 ID 的保留规则不变；生成页面不得成为事实源。
- Obsidian CLI 仍是 Vault 内容接口；本次不迁移用户实际 Vault 内容。
- 修改 skill 文档前必须用同样压力场景完成 RED/GREEN 验证；禁止把 `.agents/`、`.claude/skills/` 或 active copy 纳入提交。
- 提交目标为 `main-devtree`；禁止 force push。远端冲突必须停止并报告。

---

## RED Baseline Evidence

在新契约写入前使用三个独立代理做了无指导压力测试：

- 一个代理引入了 `architecture`、`development-task`、root/epic 等新类型和 Canvas/Dataview 方案，说明没有现有四类型和 Markdown-only 边界时会扩大模型。
- 一个代理虽然提出唯一总体任务根和纯任务树，但仍保留“开发路线移除”等未绑定到当前现有页面的判断，说明视图迁移契约需要明确写入。
- 一个代理将架构依赖、任务依赖、任务改变系统、任务解决缺口拆成全新英文关系，说明必须明确复用当前中文关系词汇，而不是重新发明关系。

GREEN 阶段使用同类场景读取 active skill，检查四类正式类型、唯一根任务、纯任务树、架构图边界、桥接路线和迁移规则。

## Implementation Tasks

### Task 1: 更新根任务和关系契约

**Files:**
- Modify: `SKILL.md`
- Modify: `CONTEXT.md`
- Modify: `README.md`
- Modify: `templates/SCHEMA.md.example`
- Modify: `references/workspace-layout.md`

**Interfaces:**
- Consumes: approved design in `docs/superpowers/specs/2026-07-27-architecture-map-and-task-tree-design.md`.
- Produces: the canonical `task_role: 根任务`, `分解为`/`依赖` semantics and the `任务-开发总任务.md` path used by compile and views.

- [x] **Step 1: Add the single-root task contract**

  在正式任务规范、frontmatter 示例和术语中写明：根任务仍是 `type: 任务`，使用 `task_role: 根任务`；每个非根任务恰好一个 `分解为` 父级；依赖不能形成树层级；未定位任务不能自动挂接。

- [x] **Step 2: Separate architecture and task semantics**

  统一说明 `包含`/`提供`/`存在缺口`属于架构投影，`分解为`属于任务树，`解决`/`涉及系统`属于交叉定位，`依赖`属于跨树枝前置关系；不新增 `architecture`、`development-task` 等正式类型。

- [x] **Step 3: Update examples and layout**

  在中文布局中加入 `图谱/节点/任务/任务-开发总任务.md`，将任务示例改为根任务→子任务，并把 `任务清单.md` 的正式生成名称改为 `开发任务.md`。

- [x] **Step 4: Run canonical-contract checks**

  ```bash
  rg -n '任务-开发总任务|task_role|分解为|依赖|架构地图|开发任务|开发路线' SKILL.md CONTEXT.md README.md templates/SCHEMA.md.example references/workspace-layout.md
  git diff --check
  ```

  Expected: all current examples use Chinese four-type values, the root task is explicit, and no new formal node type is introduced.

### Task 2: Rebuild the generated views around graph + tree

**Files:**
- Modify: `action/compile.md`
- Modify: `references/layered-views.md`

**Interfaces:**
- Consumes: Task 1’s root and relation contract.
- Produces: compile behavior for root validation, `架构地图.md`, root-first `开发任务.md`, and bridge-only `开发路线.md`.

- [x] **Step 1: Define root and tree validation**

  规定 compile 检查唯一根、单父级、任务可达性、循环、非任务端点和依赖误用；异常只生成 warning/candidate，不猜测父级或改任务状态。

- [x] **Step 2: Define architecture-map projection**

  规定 `架构地图.md` 只显示系统层级、能力和缺口摘要；不绘制 `分解为`、`依赖` 或项目/决策节点。

- [x] **Step 3: Define root-first task-tree projection**

  将 `开发任务.md` 定义为从 `任务-开发总任务` 开始的 Markdown 嵌套树，任务项显示状态、架构定位、依赖、阻塞和下一步；依赖不得被画成树边。

- [x] **Step 4: Narrow the bridge view**

  将 `开发路线.md` 改成按系统/缺口列出解决任务的表格或小型列表，禁止它建立新的父子排序或大型 Mermaid 图。

- [x] **Step 5: Verify generated-view boundaries**

  ```bash
  rg -n '架构地图|开发任务|开发路线|任务-开发总任务|唯一根|单父级|依赖.*父|不.*第二' action/compile.md references/layered-views.md
  git diff --check
  ```

  Expected: graph/tree/bridge responsibilities are distinct and every view points back to formal node pages.

### Task 3: Update migration and command references

**Files:**
- Modify: `action/migrate.md`
- Modify: `action/list.md`
- Modify: `action/pull.md`
- Modify: `action/push.md`
- Modify: `references/obsidian-cli.md`

**Interfaces:**
- Consumes: Task 1 and Task 2 page names and root constraints.
- Produces: safe migration from old generated view names and command examples that open the new tree page.

- [x] **Step 1: Add view-name migration rules**

  将 `图谱/视图/任务清单.md` 映射到 `图谱/视图/开发任务.md`；若已有旧 `开发任务.md`，只作为预览/旧生成页面处理，迁移后由 compile 重建，不把旧列表当新事实。

- [x] **Step 2: Preserve task relationships during migration**

  保留任务 ID、aliases、来源、正文、状态和历史；保留 `分解为` 与 `依赖` 的语义，禁止把依赖转换成父子关系；缺少父级的任务报告 warning，不自动挂到根任务。

- [x] **Step 3: Update command and CLI examples**

  让 list/pull/Obsidian CLI 示例打开 `图谱/总览.md` 或 `图谱/视图/开发任务.md`，不再把 `任务清单.md` 作为当前入口；push 仍只记录项目支撑信息。

- [x] **Step 4: Verify migration references**

  ```bash
  rg -n '任务清单|开发任务|任务-开发总任务|分解为|依赖' action/migrate.md action/list.md action/pull.md action/push.md references/obsidian-cli.md
  git diff --check
  ```

  Expected: old names only appear as explicit migration inputs; new command examples use the tree view.

### Task 4: Record the architecture decision

**Files:**
- Create: `docs/adr/0084-architecture-map-and-rooted-task-tree.md`

**Interfaces:**
- Records: the accepted graph/tree split and supersedes only the view-boundary assumptions from ADR-0083.

- [x] **Step 1: Write the ADR**

  记录唯一根任务、架构图/任务树/桥接索引边界、关系语义、异常 warning、迁移兼容和取舍；明确不新增正式类型、不引入插件依赖。

- [x] **Step 2: Check ADR consistency**

  ```bash
  git diff --check
  rg -n '架构地图|开发任务|开发路线|开发总任务|唯一|分解为|依赖' docs/adr/0084-architecture-map-and-rooted-task-tree.md
  ```

  Expected: the ADR contains one unambiguous tree root and does not claim that dependencies create hierarchy.

### Task 5: Sync, pressure-test, verify, commit, and push

**Files:**
- Modify via sync: `.agents/skills/workspace-sync/` (untracked active copy; do not stage)
- Verify: all changed source docs and active copies

**Interfaces:**
- Consumes: Tasks 1–4.
- Produces: an active skill that teaches the graph/tree split and a pushed `main-devtree` branch containing only intended source files.

- [x] **Step 1: Sync the feature worktree source to active copy**

  ```bash
  rsync -a --exclude='.git' --exclude='.agents/' --exclude='.claude/' --exclude='config.json' ./ .agents/skills/workspace-sync/
  ```

- [x] **Step 2: Run GREEN pressure scenarios**

  Re-run the three RED scenarios after each active skill source is available. Each result must enforce: four formal types; one confirmed `任务-开发总任务` root; `分解为` as the only tree edge; `依赖` as a non-hierarchical cross-link; architecture graph excluding task-tree edges; `开发路线` as a bridge only; and old view names as migration inputs.

- [ ] **Step 3: Run repository verification**

  ```bash
  git diff --check
  bash -n install.sh uninstall.sh
  ! rg -n 'type: (项目|决策|能力缺口)' SKILL.md README.md CONTEXT.md templates/SCHEMA.md.example action references docs/adr/0084-architecture-map-and-rooted-task-tree.md
  ! rg -n '图谱/视图/任务清单\.md' SKILL.md README.md CONTEXT.md templates/SCHEMA.md.example action/compile.md references/layered-views.md references/obsidian-cli.md
  cmp -s SKILL.md .agents/skills/workspace-sync/SKILL.md
  git status --short --branch
  ```

  Expected: source and active skill match, current docs use `开发任务.md`, legacy task-list wording is limited to migration compatibility, and no active copy path is staged.

- [ ] **Step 4: Commit only intended feature files**

  ```bash
  git add SKILL.md README.md CONTEXT.md templates/SCHEMA.md.example action/compile.md action/list.md action/migrate.md action/pull.md action/push.md references/layered-views.md references/obsidian-cli.md references/workspace-layout.md docs/adr/0084-architecture-map-and-rooted-task-tree.md docs/superpowers/specs/2026-07-27-architecture-map-and-task-tree-design.md docs/superpowers/plans/2026-07-27-architecture-map-and-task-tree.md
  git diff --cached --check
  git commit -m "feat: add rooted development task tree"
  ```

- [ ] **Step 5: Push the feature branch**

  ```bash
  git push -u origin main-devtree
  ```

  If the remote branch has advanced or the push is rejected, stop and report; never force-push.

## Plan Self-Review

- Spec coverage: Tasks 1–4 cover the approved graph/tree split, root contract, view boundaries, migration, ADR, warnings and command references; Task 5 covers active skill verification and branch delivery.
- Placeholder scan: no unresolved placeholder markers or unspecified implementation steps are required; every step names files, exact rules and verification commands.
- Type consistency: the only formal node types remain `系统`、`能力`、`缺口`、`任务`; `task_role: 根任务` is metadata, not a fifth type.
- Relation consistency: `包含` is architectural, `分解为` is task hierarchy, `依赖` is task ordering, and `解决`/`涉及系统` are cross-domain references.
- Scope: no actual Vault migration and no code-project changes; only the skill contract and active copy change.
