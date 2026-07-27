# AI Local Context Assembly Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 AI 在架构地图与开发任务树分开后，仍能以当前任务为中心获得完整、有限且可追溯的开发上下文。

**Architecture:** 保留节点正文和语义 Wiki 链接作为唯一事实源，不增加 `AI上下文.md` 或新的正式类型。扩展新 AI 会话的默认加载契约：从总览和焦点任务出发，读取任务父级/子级与依赖闭包，再读取任务的架构邻域、联调关系和直接支撑记录；生成视图只提供入口与摘要。

**Tech Stack:** Markdown、YAML frontmatter、Obsidian CLI 读取/links/backlinks/search 约定、Git、Shell 文档一致性检查。

## Global Constraints

- 正式节点类型仍固定为：`系统`、`能力`、`缺口`、`任务`。
- 不生成新的 `AI上下文.md` 事实页面；AI 通过 Obsidian CLI 按规则读取现有节点和生成入口。
- `图谱/总览.md`、`开发任务.md`、`架构地图.md` 和 `开发路线.md` 都是导航/摘要投影，不是事实源。
- 当前焦点任务优先级固定为：用户明确指定 > 当前对话明确确认 > 总览标记的活动任务；没有可确认焦点时不猜测。
- `分解为` 只用于任务父子；`依赖` 只用于跨分支前置；`解决`/`涉及系统`/`包含`/`需要联调` 保持各自语义。
- 焦点上下文包含完整任务父级链、直接子任务、直接依赖和未完成直接依赖者；不默认递归二阶以上依赖或全量任务树。
- 架构上下文只沿明确关系读取：`解决` → 缺口/目标能力/系统、`涉及系统`、系统 `包含` 祖先与直接子系统、`提供`/`存在缺口`、`需要联调`。
- 无明确关系时只报告 warning，不按名称、项目、同级任务、最近修改时间或页面邻近关系猜测。
- 项目、决策和联调说明是支撑记录，不使用正式节点 `type`，只读取与焦点任务或架构邻域直接关联的记录。
- 原始资料、完整历史和无关 workspace 只按需展开；上下文过大时保留面包屑、直接关系和链接，延迟二阶内容。
- 所有修改在已存在的 `/Users/ocean/xl/yc-ukon/workspace-sync/.worktrees/main-devtree`、`main-devtree` 分支完成；不修改或合并 `main`，不 force push。
- `.agents/` active copy 只通过同步验证，永不加入提交；`config.json`、`.claude/` 和工作树元数据不纳入本次提交。

---

### Task 1: 更新 AI 上下文术语与用户说明

**Files:**
- Modify: `CONTEXT.md`（会话启动上下文、会话聚焦任务、局部上下文闭包）
- Modify: `README.md`（图谱拆分后的 AI 阅读方式）

**Interfaces:**
- Consumes: `docs/superpowers/specs/2026-07-27-ai-context-assembly-design.md`
- Produces: 与 `SKILL.md` 一致的术语和用户可读说明，不改变四类正式类型与视图边界。

- [ ] **Step 1: 定义局部上下文闭包**

  在 `CONTEXT.md` 的会话上下文术语附近新增“AI 局部上下文闭包”：说明它以焦点任务为种子，包含任务面包屑、直接子任务、直接依赖/未完成依赖者、架构邻域、联调关系和直接支撑记录；明确生成视图不是事实源。

- [ ] **Step 2: 收紧会话启动与焦点选择**

  将“新会话默认加载”和“会话聚焦任务”改为明确优先级：用户指定 > 当前确认 > 总览活动任务；焦点不存在、任务不明确或 workspace 未选择时只能报告并等待选择，不能按名称或最近修改时间猜测。

- [ ] **Step 3: 在 README 增加 AI 接手说明**

  在现有架构图/任务树说明后补充一句：人使用分层视图，AI 读取总览加焦点任务局部闭包；列出任务层级、依赖和架构定位仍然来自节点正文关系。

- [ ] **Step 4: 检查术语一致性**

  Run:

  ```bash
  rg -n '局部上下文|会话启动|会话聚焦|依赖|任务面包屑|架构面包屑' CONTEXT.md README.md
  git diff --check
  ```

  Expected: 两个文件都说明 AI 不读取全库、不猜测焦点，且没有把生成页面描述成事实源。

- [ ] **Step 5: Commit**

  ```bash
  git add CONTEXT.md README.md
  git diff --cached --check
  git commit -m "docs: define AI local context terminology"
  ```

### Task 2: 扩展 SKILL 的 AI 会话装配契约

