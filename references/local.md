# Local 后端实现

最低门槛的 backend，把 workspace 存到本地目录。
配合 Dropbox、OneDrive、iCloud、坚果云等云盘文件夹使用，无需任何 API 配置即可实现跨设备同步。

接口规范见 `references/backend-interface.md`。

## 配置

```json
"backend": "local",
"local": {
  "path": "~/Dropbox/claude-workspaces"
}
```

`path` 必须是**已存在的目录**，skill 不会自动创建。

## connect

```bash
LOCAL_PATH=$(python3 -c "
import json
d = json.load(open('$CONFIG'))
print((d.get('local') or {}).get('path') or '')
" 2>/dev/null)
LOCAL_PATH="${LOCAL_PATH/#\~/$HOME}"

[[ -n "$LOCAL_PATH" ]] || { echo "❌ local.path 未配置"; exit 1; }
[[ -d "$LOCAL_PATH" ]] || {
  echo "❌ 目录不存在: $LOCAL_PATH"
  echo "   请先创建该目录，或将其指向云盘已同步的文件夹"
  exit 1
}
```

## read_version

```bash
MANIFEST="$LOCAL_PATH/$WS_NAME/manifest.json"
CURRENT_REMOTE_VERSION=0
CURRENT_REMOTE_CREATED_AT=""

if [[ -f "$MANIFEST" ]]; then
  CURRENT_REMOTE_VERSION=$(python3 -c "
import json
d = json.load(open('$MANIFEST'))
print(d.get('version') or 0)
" 2>/dev/null || echo 0)
  CURRENT_REMOTE_CREATED_AT=$(python3 -c "
import json
d = json.load(open('$MANIFEST'))
print(d.get('created_at') or '')
" 2>/dev/null || echo "")
fi
```

## push

```bash
WS_DIR="$LOCAL_PATH/$WS_NAME"
[[ "$WS_DIR" == "$LOCAL_PATH/"* ]] || { echo "❌ 非法 workspace 路径"; exit 1; }
rm -rf -- "$WS_DIR"
mkdir -p "$WS_DIR"
cp -r "$STAGE_DIR"/* "$WS_DIR/"
```

## pull

```bash
WS_DIR="$LOCAL_PATH/$WS_NAME"
[[ -d "$WS_DIR" ]] || { echo "❌ 工作空间 $WS_NAME 不存在"; exit 1; }
cp -r "$WS_DIR"/* "$STAGE_DIR/"
```

## list

```bash
for WS_ENTRY in "$LOCAL_PATH"/*/; do
  [[ -d "$WS_ENTRY" ]] || continue
  WS="${WS_ENTRY%/}"; WS="${WS##*/}"
  [[ -f "$LOCAL_PATH/$WS/manifest.json" ]] || continue

  VERSION=$(python3 -c "
import json
d = json.load(open('$LOCAL_PATH/$WS/manifest.json'))
print(d.get('version') or '-')
" 2>/dev/null || echo "-")
  UPDATED_AT=$(python3 -c "
import json
d = json.load(open('$LOCAL_PATH/$WS/manifest.json'))
print(d.get('updated_at') or '-')
" 2>/dev/null || echo "-")

  echo "$WS|$VERSION|$UPDATED_AT"
done
```

## clean

```bash
if [[ "$WS_NAME" == "--all" ]]; then
  for WS_ENTRY in "$LOCAL_PATH"/*/; do
    [[ -d "$WS_ENTRY" ]] || continue
    WS="${WS_ENTRY%/}"; WS="${WS##*/}"
    [[ -f "$LOCAL_PATH/$WS/manifest.json" ]] || continue
    rm -rf -- "$LOCAL_PATH/$WS"
  done
else
  WS_DIR="$LOCAL_PATH/$WS_NAME"
  [[ "$WS_DIR" == "$LOCAL_PATH/"* ]] || { echo "❌ 非法路径"; exit 1; }
  [[ -d "$WS_DIR" ]] || { echo "nothing to clean: $WS_NAME"; exit 0; }
  rm -rf -- "$WS_DIR"
fi
```
