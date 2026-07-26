# compile

## 命令

```text
/workspace-sync compile
```

这是 AI 对话中的 workspace-sync 指令。它使用已经选择的当前 workspace，不另加 workspace 参数，也不读取其他迭代。

## 目标

把当前 workspace 的自由格式 raw Markdown，或当前会话中已经明确确认的规划结论，增量整理为 Karpathy LLM Wiki 风格的开发图谱：保留 raw，维护正式节点、候选、关系、生成视图、冲突和操作日志。

## 输入边界

- 默认扫描当前 workspace 的 `raw/*.md`。
- raw 不要求固定格式、章节、YAML 或 frontmatter。
- 新规划内容必须追加为新 raw，不覆盖以前的 raw。
- 完整对话不是 compile 的必需输入，也不默认保存完整对话。
- 没有 raw 时，只有当前会话中用户已经明确确认的开发任务/规划结论才能生成新的 raw；未确认想法只能生成待确认项。

## 步骤

### 1. 确认上下文

读取：

- 根 `SCHEMA.md`；
- 当前 workspace 的 `workspace.md`；
- 当前 workspace 的 `wiki/overview.md`、`wiki/index.md`、`wiki/log.md`；
- 受影响的 raw、正式节点和候选页面。

对 Vault 内容的读取使用 Obsidian CLI。若当前 workspace 不存在，要求用户输入名称并先初始化，不猜测或借用其他 workspace。

### 2. 产生 raw（仅在需要时）

如果输入来自当前 AI 会话而不是已有 raw：

1. 从会话中提取用户明确确认的目标、任务、约束、决策和验收边界；
2. 以自由格式 Markdown 创建一个新的 `raw/<timestamp>-planning.md`；
3. 记录来源是当前会话和确认范围，不保存完整对话；
4. 没有明确确认内容时，不生成正式 raw 事实，向用户报告待确认项。

raw 文件通过 Obsidian CLI 创建，创建后不可被 compile 覆盖。

### 3. 增量编译图谱

对新增或变化的 raw：

- 识别项目、系统、能力、能力缺口、联调点、任务和技术决策；
- 用稳定节点 ID 匹配已有节点；名称相同不能自动合并；
- 在节点正文中维护“关系类型 + `[[node-id]]`”的语义 Wiki 链接；
- YAML 只保存身份、类型、状态、时间和来源，不复制关系字段；
- 同一目标/验收边界的变化保留原任务 ID 并追加修订历史；整体改写时保留旧任务，创建新任务并建立取代关系；
- 任务状态只有用户明确确认或明确事实支持时才变更；不能由 AI 猜测、子任务完成或代码提交静默更新。

### 4. 处理不确定、冲突和候选

- “可能、考虑、待确认、以后再看”等内容进入当前 workspace 的待确认项，不进入确定事实；
- 互相冲突的 raw 都保留，相关节点标记冲突；无冲突内容照常编译；
- 从缺口或联调点推导出的工作只生成 `wiki/candidates/` 候选页，不直接创建正式任务；
- 用户确认候选后，创建新稳定 ID 的正式任务并保留候选页的转化历史；
- 用户拒绝候选后保留拒绝理由，隐藏在待处理列表中，除非新证据出现，不重复建议；
- 删除任务使用软删除，保留 ID、历史和删除记录。

### 5. 生成视图

通过 Obsidian CLI 重建当前 workspace：

- `wiki/overview.md`：目标、缺口、联调、任务状态、阻塞、待确认项、候选、冲突、健康 warning 和下一步；
- `wiki/index.md`：按节点类型列出完整导航、摘要、状态、来源计数和诊断提示。

这两个文件是生成页面，人工不在其中维护事实。`wiki/log.md` 只追加操作审计，不覆盖历史。

### 6. 链接健康检查

通过 Obsidian CLI 对当前 workspace 的正式 `wiki/nodes/` 页面执行只读检查；待确认候选、raw、workspace 元数据、overview、index 和 log 不作为正式图谱关系源。

检查至少覆盖：

- 未解析链接；
- 孤立节点；
- 无出链节点；
- 必要的 links/backlinks 查询。

健康问题不自动创建占位节点、不自动修复人工页面、不自动生成正式任务。结果展示在 overview；只有问题首次出现、状态变化或解决时才追加 log。健康问题通过稳定指纹追踪，不因重复检查产生噪声。

健康问题是 warning，不阻断成功编译。Obsidian CLI 不可用、目标 workspace 无法访问或写入失败等执行错误才算 compile 失败；失败不自动 commit，保留现场并报告原因。

### 7. 提交

- 有 raw、节点、生成页面或健康问题状态变化时，创建本地 Git commit；
- 只有 warning 但内容已成功写入时，仍创建 commit；
- 没有任何文件变化时只返回 no-op，不创建空 commit；
- compile 不推送 Git 远端，远端同步由 `push` 负责。

## 输出

完成后报告：

- 当前 workspace；
- 新增/更新的 raw、节点、关系、候选和冲突；
- 用户需要确认的候选或任务状态变化；
- overview/index 路径；
- 健康检查 warning；
- 是否创建本地 commit 及 commit ID；
- 下一步建议（确认候选、修复链接、继续开发或执行 push）。
