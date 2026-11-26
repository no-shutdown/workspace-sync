# Simplify Graph Types Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 workspace-sync 的正式开发图谱从六类节点收敛为“系统、能力、缺口、任务”四类，同时保留项目/决策的可追溯性，并让总览直接显示当前架构位置和开发任务。

**Architecture:** 正式图谱只保存架构对象、能力目标、明确缺口和可执行任务；项目仓库与技术决策降级为 `图谱/说明/` 下的支撑记录。compile 使用 `系统 → 缺口 → 任务` 或 `任务 → 涉及系统` 计算当前定位，生成架构地图、开发路线、任务清单和系统联调四个互相聚焦的视图。

**Tech Stack:** Markdown、YAML frontmatter、Obsidian CLI 规范、Mermaid、Git、Shell 文档一致性检查。

## Global Constraints

- 正式节点类型固定为：`系统`、`能力`、`缺口`、`任务`。
- 正式节点路径固定为：`图谱/节点/<类型>/<类型>-<中文名称>.md`。
- 新生成节点的 frontmatter `type` 使用中文；稳定 `id`、来源、正文和历史不得因迁移丢失。
- 项目和决策是支撑记录，不进入架构地图、开发路线和任务清单的主 Mermaid 图。
- 任务通过 `解决` → `缺口` → `存在缺口` → `系统` 定位；没有缺口链路的任务使用 `涉及系统`。
- 能力与缺口不能仅凭名称合并；重复只生成候选，不自动删除、覆盖或合并。
- 不根据没有 `提供` 关系自动推断能力缺失；任务和缺口状态不能由代码提交或子任务完成静默改变。
- Obsidian CLI 仍是 Vault 内容接口；compile 只作用于当前 workspace。
- 本次修改只更新 skill 文档和 active install copy，不迁移用户实际 Vault 内容。
- 用户已明确要求完成后自动 commit & push；禁止 force push，远端冲突必须停止并报告。

---

## Baseline RED Evidence

在修改前使用三个独立压力场景测试了无新契约的基线行为：

- 类型场景产生了互相冲突的建议：一份保留五类，一份把缺口降成能力状态，一份建议三类；说明缺少硬性类型边界时，代理不会稳定保留“缺口”语义。
- 视图场景把“系统架构 → 能力 → 能力缺口 → 任务 → 代码项目”放进主链，把项目重新带回主图。
- 迁移场景建议保留英文机器 `type`，与中文 frontmatter 契约冲突。

GREEN 阶段必须用同一组压力场景读取修改后的 active `SKILL.md` 重跑，并验证所有结果都遵守四类正式节点、支撑记录隔离、中文 type 和当前定位规则。

## Implementation Tasks

### Task 1: 更新正式类型与核心术语契约

**Files:**
- Modify: `SKILL.md`
- Modify: `CONTEXT.md`
- Modify: `README.md`
- Modify: `templates/SCHEMA.md.example`

**Interfaces:**
- Produces the canonical four-type vocabulary, support-record layout, relation names, and current-position rules consumed by compile and view documentation.

- [ ] **Step 1: Replace the formal node vocabulary**

  将目录示例、正式类型列表、frontmatter `type` 示例和文件命名规则统一为 `系统`、`能力`、`缺口`、`任务`；把 `项目`、`决策`移动到 `图谱/说明/项目/` 和 `图谱/说明/决策/` 的支撑记录说明。

- [ ] **Step 2: Define the core relation contract**

  统一使用 `包含`、`提供`、`存在缺口`、`目标能力`、`解决`、`涉及系统`、`分解为`、`依赖`、`需要联调`；保留 `取代`、`派生自`、`参考决策` 为历史/支撑关系，并明确它们不参与主视图。

- [ ] **Step 3: Add architecture-position rules**

  写明任务优先通过 `解决 → 缺口 → 存在缺口 → 系统` 定位，无法走缺口链路时通过 `涉及系统` 定位；缺少定位时只生成 warning，不自动猜测。

- [ ] **Step 4: Verify the canonical docs**

  Run:

  ```bash
  rg -n '正式节点|type.*项目|type.*决策|能力缺口|图谱/节点/(项目|决策)' SKILL.md CONTEXT.md README.md templates/SCHEMA.md.example
  git diff --check
  ```

  Expected: only historical/compatibility wording remains where explicitly required; all current examples and formal lists use the four Chinese types.

### Task 2: 更新 compile、视图和迁移行为

**Files:**
- Modify: `action/compile.md`
- Modify: `references/layered-views.md`
- Modify: `action/pull.md`
- Modify: `action/push.md`
- Modify: `action/list.md`
- Modify: `references/project-state.md`
- Modify: `references/workspace-layout.md`
- Modify: `references/obsidian-cli.md`

**Interfaces:**
- Consumes Task 1's type and relation contract.
- Produces the compile and view rules for creating nodes, calculating current position, and rendering views.

- [ ] **Step 1: Update compile classification**

  规定 compile 只创建四类正式节点；项目和决策写为支撑记录；联调写为 `需要联调` 系统关系；任务使用 `涉及系统` 补齐架构定位；重复、未确认任务和不确定类型进入候选。

