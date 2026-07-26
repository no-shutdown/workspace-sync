# workspace 与 Wiki 布局

## 根目录

~~~text
knowledge-base/
├── SCHEMA.md
└── <workspace-folder>/
    ├── workspace.md
    ├── raw/
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
~~~

目录名是用户可读名称，可以受控改名；workspace 身份以 \`workspace.md\` 中的稳定 ID 为准。

## workspace.md

~~~md
---
workspace_id: ws-20260727-abc123
name: task-graph
lifecycle: active
created_at: 2026-07-27T10:00:00+08:00
updated_at: 2026-07-27T10:00:00+08:00
---

# task-graph

## 归档

尚未归档。
~~~

允许的生命周期：\`active\`、\`paused\`、\`archived\`。完成或放弃一个迭代时归档，不默认物理删除。

## raw

raw 只要求文件名以 \`.md\` 结尾。内容可以是会议笔记、规划稿、问题记录、设计讨论或工具输出，不要求模板。compile 不把 raw 转移到别处，也不覆盖它。

推荐文件名包含日期和人类可读主题，例如：

~~~text
raw/2026-07-27-order-integration-planning.md
raw/2026-07-28-follow-up.md
~~~

文件名不是事实身份；节点稳定 ID 和来源引用才是身份依据。

## 节点页面

最小 frontmatter：

~~~yaml
---
id: task-xxxx
type: task
title: 实现订单导入
created_at: 2026-07-27T10:00:00+08:00
updated_at: 2026-07-27T10:00:00+08:00
source_refs:
  - ../../../raw/2026-07-27-order-integration-planning.md
---
~~~

任务节点额外包含 \`status\`。YAML 不存语义关系；关系放在 Markdown 正文中：

~~~md
## 关系

- 解决：[[gap-order-import]]
- 依赖：[[task-auth-refactor]]
- 关联项目：[[project-order-service]]
~~~

节点页面中允许保留说明、验收边界、历史和变更记录。编译器更新时必须保留人工内容，无法安全合并时保留冲突并报告。

## 候选页面

候选位于 \`wiki/candidates/\`，例如：

~~~md
---
candidate_id: candidate-task-001
kind: task
status: pending
title: 增加订单导入联调测试
source_refs:
  - ../../raw/2026-07-27-order-integration-planning.md
---

## 推导理由

由 [[gap-order-import]] 和 [[integration-order-api]] 推导。

## 决策

待用户确认。
~~~

确认后创建新的正式任务页；候选页不改成正式任务页，不复用候选 ID。

## 生成文件

- \`overview.md\`：面向人和新 AI 的当前接手视图，可重建。
- \`index.md\`：按节点类型的完整目录，可重建。
- \`log.md\`：操作、输入、输出、冲突、项目采集和健康问题状态变化的追加审计日志。

生成文件不承载独立事实；人工修改进入 raw 或节点页面。

## 隔离规则

语义 Wiki 链接必须指向同一 workspace 内的节点。跨 workspace 引用不参与 compile、图谱关系或健康检查；如用户需要，可以在正文写普通外部引用并明确路径，但不能隐式共享节点。
