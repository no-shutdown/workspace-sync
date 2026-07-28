# 代码项目现场

## 目的

workspace 对代码项目有感知，但知识库不拥有代码。项目现场记录“这个迭代涉及哪些仓库、各自停在哪里”，用于人和 AI 接手以及换设备恢复；项目不是正式图谱节点。

## 项目支撑记录

项目记录位于：

```text
图谱/说明/项目/<项目名称>.md
```

它可以包含：

~~~yaml
---
record_kind: 项目
project_id: project-xxxx
title: 数据服务
remote: gitlab.example.com/team/data-service
branch: main
upstream: origin/main
head: abc1234
dirty: false
captured_at: 2026-07-27T10:00:00+08:00
---
~~~

项目记录是支撑资料，不具有正式图谱 `type`，不参与系统层级、缺口链路、任务状态统计或主 Mermaid 图。任务/系统需要说明实现载体时，在正文的“实现项目”部分引用项目记录，或保存非语义的项目 ID 元数据。

本机绝对路径只在本地 state 文件中保存，不进入共享 Git 知识库。

## remote 规范化

以下远端应归一到同一 key：

~~~text
git@gitlab.example.com:team/data-service.git
ssh://git@gitlab.example.com/team/data-service.git
https://gitlab.example.com/team/data-service.git
→ gitlab.example.com/team/data-service
~~~

规范化时去除协议、用户信息和结尾 `.git`，host 小写，并将 host:path 统一为 host/path。

## push 采集

push 只读采集当前 workspace 已登记的项目支撑记录和用户确认的新项目。当前 cwd 发现的仓库是候选，不自动加入；不扫描所有本地仓库。

对每个已确认项目采集：

- 规范化 remote；
- 当前 branch；
- upstream；
- HEAD commit；
- dirty 状态；
- captured_at。

dirty 项目不阻断知识库 push。保存 dirty 标志和 Git 指针，不保存 diff、未提交文件或代码副本。

## pull 恢复

恢复顺序：

1. 如用户在本次操作中明确提供路径，验证 remote 后优先使用；
2. 检查当前 `run_dir` 或当前 cwd 中与目标 remote 匹配的仓库；
3. 再根据 remote 查询设备级 state 中的 `project_paths`；
4. 仍无法唯一定位时，要求用户确认。

只有以下条件都满足才恢复分支和 HEAD：目标是匹配的 Git 仓库、工作树干净、分支存在、目标 commit 可用。否则跳过并报告，不能强制覆盖本地代码。

当前会话中的路径选择只影响本次解析和当前会话缓存，不覆盖共享知识库事实，也不自动改写用户级 `project_paths`；这样不同会话可以在同一代码仓库的不同 worktree 中并行工作。

## 项目与任务关系

一个任务可以记录多个实现项目，一个系统也可以由多个项目实现。项目关联用于恢复代码现场，不作为架构父子关系；任务的架构位置必须通过缺口链路或 `涉及系统` 关系表达。
