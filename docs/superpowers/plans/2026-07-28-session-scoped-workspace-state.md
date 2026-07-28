# Session-Scoped Workspace State Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 workspace-sync 的当前 workspace 和会话焦点从用户级共享状态改为当前运行目录下按 session ID 隔离的会话缓存，保证并行会话不会互相覆盖。

**Architecture:** 知识库 Git 仓库继续保存共享 workspace 事实；用户/设备级配置继续保存知识库连接和 `project_paths`；会话选择写入 `<run_dir>/.workspace-sync-cache/sessions/<session-id>.json`。所有依赖知识库事实的命令先解析并校验当前会话缓存，缺失或无效时停止，不读取旧的全局 workspace 指针。

**Tech Stack:** Markdown Skill 契约、Obsidian CLI、Git；无新增运行时依赖或独立业务代码。

## Global Constraints

- 会话缓存固定放在当前运行目录的 `.workspace-sync-cache/sessions/<session-id>.json`。
- `session_id` 和会话启动时的 `run_dir` 必须由运行环境提供；不能根据 workspace 名称、项目名称或时间戳推断。
- 用户级 `local-state.json` 中的 `current_workspace_id`、`current_workspace_name` 不再生效；`project_paths` 继续保留。
- 无 session ID 时，显式 workspace 只允许完成单次操作，不创建共享缓存，也不回退到用户级指针。
- 缓存只保存会话边界和焦点，不保存图谱、原始资料、代码或其他 workspace 事实。
- 不修改用户项目的 `.gitignore` 或 `.git/info/exclude`；用户自行忽略 `.workspace-sync-cache`。
- workspace 身份始终以知识库中 `工作区.md` 的稳定 `workspace_id` 为准；缓存中的名称只是显示值。
- 项目路径解析顺序为：用户明确路径 → 当前会话 `run_dir`/cwd 中的匹配仓库 → 用户级 `project_paths` → 要求确认。
- 项目没有自动化测试框架；每个任务使用 `git diff --check`、文档契约扫描、shell 语法检查和并发场景审查验证。

## File Map

### 会话状态契约

- Create: `references/session-state.md` — 定义 session ID、run dir、缓存路径/schema、解析顺序、错误行为、旧状态兼容和并发边界。
- Create: `docs/adr/0086-session-scoped-workspace-state.md` — 记录采用会话级缓存、共享配置边界和对 ADR-0045/0062 的补充/取代关系。

### 核心 Skill 和命令

- Modify: `SKILL.md` — 更新不可违反规则、命令接口、本地状态模型、pull/list/compile/push 流程和会话启动契约。
- Modify: `action/config.md` — 明确 config 不设置 workspace，只保存知识库与设备级配置。
- Modify: `action/list.md` — 选择结果写入当前会话缓存，不写用户级 current workspace。
- Modify: `action/pull.md` — 同步后将选择绑定到当前会话，加入显式 workspace、session 缓存和项目路径优先级。
- Modify: `action/compile.md` — 支持可选 workspace 覆盖，默认读取当前会话缓存，缺失时安全停止。
- Modify: `action/push.md` — 支持可选 workspace 覆盖，默认读取当前会话缓存，保持提交范围和远端安全规则。
- Modify: `action/migrate.md` — 迁移操作使用当前会话 workspace，支持显式覆盖，不从全局指针猜测。

### 参考文档和用户入口

- Modify: `references/setup.md` — 收窄 `state_file` 语义为设备级配置，并说明 session 缓存不写入知识库。
- Modify: `references/git-repository.md` — 更新本地状态边界，区分设备配置和会话选择。
- Modify: `references/project-state.md` — 更新项目路径解析顺序，避免并行 worktree 使用错误的共享映射。
- Modify: `references/obsidian-cli.md` — 说明 Obsidian CLI 的查询范围由当前会话 workspace 决定。
- Modify: `README.md` — 更新命令说明和并行会话使用方式。
- Modify: `CONTEXT.md` — 更新“当前工作空间”“本地指针”“会话启动上下文”和“知识库配置”等术语。
- No change: `templates/config.json.example` — 结构仍然只包含 repository、obsidian 和 `state_file`；通过相关说明文件解释 `state_file` 不再保存 current workspace。
- No change: 历史 ADR（包括 `0045`、`0062`）— ADR 采用追加式记录，不改写历史；新 ADR 说明新决策覆盖旧实现语义。

### 本地活动副本

- After source changes are merged: 将主仓库源文件同步到本机未跟踪的 `.agents/skills/workspace-sync/` 活动副本，排除 `.git/`、`.agents/`、`.claude/`、`config.json` 和 `.superpowers/`；不将活动副本加入 Git 提交。

## Implementation Tasks

### Task 1: 建立会话状态契约和架构决策

