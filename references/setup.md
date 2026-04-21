# 首次配置流程

触发条件:`config.json` 中 `backend=null` 或对应 backend 的必填字段缺失。

Claude 必须按以下顺序交互,**不要一次问所有问题**。

---

## Step 1: 选择后端

```
这是你第一次使用 workspace-sync,请选择云端存储后端:

[1] GitLab   - 把工作空间作为 commit 推到一个已存在的 GitLab 仓库
               你需要准备:仓库地址 + Personal Access Token

[2] MinIO    - 把工作空间作为对象存到一个已存在的 bucket
               你需要准备:endpoint、access_key、secret_key、bucket 名
               另外本机需要装 mc 客户端(MinIO CLI)

请回复 1 或 2。
```

等用户回复。

---

## Step 2(选 GitLab):收集配置

依次问:
1. GitLab 主机(例如 `gitlab.com` 或 `your.gitlab.com`)
2. Personal Access Token(scope 需要 api + read_repository + write_repository)
3. 仓库路径(`namespace/name` 格式,**必须是已存在的仓库**)
4. 使用的分支(默认 `main`,可直接回车跳过)

收齐后立即验证仓库存在:

```bash
ENC_PATH=$(printf '%s' "$GITLAB_PROJECT_PATH" | sed 's|/|%2F|g')
RESULT=$(no_proxy="$GITLAB_HOST" curl -s -o /dev/null -w "%{http_code}" \
  --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "https://${GITLAB_HOST}/api/v4/projects/${ENC_PATH}")

if [[ "$RESULT" != "200" ]]; then
  # 401 = token 无效/过期  404 = 仓库不存在或无权限
  echo "❌ 仓库验证失败 (HTTP $RESULT)"
  exit 1
fi
echo "✓ 仓库验证通过"
```

验证失败 → 告知用户具体原因(401/404),停止配置,等用户修复后重试。
验证通过 → 跳到 Step 4 写 config.json。

---

## Step 3(选 MinIO):收集配置

先检查 mc 是否安装:

```bash
if ! command -v mc &>/dev/null; then
  echo "❌ 未找到 mc(MinIO 客户端),请先安装:"
  echo "  Windows: scoop install mc  或  choco install minio-client"
  echo "  macOS:   brew install minio/stable/mc"
  echo "  Linux:   curl https://dl.min.io/client/mc/release/linux-amd64/mc -o mc && chmod +x mc"
  exit 1
fi
```

mc 可用后,依次问:
1. MinIO endpoint(例如 `https://minio.example.com`)
2. Access Key
3. Secret Key
4. Bucket 名称(**必须已存在**)
5. Bucket 内前缀(例如 `workspaces/`,留空则存在根)

配置 alias 并验证 bucket:

```bash
MC_ALIAS="claude-workspace-sync"
mc alias set "$MC_ALIAS" "$MINIO_ENDPOINT" "$MINIO_AK" "$MINIO_SK" --api S3v4

if ! mc ls "$MC_ALIAS/$MINIO_BUCKET" &>/dev/null; then
  echo "❌ Bucket '$MINIO_BUCKET' 不存在或无权限访问"
  exit 1
fi
echo "✓ Bucket 验证通过"
```

验证通过 → 跳到 Step 4 写 config.json。

---

## Step 4: 写入 config.json

用 Write 工具更新 `<当前 CLI 状态目录>/skills/workspace-sync/config.json`,只写入相关字段,保留其他字段不变。

写入完成后输出:

```
✓ 配置已保存。继续执行 /workspace-sync <原命令>...
```

然后继续原本用户请求的操作。
