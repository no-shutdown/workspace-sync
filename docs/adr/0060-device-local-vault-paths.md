# 每台设备独立配置本地 Vault 路径

---
status: accepted
---

知识库 Git remote 和分支是跨设备共享的身份；本地 Vault 路径由每台设备单独配置。pull 在本地 Vault 不存在时，将同一 Git 仓库克隆到当前设备配置的位置，不把任何源设备绝对路径写入仓库或依赖它恢复。

## Consequences

- 同一知识库可以在不同操作系统和目录布局下使用。
- 本地路径配置属于设备状态，不进入 Wiki、raw 或 workspace 事实。
- pull 需要在克隆前验证目标路径和 Git 仓库身份。