**Files:**
- Create: `references/session-state.md`
- Create: `docs/adr/0086-session-scoped-workspace-state.md`
- Modify: `SKILL.md`

**Interfaces:**
- Consumes: 已确认设计文档 `docs/superpowers/specs/2026-07-28-session-scoped-workspace-state-design.md`。
- Produces: 后续命令文档统一引用的 session state contract；明确字段 `version`、`session_id`、`workspace_id`、`workspace_name`、`focus_task_id`。

- [ ] **Step 1: 写入会话状态参考文档**

  在 `references/session-state.md` 中写明以下固定契约：

  ```text
  session_id + run_dir 由运行环境提供
  cache = <run_dir>/.workspace-sync-cache/sessions/<session-id>.json
  ```

  文档必须包含：

  - 缓存 JSON 示例和 `workspace_id` 优先规则；
  - 会话启动确定 `run_dir`，后续命令不随 Vault 路径迁移缓存；
  - session ID 路径安全校验和原子写入要求；
  - 缓存缺失、损坏、workspace 不存在、ID 不匹配、没有 session ID/run dir 时的安全行为；
  - 旧 `local-state.json` 只保留 `project_paths`，忽略 `current_workspace_*`；
  - 项目路径解析优先级；
  - 两个会话可以选择同一个 workspace，但不能共享会话文件。

- [ ] **Step 2: 写入 ADR-0086**

  新 ADR 记录：共享知识库事实与用户/设备配置不变；当前 workspace 和 focus task 改为当前运行目录下的 session 文件；没有 session ID 时不使用全局回退；用户自行处理 Git ignore。明确它补充并取代 ADR-0045 中“本机指针”的共享文件实现语义，同时不删除历史 ADR。

- [ ] **Step 3: 更新 `SKILL.md` 的总契约**

  修改这些位置：

  - 不可违反规则：将“先选 workspace”改为“先建立当前会话 workspace 边界”，明确不读全局 current workspace；
  - 命令表：给 `compile`、`push`、`migrate` 增加可选 workspace 覆盖说明；
  - 本地配置：`state_file` 只保存设备级配置和 `project_paths`，加入会话缓存路径链接；
  - 本地状态示例：移除用户级 `current_workspace_id/name`，添加 session cache 示例；
  - `pull`、`list`、`compile`、`push` 和新会话启动流程：统一先解析 session cache、按稳定 ID 校验 workspace，缺失时安全停止；
  - 项目现场恢复规则：改用“明确路径 → 当前 cwd/run_dir → project_paths → 要求确认”的路径顺序。

- [ ] **Step 4: 运行契约自检**

  Run:

  ```bash
  git diff --check
  bash -n install.sh uninstall.sh
  rg -n "\.workspace-sync-cache/sessions|session_id|current_workspace_id|project_paths" \
    SKILL.md references/session-state.md docs/adr/0086-session-scoped-workspace-state.md
  ```

  Expected: diff 无空白错误；shell 语法退出码为 0；输出包含 session cache、session ID 和设备级 project paths 契约。

- [ ] **Step 5: Commit**

  ```bash
  git add SKILL.md references/session-state.md docs/adr/0086-session-scoped-workspace-state.md
  git commit -m "docs: define session-scoped workspace state"
  ```

### Task 2: 更新 config/list/pull 的选择和绑定流程

**Files:**
- Modify: `action/config.md`
- Modify: `action/list.md`
- Modify: `action/pull.md`

**Interfaces:**
- Consumes: Task 1 的 session state contract。
- Produces: 选择 workspace 的命令把稳定 ID 写入当前会话缓存；config 不写 workspace。

- [ ] **Step 1: 修正 config 行为**

  在 `action/config.md` 的“写入与收尾”中：

  - 保留 repository、obsidian、state_file 配置；
  - 明确不写 `current_workspace_id/name`；
  - 明确 state_file 中的 project paths 是用户/设备级；
  - 提示用户通过 `pull` 或 `list` 在当前会话中建立 workspace。

- [ ] **Step 2: 修正 list 行为**

  在 `action/list.md` 中：

  - 把“设置本地当前 workspace 指针”改为“写入当前会话缓存”；
  - 用户选择后写入 `workspace_id`、显示名称和保留的 focus task；
  - 无 session ID 时允许显式选择用于单次操作，但不创建共享缓存并报告不可持久化；
  - 保留“只读本地 Vault、不自动 pull、不自动猜测”的边界。

- [ ] **Step 3: 修正 pull 行为**

  在 `action/pull.md` 中：

  - 继续先安全同步知识库，再选择 workspace；
  - 选择结果写入当前会话缓存，不写用户级 current pointer；
  - 明确指定名称时可直接绑定，未指定时必须让用户选择；
  - 代码现场恢复路径改为：用户明确路径 → 当前 run_dir/cwd → project_paths → 要求确认；
  - 缓存写入失败时报告“知识库已同步但会话 workspace 未持久化”，不创建全局替代状态。