- [ ] **Step 2: Rename and narrow generated views**

  将生成视图统一为 `架构地图.md`、`开发路线.md`、`任务清单.md`、`系统联调.md`。架构地图只显示系统层级/能力和缺口摘要；开发路线显示 `系统 → 缺口 → 任务`；任务清单按系统/状态列任务；总览显示当前定位面包屑和下一步。

- [ ] **Step 3: Update migration mapping**

  将旧项目/决策节点移动到说明目录；将 `能力缺口` 改为 `缺口`；保留稳定 ID、aliases、来源、正文和历史；旧联调点只保留为待处理说明；未知类型不得猜测；迁移后重建视图并检查链接。

- [ ] **Step 4: Update project-state and layout references**

  将代码项目现场从“正式项目节点”改为支撑记录/项目清单，同时保留 remote、branch、HEAD、dirty 和本地 state 映射规则；所有用户可见路径使用中文。

- [ ] **Step 5: Verify behavior docs**

  Run:

  ```bash
  rg -n '架构地图|开发路线|任务清单|涉及系统|存在缺口|图谱/说明/项目|图谱/说明/决策' action references
  git diff --check
  ```

  Expected: compile and view docs agree on the same four types, support paths, relation names, and generated-page names.

### Task 3: Record the accepted architecture decision

**Files:**
- Create: `docs/adr/0083-simplify-graph-types-and-support-records.md`

**Interfaces:**
- Records the accepted decision for future maintainers and supersedes the type/layout assumptions in ADR 0082 without editing historical ADRs.

- [ ] **Step 1: Write the ADR**

  记录状态、背景、决策、四类正式节点、项目/决策支撑记录、关系和视图边界、迁移兼容与后果。

- [ ] **Step 2: Check ADR consistency**

  Run:

  ```bash
  git diff --check
  rg -n '系统|能力|缺口|任务|项目|决策|架构地图|开发路线|任务清单' docs/adr/0083-simplify-graph-types-and-support-records.md
  ```

  Expected: the ADR states one unambiguous vocabulary and does not claim that support records are formal graph nodes.

### Task 4: Sync active copy, run GREEN pressure tests, verify, commit, and push

**Files:**
- Modify via sync: `.agents/skills/workspace-sync/` (untracked active install copy; do not stage `.agents/` itself)
- Verify: all modified source documentation and the active `SKILL.md`

**Interfaces:**
- Consumes Tasks 1–3.
- Produces an active install copy that matches the source skill and a pushed Git commit containing only intended tracked files.

- [ ] **Step 1: Sync the source skill to the active install copy**

  Run:

  ```bash
  rsync -a --exclude='.git/' --exclude='.agents/' --exclude='.claude/' --exclude='config.json' ./ .agents/skills/workspace-sync/
  ```

- [ ] **Step 2: Run the same three pressure scenarios with the updated skill**

  Each scenario must read the active `SKILL.md` first and return a concrete design. Verify manually that each result:

  - lists exactly four formal node types;
  - treats project/decision as support records;
  - uses Chinese `type` and `类型-中文名称.md` names;
  - keeps `缺口` separate from `能力`;
  - keeps the main views free of project/decision nodes;
  - provides `系统 → 缺口 → 任务` or `任务 → 涉及系统` positioning.

- [ ] **Step 3: Run repository verification**

  Run:

  ```bash
  git diff --check
  bash -n install.sh uninstall.sh
  rg -n '正式类型|正式节点类型|type:' SKILL.md README.md CONTEXT.md templates/SCHEMA.md.example action references docs/adr/0083-simplify-graph-types-and-support-records.md
  cmp -s SKILL.md .agents/skills/workspace-sync/SKILL.md
  git status --short --branch
  ```

  Expected: exit code 0 for all checks; active `SKILL.md` is byte-identical to source; `.agents/` and `.claude/` remain unstaged.

- [ ] **Step 4: Commit only the tracked implementation files**

  Stage the explicit source paths, design/plan/ADR documents, and no `.agents/` or `.claude/` paths:

  ```bash
  git add SKILL.md README.md CONTEXT.md templates/SCHEMA.md.example action/compile.md action/list.md action/pull.md action/push.md references/layered-views.md references/obsidian-cli.md references/project-state.md references/workspace-layout.md docs/adr/0083-simplify-graph-types-and-support-records.md docs/superpowers/specs/2026-07-27-simplify-graph-types-design.md docs/superpowers/plans/2026-07-27-simplify-graph-types.md
  git diff --cached --check
  git commit -m "refactor: simplify graph node types"
  ```

- [ ] **Step 5: Push the commit**

  Run:

  ```bash
  git push origin main
  ```

  If the remote has advanced, stop and report the remote divergence; do not force-push.

## Plan Self-Review

- Spec coverage: Tasks 1–3 cover the four-type contract, support records, relations, views, current-position calculation, migration, warnings, and ADR; Task 4 covers active copy and verification.
- Placeholder scan: no unresolved placeholder markers or unspecified implementation steps are required; every task names files, edits, commands, and expected results.
- Type consistency: `缺口` is the only shortened formal label; `能力缺口` appears only as a legacy migration input. `项目` and `决策` are support records everywhere after migration.
- Scope: no code project or actual Vault migration is included; only the skill contract and active install copy change.
