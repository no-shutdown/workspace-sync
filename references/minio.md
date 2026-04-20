# MinIO 后端实现

## 读取配置 & 准备 mc alias

```bash
MINIO_ENDPOINT=$(python3 -c "import json; d=json.load(open('$CONFIG')); print((d.get('minio') or {}).get('endpoint') or '')" 2>/dev/null)
MINIO_AK=$(python3 -c "import json; d=json.load(open('$CONFIG')); print((d.get('minio') or {}).get('access_key') or '')" 2>/dev/null)
MINIO_SK=$(python3 -c "import json; d=json.load(open('$CONFIG')); print((d.get('minio') or {}).get('secret_key') or '')" 2>/dev/null)
MINIO_BUCKET=$(python3 -c "import json; d=json.load(open('$CONFIG')); print((d.get('minio') or {}).get('bucket') or '')" 2>/dev/null)
MINIO_PREFIX=$(python3 -c "import json; d=json.load(open('$CONFIG')); print((d.get('minio') or {}).get('prefix') or '')" 2>/dev/null)
MC_ALIAS=$(python3 -c "import json; d=json.load(open('$CONFIG')); print((d.get('minio') or {}).get('mc_alias') or 'claude-workspace-sync')" 2>/dev/null)

mc alias set "$MC_ALIAS" "$MINIO_ENDPOINT" "$MINIO_AK" "$MINIO_SK" --api S3v4 &>/dev/null

# BUCKET_PATH 末尾必须有 /
BUCKET_PATH="$MC_ALIAS/$MINIO_BUCKET/$MINIO_PREFIX"
[[ "$BUCKET_PATH" == */ ]] || BUCKET_PATH="$BUCKET_PATH/"
```

## 读取版本号

在 push 的 Step 6 和 Step 11 中调用:

```bash
CURRENT_REMOTE_VERSION=0
CURRENT_REMOTE_CREATED_AT=""

MANIFEST_JSON=$(mc cat "${BUCKET_PATH}${WS_NAME}/manifest.json" 2>/dev/null || true)
if [[ -n "$MANIFEST_JSON" ]]; then
  CURRENT_REMOTE_VERSION=$(printf '%s' "$MANIFEST_JSON" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(d.get('version') or 0)
" 2>/dev/null || echo 0)
  CURRENT_REMOTE_CREATED_AT=$(printf '%s' "$MANIFEST_JSON" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(d.get('created_at') or '')
" 2>/dev/null || echo "")
fi
```

## Push

在 push 的 Step 12 中调用:

```bash
# 先删除云端已有的同名 workspace(覆盖语义)
mc rm --recursive --force "${BUCKET_PATH}${WS_NAME}/" 2>/dev/null || true

# 上传 staging 目录
mc cp --recursive "$STAGE_DIR/" "${BUCKET_PATH}${WS_NAME}/"
```

## Pull

在 pull 的 Step 1 中调用:

```bash
if ! mc ls "${BUCKET_PATH}${WS_NAME}/" &>/dev/null; then
  echo "❌ 工作空间 $WS_NAME 不存在"
  exit 1
fi
mc cp --recursive "${BUCKET_PATH}${WS_NAME}/" "$STAGE_DIR/"
```

## List

返回格式 `name|version|updated_at`,每行一条:

```bash
for WS in $(mc ls "$BUCKET_PATH" 2>/dev/null | awk '{print $NF}' | sed 's|/$||'); do
  [[ -n "$WS" ]] || continue

  MANIFEST_JSON="$(mc cat "${BUCKET_PATH}${WS}/manifest.json" 2>/dev/null || true)"
  VERSION="$(printf '%s' "$MANIFEST_JSON" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(d.get('version') or '-')
" 2>/dev/null || echo '-')"
  UPDATED_AT="$(printf '%s' "$MANIFEST_JSON" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(d.get('updated_at') or '-')
" 2>/dev/null || echo '-')"

  echo "$WS|$VERSION|$UPDATED_AT"
done
```

## Clean

```bash
if [[ "$WS_NAME" == "--all" ]]; then
  mc rm --recursive --force "$BUCKET_PATH"
else
  if ! mc ls "${BUCKET_PATH}${WS_NAME}/" &>/dev/null; then
    echo "nothing to clean: $WS_NAME"
    exit 0
  fi
  mc rm --recursive --force "${BUCKET_PATH}${WS_NAME}/"
fi
```
