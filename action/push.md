# push

## 命令

```bash
/workspace-sync push <workspace-name>
```

## 作用

把当前会话的工作上下文（对话摘要 + 涉及项目的 git 指针 + skill 状态）打包上传到已配置的后端。

## 执行步骤

### Step 1: 运行 prepare 脚本

```bash
WS_SKILL_DIR="<当前实际使用的 workspace-sync skill 目录>"
chmod +x "$WS_SKILL_DIR/scripts/ws-push-prepare.sh"
bash "$WS_SKILL_DIR/scripts/ws-push-prepare.sh" "$WS_NAME"
```

脚本完成以下工作：
- 按 SKILL.md 中的 `validate_ws_name` 校验名称
- 定位当前 session jsonl（主路径 + fallback 扫描）
- 运行 `detect-projects.sh` 识别涉及的项目
- 创建 staging 目录，复制 conversation.jsonl
- 对每个项目执行 `git status` / `git fetch` 收集 `code_status`
- 读取远端已有版本号和 created_at
- 将结果写入 `$STAGE_DIR/.prepare-result.json` 并输出到 stdout

脚本输出 JSON：

```json
{
  "stage_dir": "/path/to/staging/ws_name",
  "session_jsonl": "/path/to/xxx.jsonl",
  "backend": "gitlab",
  "projects": [
    {"name": "shanks-manage", "path": "...", "remote": "...",
     "head": "abc123", "branch": "feature/x", "upstream": "origin/feature/x",
     "code_status": "clean"}
  ],
  "code_warnings": ["⚠  shanks-manage: 存在未提交改动"],
  "remote_version": 2,
  "remote_created_at": "2026-04-15T18:00:00+08:00",
  "old_summary_path": "/path/to/old/summary.md"
}
```

致命错误（无 upstream、staging 路径非法等）时脚本 exit 1，JSON 含 `error` 字段，直接报给用户。

### Step 2: 展示确认

将 `projects` 整理为编号列表展示：

```
检测到本次对话涉及 N 个项目:
  [1] shanks-manage  (feature/import)
工作空间名称: feature-import
确认推送? [Y/n]
```

`projects` 为空 → 告知"纯讨论模式"，继续。
用户取消 → 停止。

### Step 3: 代码状态确认（如有警告）

若 `code_warnings` 非空，展示：

```
以下项目的代码状态不是完全干净:
  ⚠  shanks-manage: 存在未提交改动

此次 workspace 只保存对话上下文，代码侧以当前已推送的 HEAD 为准。
在另一台设备 pull 后，上述代码改动不会被恢复。
是否仍然继续推送? [y/N]
```

用户选 N → 停止。
用户选 Y → 继续。

### Step 4: 生成 summary.md 和 manifest.json

Claude 用 Read 工具读 `session_jsonl`，决定生成策略。

**摘要的核心目标**：让一个在新设备上 pull 的人，读完摘要就能理解：
- 我们在做什么、为什么做（整体目标）
- 讨论了哪些问题、探索了哪些方案、得出了什么结论（讨论脉络）
- 拍板了哪些决策及原因（关键决策）
- 代码层面做到哪、下一步是什么（项目进度）

**不能只记录进度**，必须捕获讨论的话题、思路和结论，否则 pull 后的人连任务背景都不知道。

---

**首次 push（`remote_version == 0`）：**

从头提炼整段对话，按 SKILL.md 中的 summary.md 格式生成完整摘要，重点关注：
- 任务发起的背景和目标
- 对话中讨论过的方案（包括被否定的选项及原因）
- 明确达成的结论和决策
- 当前停在哪、下一步做什么

**更新 push（`remote_version > 0` 且 `old_summary_path` 非空）：**

先读旧摘要，以旧摘要为基础增量更新：
- `整体目标` / `背景与约束`：原则上保留，本次对话有明确修正时才更新
- `讨论脉络`：**追加**本次新增的讨论话题和结论，不要覆盖历史记录；形成累积的讨论历程
- `关键决策`：追加本次新增的决策；已有决策若被推翻需标注并说明原因
- 各项目段落：
  - `系统认知`：**追加**本次发现的系统知识；已有条目保留，不要删减
  - `已完成`：追加本次完成的工作
  - `进行中`：**替换**为当前真实轨迹，不保留上次的进行中描述
  - `下一步`：**替换**为当前最具体的下一动作
  - `注意事项`：追加本次新发现的坑或约束
- 本次未涉及的项目段落直接保留
- 宁可信息量多，不要为了简洁丢失任何关键背景

用 Write 工具写入：
- `$stage_dir/summary.md`
- `$stage_dir/manifest.json`（按 SKILL.md 的 manifest 格式；`version` 字段先写 0，upload 脚本会自动更新）

manifest.json 中 `projects` 数组来自 prepare JSON 的 `projects` 字段（包含 code_status）：

```json
{
  "name": "<WS_NAME>",
  "version": 0,
  "previous_version": "<remote_version>",
  "conversation_id": "<从 session jsonl 提取>",
  "source_device": "<hostname>",
  "source_cwd": "<cwd>",
  "created_at": "<remote_created_at 或 now（首次 push）>",
  "updated_at": "<now>",
  "projects": [...]
}
```

### Step 5: 运行 upload 脚本

```bash
chmod +x "$WS_SKILL_DIR/scripts/ws-push-upload.sh"
bash "$WS_SKILL_DIR/scripts/ws-push-upload.sh" "$WS_NAME"
```

脚本完成：
- 写 `projects/<name>/meta.json`（git 指针 + code_status）
- 导出 skill states
- 二次读取远端版本做并发校验
- 上传到对应 backend

**退出码 0（成功）**，JSON 含 `success: true, version, dirty_projects`：

```
✓ 工作空间已推送: <name>
  - 后端: <backend>
  - 版本: v<version>
  - 涉及项目: N 个
  - skill 状态: <exported/skipped>
  - 在另一设备用 /workspace-sync pull <name> 恢复
```

dirty_projects 非空时追加：

```
⚠  提醒：以下项目有未同步的本地代码，pull 后需手动恢复:
   - shanks-manage (dirty)
```

**退出码 2（并发冲突）**，JSON 含 `conflict: true, base_version, latest_version, proposed_version`：

```
⚠ 并发冲突: 你本地基于版本 v<base_version>，当前远端已是 v<latest_version>
  如果继续，将提交 v<proposed_version>
  是否继续? [y/N]
```

用户选 Y → `bash ws-push-upload.sh "$WS_NAME" --force`，继续。
用户选 N → 停止。

**退出码 1（其他错误）** → 展示 JSON 中的 `error` 字段给用户。