- [ ] **Step 4: 验证选择命令文档**

  Run:

  ```bash
  git diff --check
  rg -n "本地状态文件|current_workspace_id|current_workspace_name|会话缓存|\.workspace-sync-cache" \
    action/config.md action/list.md action/pull.md
  ```

  Expected: `config` 只把 current 字段作为“不再写入/忽略”说明；`list/pull` 明确写会话缓存；不出现把 current workspace 写入共享 state 的正向指令。

- [ ] **Step 5: Commit**

  ```bash
  git add action/config.md action/list.md action/pull.md
  git commit -m "docs: bind workspace selection to sessions"
  ```

### Task 3: 更新 compile/push/migrate 的消费边界

**Files:**
- Modify: `action/compile.md`
- Modify: `action/push.md`
- Modify: `action/migrate.md`

**Interfaces:**
- Consumes: Task 1 的 session state contract 和 Task 2 的选择绑定流程。
- Produces: 所有依赖 workspace 的操作都从当前会话解析 workspace，且支持显式一次性覆盖。

- [ ] **Step 1: 更新 compile 命令接口**

  将命令改为 `/workspace-sync compile [工作区名称]`，并在步骤 1 明确：先读取当前会话缓存；参数存在时校验并作为覆盖；两者都没有时停止并要求选择；不读取旧 global current pointer。保留所有既有图谱编译、状态确认、视图生成和提交范围规则。

- [ ] **Step 2: 更新 push 命令接口**

  将命令改为 `/workspace-sync push [工作区名称]`，把“读取本地当前 workspace 指针”改为“解析当前会话缓存或显式 workspace”。显式路径和当前 cwd 优先于用户级 project_paths；其他 workspace 和根目录提交范围规则不变。

- [ ] **Step 3: 更新 migrate 命令接口**

  将命令改为 `/workspace-sync migrate [工作区名称]`，迁移预览和确认都必须绑定当前会话 workspace 或显式参数；不能从用户级 current pointer 猜测。保留迁移只作用于一个 workspace、必须确认、不自动 push 的规则。

- [ ] **Step 4: 验证消费命令文档**

  Run:

  ```bash
  git diff --check
  rg -n "当前 workspace 指针|读取本地当前|current_workspace|\.workspace-sync-cache|显式" \
    action/compile.md action/push.md action/migrate.md
  ```

  Expected: 三个命令都写明会话缓存/显式参数；没有把用户级 current pointer 作为默认来源的正向流程。

- [ ] **Step 5: Commit**

  ```bash
  git add action/compile.md action/push.md action/migrate.md
  git commit -m "docs: require session workspace for operations"
  ```

### Task 4: 同步参考文档、README 和术语

**Files:**
- Modify: `references/setup.md`
- Modify: `references/git-repository.md`
- Modify: `references/project-state.md`
- Modify: `references/obsidian-cli.md`
- Modify: `README.md`
- Modify: `CONTEXT.md`

**Interfaces:**
- Consumes: Task 1-3 的最终术语和命令契约。
- Produces: 用户入口、项目路径说明和 AI 上下文术语与 session-scoped 行为一致。

- [ ] **Step 1: 更新 setup/git-repository 的状态分层**

  `references/setup.md` 和 `references/git-repository.md` 必须区分：

  - config/state_file 保存知识库连接和设备级 project paths；
  - session cache 保存 current workspace/focus task；
  - session cache 不进入知识库 Git、不写入 Obsidian；
  - config 不选择 workspace。

- [ ] **Step 2: 更新 project-state 的路径恢复顺序**

  将 remote→path 映射的优先级改为：明确路径、当前 run_dir/cwd、用户级 project_paths、要求确认；说明当前会话不会覆盖共享映射，支持并行 worktree。

- [ ] **Step 3: 更新 obsidian-cli 的读取边界**

  明确 Obsidian CLI 查询必须先通过当前会话 workspace 建立目录边界；没有 session workspace 时停止读取知识库事实；所有 links/backlinks/files/search 规则继续只作用于该 workspace。

- [ ] **Step 4: 更新 README 使用说明**

  在命令表和安装后的工作流中说明：`list/pull` 的选择属于当前会话；`compile/push/migrate` 可显式传 workspace；多个会话可以在同一目录使用不同 workspace；用户需自行忽略 `.workspace-sync-cache`。

- [ ] **Step 5: 更新 CONTEXT 术语**

  修改“知识库 Git 配置”“当前工作空间”“本地当前工作空间指针”“会话启动上下文”“工作空间列表”和“知识库同步操作”的定义：

  - 当前 workspace 是会话边界，不是用户级全局指针；
  - 新增“会话 workspace 状态缓存”术语，说明路径、字段和安全行为；
  - `project_paths` 仍是设备级默认映射；
  - 会话焦点和 workspace 选择不会写入共享知识库。