**Files:**
- Modify: `SKILL.md:238-244`（新 AI 会话启动上下文与相关规则）

**Interfaces:**
- Consumes: Task 1 的术语和 approved spec。
- Produces: AI 可直接执行的上下文读取顺序、关系闭包、错误处理和规模控制规则。

- [ ] **Step 1: 写入固定入口与焦点优先级**

  在新 AI 会话规则中固定读取顺序：`SCHEMA.md`、`工作区.md`、`图谱/总览.md`，然后按“用户明确指定 > 当前确认 > 总览活动任务”选择焦点；没有焦点时只加载活动任务摘要，不猜测。

- [ ] **Step 2: 写入任务上下文闭包**

  明确读取当前任务、沿 `分解为` 到 `任务-开发总任务` 的完整父级链、直接子任务、直接依赖和未完成直接依赖者；禁止用 `依赖` 代替父级，禁止默认递归二阶依赖或整个任务树。

- [ ] **Step 3: 写入架构上下文闭包**

  明确沿 `解决`、`涉及系统`、`包含`、`提供`、`存在缺口`、`目标能力` 和 `需要联调` 读取架构邻域，并在缺关系时只生成“任务缺少架构定位” warning。

- [ ] **Step 4: 写入支撑记录、来源和错误规则**

  规定只读取焦点邻域直接关联的项目/决策/联调支撑记录；`source_refs` 指向的原始资料按需展开。补充 workspace 未选择、焦点不存在、未解析链接、图谱不健康和上下文过大时的安全行为。

- [ ] **Step 5: Commit**

  ```bash
  git add SKILL.md
  git diff --cached --check
  git commit -m "feat: define AI context assembly contract"
  ```

### Task 3: 同步生成入口、CLI 与分层视图说明

**Files:**
- Modify: `action/compile.md`（总览/分层视图输出与 AI 接手摘要）
- Modify: `action/pull.md`（pull 后接手上下文提示）
- Modify: `references/layered-views.md`（视图与 AI 局部闭包的关系）
- Modify: `references/obsidian-cli.md`（links/backlinks/source_refs 的读取意图）

**Interfaces:**
- Consumes: Task 2 的会话装配契约。
- Produces: compile/pull/CLI 文档与 SKILL 规则一致，且不会引入第二份 AI 事实页面。

- [ ] **Step 1: 更新 compile 的总览输出**

  规定 `图谱/总览.md` 保留目标、健康状态、两条面包屑、活动任务摘要和视图入口，并为焦点任务提供 `开发任务.md`、`架构地图.md`、`开发路线.md` 和节点页面链接；总览只作导航，不能存独立任务状态。

- [ ] **Step 2: 更新 pull 的接手提示**

  规定 pull 后先打开总览，再按用户焦点读取任务局部闭包；没有焦点时呈现活动任务选择，不自动进入最近修改任务。

- [ ] **Step 3: 更新分层视图说明**

  在 `references/layered-views.md` 增加“AI 局部上下文”章节，明确任务树与架构图分别是人类入口，AI 通过节点正文关系跨视图组装上下文；禁止把桥接表或 Mermaid 标签当作事实。

- [ ] **Step 4: 更新 CLI 读取意图**

  在 `references/obsidian-cli.md` 补充 `backlinks` 用于追溯任务父级/直接依赖者，`links` 用于读取任务和架构出边，`search/files` 只在当前 workspace 范围内查找来源和支撑记录；未解析链接不能被当作事实。

- [ ] **Step 5: Commit**

  ```bash
  git add action/compile.md action/pull.md references/layered-views.md references/obsidian-cli.md
  git diff --cached --check
  git commit -m "docs: connect AI context to generated views"
  ```

### Task 4: 记录决策并更新 active copy

**Files:**
- Create: `docs/adr/0085-ai-local-context-assembly.md`
- Modify via sync: `.agents/skills/workspace-sync/`（只读验证，不提交）

**Interfaces:**
- Consumes: Tasks 1–3。
- Produces: ADR 记录“视图分开、AI 局部闭包接手”的长期决策；active copy 与源文档一致。

- [ ] **Step 1: 写 ADR**

  记录背景、唯一事实源、焦点选择优先级、任务/架构/支撑闭包、错误与规模控制、为什么不生成 `AI上下文.md`，以及对 AI 与人的取舍。

- [ ] **Step 2: 同步 active copy**

  Run:

  ```bash
  rsync -a --exclude='.git' --exclude='.agents/' --exclude='.claude/' --exclude='config.json' ./ .agents/skills/workspace-sync/
  ```

