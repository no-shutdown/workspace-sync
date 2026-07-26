# 编译默认本地提交，远端推送显式执行

---
status: accepted
---

知识库编译完成后默认写入知识库 Git 仓库并创建本地 commit；不会自动推送到远端。需要跨设备同步时，用户通过显式参数或独立操作开启 push，例如 `compile <workspace> --push`。

## Consequences

- 一条普通编译命令可以完成整理和本地版本留存，不需要额外手工提交。
- 远端 GitLab 或其他 Git 服务不会因为一次编译被隐式写入。
- 编译结果、冲突标记和原始档历史都能在 push 前通过 Git diff 检查。
