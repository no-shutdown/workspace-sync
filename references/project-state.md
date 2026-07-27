# 代码项目现场

## 目的

workspace 对代码项目有感知，但知识库不拥有代码。项目现场记录“这个迭代涉及哪些仓库、各自停在哪里”，用于人和 AI 接手以及换设备恢复。

## 项目节点与现场记录

项目正式节点可以包含：

~~~yaml
---
id: project-order-service
type: 项目
title: 订单服务
remote: gitlab.example.com/team/order-service
created_at: 2026-07-27T10:00:00+08:00
updated_at: 2026-07-27T10:00:00+08:00
---
~~~

workspace 的项目现场作为该项目节点或 workspace 日志中的可追溯记录，至少包括：

- 规范化 remote；
- branch；
- upstream；
- HEAD commit；
- dirty；
- captured_at。

本机绝对路径只在本地 state 文件中保存，不进入共享 Git 知识库。

## remote 规范化

以下远端应归一到同一 key：

~~~text
git@gitlab.example.com:team/order-service.git
ssh://git@gitlab.example.com/team/order-service.git
https://gitlab.example.com/team/order-service.git
→ gitlab.example.com/team/order-service
~~~

规范化时去除协议、用户信息和结尾 .git，host 小写，并将 host:path 统一为 host/path。

## push 采集

push 只读采集已关联项目和用户确认的新项目。当前 cwd 发现的仓库是候选，不自动加入；不扫描所有本地仓库。

dirty 项目不阻断知识库 push。保存 dirty 标志和 Git 指针，不保存 diff、未提交文件或代码副本。

## pull 恢复

恢复顺序：

1. 根据 remote 查询本机 state 中的路径；
2. 如用户明确提供路径，验证 remote 后使用；
3. 检查当前 cwd 仅作为有限候选。

只有以下条件都满足才恢复分支和 HEAD：目标是匹配的 Git 仓库、工作树干净、分支存在、目标 commit 可用。否则跳过并报告，不能强制覆盖本地代码。

## 项目与任务关系

任务可以关联多个项目；项目也可以出现在多个 workspace 中。项目节点不是 workspace 归属，也不是任务树的父节点。一个系统可以由多个项目共同实现，图谱关系负责表达这些语义。
