# config

## 命令

```text
/workspace-sync config
```

## 目标

配置一个个人开发知识库 Git 仓库，并指定本地 clone 路径。配置不创建第二套 workspace 存储，也不保存 Git token。

## 配置字段

```json
{
  "repository": {
    "url": "git@gitlab.example.com:me/dev-knowledge.git",
    "branch": "main",
    "path": "C:/Users/me/dev-knowledge"
  },
  "state_file": null
}
```

逐项询问：

1. 知识库 Git 仓库链接。
2. 分支名，默认 `main`。
3. 本机知识库 clone 路径。
4. 用户想用 Obsidian 时，记录可选的 `obsidian.enabled` 和 `obsidian.vault`。已有设置默认保留。

不要询问或写入 token；使用用户已经配置好的 SSH、Git Credential Manager 或其他 Git 认证方式。

## 验证顺序

1. 检查 Git URL 非空、分支名合法、路径不是危险目录。
2. 如果本地路径已有 Git 仓库，确认其 remote 与配置 URL 指向同一知识库；不匹配时停止并要求用户选择新路径或重新配置。
3. 如果本地路径不存在，创建父目录并 clone 已存在的知识库仓库；不要自动创建远端项目。
4. 如果仓库为空，初始化根 `SCHEMA.md` 和 Git 提交；如果仓库已有内容，确认根结构可读。
5. 用户选择启用 Obsidian 时，检查 CLI 能否定位相同的知识库。不可用时报告并使用文件接口；HTML 导出依赖独立安装。

验证失败不写入新的配置值。

## 写入与收尾

- 只更新 `config.json` 的知识库连接、本机路径和用户明确要求调整的 Obsidian 设置。
- `state_file` 只保留用户/设备级信息，例如 `project_paths`；旧 `current_workspace_id`、`current_workspace_name` 只作为历史字段保留并忽略，不再写入。
- 当前 workspace 绑定改由会话缓存 `<run_dir>/.workspace-sync-cache/sessions/<session-id>.json` 管理；`config` 不创建也不更新任何 workspace 选择。
- 已有配置先保留备份，再替换经过验证的字段。
- 成功后展示配置生效路径，并提示用户通过 `/workspace-sync pull` 或 `/workspace-sync list` 在当前会话中建立 workspace；项目路径映射仍由用户/设备级 `state_file` 管理。
