# 配置流程

适用于两种场景：

- 首次使用：`config.json` 中 `backend=null` 或对应 backend 的必填字段缺失
- 主动重配：用户执行 `/workspace-sync config`

Claude 必须按以下顺序交互，**不要一次问所有问题**。

---

## Step 1: 选择后端

```text
请选择 workspace-sync 的存储后端：

[1] Local   - 保存到本地目录，适合配合 Dropbox / OneDrive / iCloud
[2] GitHub  - 保存到一个已存在的 GitHub 仓库
[3] GitLab  - 保存到一个已存在的 GitLab 仓库
[4] MinIO   - 保存到一个已存在的 MinIO bucket

请回复 1、2、3 或 4。
```

等用户回复。

---

## Step 2(Local): 收集配置

依次问：

1. 本地同步目录路径，例如 `~/Dropbox/claude-workspaces`

收到后立即验证目录存在，并写入：

```bash
bash "$WS_SKILL_DIR/scripts/ws-config.sh" \
  local \
  --path "$LOCAL_PATH"
```

如果目录不存在：

```text
❌ 目录不存在：<path>
请先创建该目录，或改成一个已经存在并会被云盘同步的目录。
```

---

## Step 2(GitHub): 收集配置

依次问：

1. GitHub Personal Access Token
2. 仓库路径，格式 `owner/name`
3. 分支名，默认 `main`，可直接回车跳过

收齐后立刻验证并写入：

```bash
bash "$WS_SKILL_DIR/scripts/ws-config.sh" \
  github \
  --token "$GITHUB_TOKEN" \
  --repo "$GITHUB_REPO" \
  --branch "$GITHUB_BRANCH"
```

验证失败时，明确报出 HTTP 状态码并停止，让用户修正后重试。

---

## Step 2(GitLab): 收集配置

依次问：

1. GitLab 主机，例如 `gitlab.com` 或 `your.gitlab.com`
2. Personal Access Token
3. 仓库路径，格式 `namespace/name`
4. 分支名，默认 `main`，可直接回车跳过
5. 协议，默认 `https`，通常无需改动

收齐后立刻验证并写入：

```bash
bash "$WS_SKILL_DIR/scripts/ws-config.sh" \
  gitlab \
  --host "$GITLAB_HOST" \
  --token "$GITLAB_TOKEN" \
  --project-path "$GITLAB_PROJECT_PATH" \
  --branch "$GITLAB_BRANCH" \
  --protocol "$GITLAB_PROTOCOL"
```

验证失败时，明确报出 HTTP 状态码并停止，让用户修正后重试。

---

## Step 2(MinIO): 收集配置

先确认本机已安装 `mc`，再依次问：

1. MinIO endpoint，例如 `https://minio.example.com`
2. Access Key
3. Secret Key
4. Bucket 名称
5. Bucket 前缀，默认 `workspaces/`
6. `mc` alias，默认 `claude-workspace-sync`

收齐后立刻验证并写入：

```bash
bash "$WS_SKILL_DIR/scripts/ws-config.sh" \
  minio \
  --endpoint "$MINIO_ENDPOINT" \
  --access-key "$MINIO_ACCESS_KEY" \
  --secret-key "$MINIO_SECRET_KEY" \
  --bucket "$MINIO_BUCKET" \
  --prefix "$MINIO_PREFIX" \
  --mc-alias "$MINIO_MC_ALIAS"
```

如果 `mc` 未安装，直接报错并给出安装提示；如果 bucket 不存在或无权限，也直接报错停止。

---

## Step 3: 保存成功后的收尾

配置脚本成功后，会返回当前生效的 `config.json` 路径。

向用户输出：

```text
✓ 配置已保存。
```

如果本流程是从其他命令中途进入的，则继续执行原命令。
如果这是用户主动执行 `/workspace-sync config`，则到此结束。
