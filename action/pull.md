# pull

## 命令

```bash
/workspace-sync pull <workspace-name>
```

## 目标

下载并恢复指定 workspace，同时把摘要重新呈现给用户，便于立即继续工作。

## 执行步骤

### Step 1: 校验名称与配置

- 按 `SKILL.md` 的 `validate_ws_name` 校验 `WS_NAME`
- 读取当前生效 `config.json`
- 配置缺失时，转入 `references/setup.md`

### Step 2: 先比较本地缓存与远端

优先读取本地缓存的 `manifest.json`。
如果 backend 支持轻量远端查询，再读取远端 `manifest.json` 的 `version` / `updated_at`。

决策规则：

- 本地无、远端有：下载远端
- 本地有、远端无：从本地缓存恢复，并明确说明是 `local_only`
- 本地和远端都有，远端更新：下载远端
- 本地和远端都有，本地相同或更新：优先保守处理，先向用户说明版本关系再决定是否强制覆盖
- 两边都没有：报错停止

### Step 3: 恢复 workspace 基础文件

恢复：

- `manifest.json`
- `summary.md`
- `conversation.jsonl`（默认应存在）

一致性校验：

- 若 `manifest.conversation_saved=true` 但 `conversation.jsonl` 缺失，标记为远端数据不一致并提示用户重新 `push`
- 若 `manifest.conversation_saved=false`，明确标记为“降级 workspace”，告知上下文完整性受限

### Step 4: 恢复项目代码位置

对 `manifest.projects` 中的每个项目：

1. 优先查 `local-paths.json`
2. 再在 `scan_roots` 下扫描 git 仓库并按规范化 remote 精确匹配
3. 唯一命中时自动采用，并写回 `local-paths.json`
4. 多个候选时让用户选
5. 没有候选时再问用户本地路径

恢复前先做校验：

- 目标目录必须是 git 仓库
- `remote.origin.url` 规范化后必须和记录匹配
- 本地工作区如果有未提交改动，则跳过该项目，不强制覆盖

恢复动作：

- 切到记录的分支
- 尝试 checkout 到记录的 `HEAD`
- 失败时标记为 `skipped_head_missing`

### Step 5: 导入 portable skill states

读取各 skill 的 `workspace-sync.contract.json`：

- `sync_paths`：直接恢复对应路径
- `import_command`：仅在 contract 明确要求时，调用该 skill 自己的命令

结果单独汇报为：

- `restored`
- `skipped`
- `missing`
- `deferred`

### Step 6: 重新呈现上下文

不要只说”恢复成功”。必须分两层呈现，让用户同时看到当前 workspace 的细节和更大 Epic 的全貌。

**微观层（本 workspace 内）**，基于 `summary.md`：

- 整体目标与验收标准
- 背景与约束
- 关键决策
- 每个项目的当前停点（分支、HEAD、代码状态）
- 未决问题

**宏观层（Epic 全景）**，基于 `summary.md` 章节 8：

- 本 workspace 在 Epic 中的位置
- Epic 已完成 vs 待完成的任务列表
- 完成本 workspace 后建议的下一个 workspace 或 task

如果 `summary.md` 缺少宏观层（章节 8 为空或不存在）：

- 主动通过 issue tracker 补全（有 GitLab/GitHub 配置时自动查询；否则明确提示用户补充）
- 告知用户”当前 summary 缺少 Epic 全景，建议在本次工作结束后 push 时补全章节 8”

如果 `conversation.jsonl` 缺失：

- 明确告知当前恢复为降级模式
- 提示用户该摘要可能遗漏历史细节
- 建议在源设备重新执行一次包含完整对话的 `push`

如果某些项目因为本地脏工作区、路径未解析或 `HEAD` 缺失而未恢复完整，必须明确提示：

- 摘要仅能作为参考
- 当前代码现场和摘要可能不完全一致

### Step 7: 给出衔接动作

衔接动作需覆盖两个层次，不要要求用户再手打一遍 `/workspace-sync` 命令：

- **立即可做**：根据 `summary.md` 章节 7 的”微观下一步”，给出一个具体的衔接命令或操作
- **完成后下一步**：根据 `summary.md` 章节 8 的”Epic 待完成”，说明本 workspace 全部验收后应该开始的下一个 task 是什么