- [ ] **Step 3: 校验 active/source parity**

  Run:

  ```bash
  for f in SKILL.md CONTEXT.md README.md action/compile.md action/pull.md references/layered-views.md references/obsidian-cli.md docs/adr/0085-ai-local-context-assembly.md; do
    diff -q "$f" ".agents/skills/workspace-sync/$f" || exit 1
  done
  test ! -e .agents/skills/workspace-sync/.git
  ```

  Expected: all listed source docs match active copy and active copy contains no nested Git metadata.

- [ ] **Step 4: Commit**

  ```bash
  git add docs/adr/0085-ai-local-context-assembly.md docs/superpowers/specs/2026-07-27-ai-context-assembly-design.md
  git diff --cached --check
  git commit -m "docs: record AI context assembly decision"
  ```

### Task 5: 压力测试、验证、提交与推送

**Files:**
- Verify: `SKILL.md`, `CONTEXT.md`, `README.md`, `action/compile.md`, `action/pull.md`, `references/layered-views.md`, `references/obsidian-cli.md`, `docs/adr/0085-ai-local-context-assembly.md`
- Verify only: `.agents/skills/workspace-sync/`

**Interfaces:**
- Consumes: Tasks 1–4。
- Produces: pushed `main-devtree` with an AI-readable local context contract and no active-copy artifacts in Git。

- [ ] **Step 1: Run RED/GREEN pressure scenarios**

  Dispatch three read-only agents after syncing active copy. Test:

  1. Focus task A has root path, child B, dependency D, solves gap G, involves system S, and S contains S2; expected context includes both breadcrumbs and direct relations without treating dependency as hierarchy.
  2. No focus task is provided; expected behavior is to load total/workspace boundary and activity summaries, then ask for selection rather than choose by name or recency.
  3. Missing parent, unresolved link, missing architecture relation, or oversized neighborhood; expected warning, deferred links, and no auto-repair/full graph load.

  Each agent must read `.agents/skills/workspace-sync/SKILL.md` first, must not edit files, and must report whether the six formal relation meanings remain distinct.

- [ ] **Step 2: Run repository verification**

  ```bash
  git diff --check
  bash -n install.sh uninstall.sh
  ! rg -n '^type: (项目|决策|能力缺口|联调点)$' SKILL.md CONTEXT.md README.md action references docs/adr/0085-ai-local-context-assembly.md
  ! rg -n '图谱/(视图/)?AI上下文\.md' SKILL.md CONTEXT.md README.md action references docs/adr/0085-ai-local-context-assembly.md
  for f in SKILL.md CONTEXT.md README.md action/compile.md action/pull.md references/layered-views.md references/obsidian-cli.md docs/adr/0085-ai-local-context-assembly.md; do
    diff -q "$f" ".agents/skills/workspace-sync/$f" || exit 1
  done
  test ! -e .agents/skills/workspace-sync/.git
  ! git diff --cached --name-only | rg '^\.agents/|^\.claude/'
  ```

- [ ] **Step 3: Commit intended source files only**

  ```bash
  git add CONTEXT.md README.md SKILL.md action/compile.md action/pull.md references/layered-views.md references/obsidian-cli.md docs/adr/0085-ai-local-context-assembly.md docs/superpowers/specs/2026-07-27-ai-context-assembly-design.md docs/superpowers/plans/2026-07-27-ai-context-assembly.md
  git diff --cached --check
  git status --short
  git commit -m "feat: improve AI task context assembly"
  ```

- [ ] **Step 4: Push and verify remote**

  ```bash
  git push -u origin main-devtree
  local_sha="$(git rev-parse HEAD)"
  remote_sha="$(git ls-remote origin refs/heads/main-devtree | awk '{print $1}')"
  test "$local_sha" = "$remote_sha"
  git status --short --branch
  ```

  Expected: remote SHA equals local SHA, tracked worktree is clean, and only the intentionally untracked `.agents/` active copy remains.

## Plan Self-Review

- Spec coverage: Tasks 1–3 cover entry/focus selection, task closure, architecture closure, support/source expansion, error/scale behavior and view/CLI handoff; Task 4 records the decision; Task 5 covers all pressure scenarios and verification.
- Placeholder scan: no unresolved placeholder markers or vague implementation steps are required; every task names exact files and commands.
- Contract consistency: all references use the existing four types and Chinese relation vocabulary; no task dependency is promoted to hierarchy.
- Scope: no Vault migration, code-project change, new plugin dependency, new formal node type, formal relation or AI facts page.
- Delivery: all source work stays on `main-devtree`; `main` and active-copy artifacts are excluded.