- [ ] **Step 6: 运行全局文档扫描**

  Run:

  ```bash
  git diff --check
  rg -n "current_workspace_id|current_workspace_name|当前 workspace 指针写入本地状态|设置本地当前 workspace" \
    SKILL.md action references README.md CONTEXT.md templates
  rg -n "\.workspace-sync-cache/sessions|session_id|project_paths" \
    SKILL.md references README.md CONTEXT.md
  ```

  Expected: 第一条没有把用户级 state 作为正向写入来源的旧语句；第二条覆盖核心契约、路径和设备级映射说明。历史 ADR 不纳入旧语句扫描，因为它们是不可改写的决策记录。

- [ ] **Step 7: Commit**

  ```bash
  git add references/setup.md references/git-repository.md references/project-state.md \
    references/obsidian-cli.md README.md CONTEXT.md
  git commit -m "docs: align workspace references with session state"
  ```

### Task 5: 完成验证、活动副本同步和交付检查

**Files:**
- Verify: all modified Markdown files from Tasks 1-4
- Sync after merge: `.agents/skills/workspace-sync/` (untracked active copy only)

**Interfaces:**
- Consumes: Tasks 1-4 的文档契约和分支提交。
- Produces: 可审查的 source/active-copy 一致状态，以及证明并行会话隔离的验证记录。

- [ ] **Step 1: 验证 Git 和 shell 完整性**

  Run:

  ```bash
  bash -n install.sh uninstall.sh
  git diff --check origin/main..HEAD
  git status --short --branch
  ```

  Expected: shell 语法退出码为 0；diff 无空白错误；分支只包含本次 session state 文档变更，未跟踪活动副本不被加入提交。

- [ ] **Step 2: 模拟两个会话的缓存隔离**

  在 `/private/tmp` 下创建临时运行目录，不修改知识库：

  ```text
  temp-run/.workspace-sync-cache/sessions/session-A.json
    workspace_id = ws-A
  temp-run/.workspace-sync-cache/sessions/session-B.json
    workspace_id = ws-B
  ```

  检查：读取 session-A 只能得到 ws-A，读取 session-B 只能得到 ws-B；不存在 `temp-run/.workspace-sync-cache/current.json` 或用户级 fallback；删除其中一个文件不影响另一个。测试完成后删除临时目录。

- [ ] **Step 3: 验证安全失败矩阵**

  对以下输入逐项核对文档行为，不得出现自动猜测或全局回退：

  | 场景 | 预期 |
  | --- | --- |
  | 缓存不存在 | 要求 list/pull/显式 workspace |
  | JSON 损坏 | 报错并要求重新选择 |
  | workspace ID 不存在 | 报错，不按名称/最近修改猜测 |
  | session ID 含路径穿越 | 拒绝解析 |
  | 无 session ID + 显式 workspace | 仅完成单次操作，不持久化共享状态 |
  | 无 session ID + 无显式 workspace | 停止 |
  | 两会话不同 workspace | 各自只读写自己的 workspace |

- [ ] **Step 4: 同步本机活动副本**

  在主仓库工作树中（源分支合并后）执行，不把活动副本加入 Git：

  ```bash
  rsync -a \
    --exclude='.git' \
    --exclude='.agents/' \
    --exclude='.claude/' \
    --exclude='config.json' \
    --exclude='.superpowers/' \
    ./ .agents/skills/workspace-sync/
  ```

  然后比较 source 与 active copy 的所有 Skill、action、reference、README、CONTEXT 和模板文件，确认内容一致；保留 active copy 的本地配置，不 stage `.agents/`。

- [ ] **Step 5: 最终状态检查**

  Run:

  ```bash
  git diff --check origin/main..HEAD
  git status --short --branch
  git log --oneline --decorate origin/main..HEAD
  ```

  Expected: 所有文档检查通过；只存在本次分支提交和用户已有的未跟踪活动副本；报告本地分支、提交列表和未执行 push 的状态。

## Self-Review Checklist

- Spec coverage: Tasks 1-4 cover state layers, cache path/schema, runtime contract, command behavior, project path precedence, legacy compatibility, concurrency, error handling, no-ignore boundary and acceptance criteria.
- Placeholder scan: plan contains no unresolved marker or unspecified implementation step; `<run_dir>` and `<session-id>` are intentional contract placeholders defined in Task 1.
- Interface consistency: every task uses the same cache path, fields, command override convention, and project path precedence defined in the global constraints.
- Scope check: the project has no executable state adapter; the plan updates the documented Skill contract and validates it with static checks rather than inventing a new runtime dependency.
