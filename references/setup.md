# 知识库 Git 仓库配置流程

配置目标只有一个：让用户指定个人开发知识库 Git 仓库，并在本机 clone 后直接维护 Markdown，也可选用 Obsidian。workspace 不单独配置存储，也不保存成另一个共享缓存对象；当前 workspace/focus task 改为当前运行目录下的会话缓存。

## 逐项收集

按顺序询问，不要一次性抛出全部问题：

1. Git 仓库 URL；
2. 同步分支，默认 `main`；
3. 本机知识库 clone 路径；
4. 可选的 Obsidian Vault 名称与启用设置。

认证使用现有 SSH/Git Credential Manager/Git 配置。不要要求 token，也不要把 token 写入 `config.json`、Git remote 或 Markdown。

## 验证

### Git URL 与路径

- URL 非空且可被 Git 解析；
- 分支名非空；
- 本地路径不是根目录、用户主目录或其他宽泛危险目录；
- 已有目录如果是 Git 仓库，remote 必须与配置 URL 指向同一知识库；
- 不匹配时停止，不能在现有代码仓库上覆盖初始化知识库。

### 远端仓库

- 本地路径不存在时 clone 已存在的远端仓库；
- clone 失败直接报告认证、网络或权限错误；
- 不自动创建 GitLab/GitHub 项目，也不切换到其他远端；
- 空仓库可以初始化 `SCHEMA.md` 和基础提交。

### 可选的 Obsidian

需要 Obsidian 功能时，检查 CLI 能否定位配置指向的知识库。原有 `obsidian.vault` 设置可保留；使用规则见 `references/markdown.md`。HTML 的独立安装见 `references/html.md`。

## 写入配置

验证全部通过后：

1. 备份已有 `config.json`；
2. 只写入 `repository`、`obsidian` 和本地 `state_file` 配置；
3. `state_file` 只保存设备级配置和 `project_paths`；旧 `current_workspace_id`、`current_workspace_name` 只作为历史字段保留并忽略；
4. 不写入任何 workspace 选择；当前 workspace 和 focus task 只由 `<run_dir>/.workspace-sync-cache/sessions/<session-id>.json` 承载，该缓存不进入知识库 Git，也不写入 Obsidian 页面；
5. `config` 不选择 workspace，也不创建用户级全局 fallback；提示用户执行 `/workspace-sync pull` 或 `/workspace-sync list` 选择当前会话 workspace。

## 空仓库初始化

如果远端 Git 仓库为空：

```text
SCHEMA.md
```

由 skill 根据 `references/workspace-layout.md` 和仓库 Schema 约定初始化根规则文件并创建首个 Git commit。workspace 目录在用户第一次选择或新建 workspace 时创建。
