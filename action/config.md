# config

## 命令

```text
/workspace-sync config
```

## 目标

配置一个个人开发知识库 Git 仓库，并把它作为本地 Obsidian Vault。配置不创建第二套 workspace 存储，也不保存 Git token。

## 配置字段

```json
{
  "repository": {
    "url": "git@gitlab.example.com:me/dev-knowledge.git",
    "branch": "main",
    "path": "C:/Users/me/Obsidian/dev-knowledge"
  },
  "obsidian": {
    "vault": "dev-knowledge"
  },
  "state_file": null
}
```

逐项询问：

1. 知识库 Git 仓库链接。
2. 分支名，默认 `main`。
3. 本机 clone/Vault 路径。
4. Obsidian Vault 名称（如果 CLI 通过路径定位，也记录可读名称）。

不要询问或写入 token；使用用户已经配置好的 SSH、Git Credential Manager 或其他 Git 认证方式。

## 验证顺序

1. 检查 Git URL 非空、分支名合法、路径不是危险目录。
2. 如果本地路径已有 Git 仓库，确认其 remote 与配置 URL 指向同一知识库；不匹配时停止并要求用户选择新路径或重新配置。
3. 如果本地路径不存在，创建父目录并 clone 已存在的知识库仓库；不要自动创建远端项目。
4. 如果仓库为空，初始化根 `SCHEMA.md` 和 Git 提交；如果仓库已有内容，确认根结构可读。
5. 检查 Obsidian CLI 可调用且能够定位该 Vault。CLI 不可用时报告安装/启动问题，不使用第二套 Vault 文件接口。

验证失败不写入新的配置值。

## 写入与收尾

- 只更新 `config.json` 的知识库连接和本机 Vault 信息。
- `current_workspace_id`、`current_workspace_name` 和项目本地路径写入本地 `state_file`，不能写入 Git 仓库。
- 已有配置先保留备份，再替换经过验证的字段。
- 成功后展示配置生效路径，并提示执行 `/workspace-sync pull` 或 `/workspace-sync list` 选择 workspace。
