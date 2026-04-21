# 配置流程

适用于两种场景：

- 首次使用：`config.json` 不存在，或 `backend` 为空，或当前 backend 必填字段缺失
- 主动重配：用户执行 `/workspace-sync config`

执行原则：

- 按顺序逐项提问
- 不要一次性把所有问题都抛给用户
- 先验证，再写入
- 只更新当前 backend 对应字段和 `backend`

## Step 1: 选择 backend

```text
请选择 workspace-sync 的存储后端：

[1] Local   - 保存到本地目录，适合配合 Dropbox / OneDrive / iCloud
[2] GitHub  - 保存到一个已存在的 GitHub 仓库
[3] GitLab  - 保存到一个已存在的 GitLab 仓库
[4] MinIO   - 保存到一个已存在的 MinIO bucket
```

## Step 2: 收集并验证参数

### Local

依次询问：

1. 本地同步目录路径

收到后立即校验：

- 路径非空
- 目录已经存在
- 当前环境对该目录可读写

### GitHub

依次询问：

1. Personal Access Token
2. 仓库路径，格式 `owner/name`
3. 分支名，默认 `main`

收到后立即校验：

- token 非空
- repo 格式合法
- 可以通过 GitHub API 访问仓库

可用 `gh api` 或 `curl` 进行只读验证；验证失败时直接把 HTTP 状态码或错误信息告诉用户。

### GitLab

依次询问：

1. GitLab host
2. Personal Access Token
3. 项目路径，格式 `group/name`
4. 分支名，默认 `main`
5. 协议，默认 `https`

收到后立即校验：

- host / token / project_path 非空
- 可以通过 GitLab API 访问目标项目

### MinIO

依次询问：

1. endpoint
2. access key
3. secret key
4. bucket
5. prefix，默认 `workspaces/`
6. `mc_alias`，默认 `claude-workspace-sync`

收到后立即校验：

- 本机已安装 `mc`
- 能成功设置 alias
- 目标 bucket 存在且当前凭据可访问

## Step 3: 写入 `config.json`

写入要求：

- 当前文件不存在时，从 `templates/config.json.example` 初始化结构
- 只更新当前 backend 字段和 `backend`
- 保留其他 backend 字段
- 保留 `scan_roots`、`cache_dir`、`local_paths_file`

建议直接用模型的文件编辑能力修改 JSON，而不是再引入额外仓库脚本。

## Step 4: 收尾

- 如果这是用户主动执行 `/workspace-sync config`，写完后确认成功并告知生效配置路径
- 如果这是其他命令中途触发的配置流程，写完后继续原命令
