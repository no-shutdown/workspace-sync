# push 只提交当前工作空间

---
status: accepted
---

个人开发知识库虽然位于一个 Git 仓库中，但 push 默认只 stage 和 commit 当前 workspace 目录下的变更。其他 workspace 和根目录 `SCHEMA.md` 的修改必须被提示但不能自动纳入本次提交。

## Consequences

- 当前 workspace 的 push 不会意外提交其他迭代的工作。
- 根级规则变更需要独立、显式的提交流程。
- push 需要检测并报告提交范围外的未提交变更。
