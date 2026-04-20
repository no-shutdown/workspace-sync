# GitLab 后端实现

## 读取配置

```bash
GITLAB_HOST=$(python3 -c "import json; d=json.load(open('$CONFIG')); print((d.get('gitlab') or {}).get('host') or '')" 2>/dev/null)
GITLAB_TOKEN=$(python3 -c "import json; d=json.load(open('$CONFIG')); print((d.get('gitlab') or {}).get('token') or '')" 2>/dev/null)
GITLAB_PROJECT_PATH=$(python3 -c "import json; d=json.load(open('$CONFIG')); print((d.get('gitlab') or {}).get('project_path') or '')" 2>/dev/null)
GITLAB_BRANCH=$(python3 -c "import json; d=json.load(open('$CONFIG')); print((d.get('gitlab') or {}).get('branch') or 'main')" 2>/dev/null)
CACHE_DIR="${CACHE_DIR:-$HOME/.claude/workspace-cache}"
```

## 准备本地 clone(push/pull/list/clean 均需要)

```bash
LOCAL_REPO="$CACHE_DIR/gitlab/$(echo "$GITLAB_PROJECT_PATH" | sed 's|/|_|g')"

if [[ ! -d "$LOCAL_REPO/.git" ]]; then
  mkdir -p "$(dirname "$LOCAL_REPO")"
  no_proxy="$GITLAB_HOST" git clone \
    "https://oauth2:${GITLAB_TOKEN}@${GITLAB_HOST}/${GITLAB_PROJECT_PATH}.git" \
    "$LOCAL_REPO" \
    || { echo "❌ GitLab clone 失败,请检查 token 和仓库路径"; exit 1; }
else
  (cd "$LOCAL_REPO" && no_proxy="$GITLAB_HOST" git pull --ff-only) \
    || { echo "❌ GitLab pull 失败"; exit 1; }
fi
```

clone/pull 失败直接报错退出,不尝试创建仓库。

## 读取版本号

在 push 的 Step 6 和 Step 11 中调用:

```bash
WS_DIR="$LOCAL_REPO/$WS_NAME"
CURRENT_REMOTE_VERSION=0
CURRENT_REMOTE_CREATED_AT=""

if [[ -f "$WS_DIR/manifest.json" ]]; then
  CURRENT_REMOTE_VERSION=$(python3 -c "
import json
d = json.load(open('$WS_DIR/manifest.json'))
print(d.get('version') or 0)
" 2>/dev/null || echo 0)
  CURRENT_REMOTE_CREATED_AT=$(python3 -c "
import json
d = json.load(open('$WS_DIR/manifest.json'))
print(d.get('created_at') or '')
" 2>/dev/null || echo "")
fi
```

## Push

在 push 的 Step 12 中调用(此时 STAGE_DIR 已准备好,NEXT_VERSION 已确定):

```bash
WS_DIR="$LOCAL_REPO/$WS_NAME"
[[ "$WS_DIR" == "$LOCAL_REPO/"* ]] || { echo "❌ 非法 workspace 路径"; exit 1; }
rm -rf -- "$WS_DIR"
mkdir -p "$WS_DIR"
cp -r "$STAGE_DIR"/* "$WS_DIR/"

(
  cd "$LOCAL_REPO"
  git checkout "$GITLAB_BRANCH" 2>/dev/null || git checkout -b "$GITLAB_BRANCH"
  git add "$WS_NAME"
  git -c user.email="workspace-sync@local" -c user.name="workspace-sync" \
      commit -m "workspace: update $WS_NAME v${NEXT_VERSION} from $(hostname)" \
    || echo "nothing to commit"
  no_proxy="$GITLAB_HOST" git push origin "$GITLAB_BRANCH"
)
```

## Pull

在 pull 的 Step 1 中调用(下载到 STAGE_DIR):

```bash
# LOCAL_REPO 已通过"准备本地 clone"更新至最新
WS_DIR="$LOCAL_REPO/$WS_NAME"
[[ -d "$WS_DIR" ]] || { echo "❌ 工作空间 $WS_NAME 不存在"; exit 1; }
cp -r "$WS_DIR"/* "$STAGE_DIR/"
```

## List

返回格式 `name|version|updated_at`,每行一条:

```bash
(cd "$LOCAL_REPO" && git checkout "$GITLAB_BRANCH" 2>/dev/null || true)

for WS_ENTRY in "$LOCAL_REPO"/*/; do
  WS="${WS_ENTRY%/}"
  WS="${WS##*/}"
  [[ "$WS" == ".git" ]] && continue
  [[ -f "$LOCAL_REPO/$WS/manifest.json" ]] || continue

  VERSION=$(python3 -c "
import json
d = json.load(open('$LOCAL_REPO/$WS/manifest.json'))
print(d.get('version') or '-')
" 2>/dev/null || echo "-")
  UPDATED_AT=$(python3 -c "
import json
d = json.load(open('$LOCAL_REPO/$WS/manifest.json'))
print(d.get('updated_at') or '-')
" 2>/dev/null || echo "-")

  echo "$WS|$VERSION|$UPDATED_AT"
done
```

## Clean

```bash
(cd "$LOCAL_REPO" && git checkout "$GITLAB_BRANCH" 2>/dev/null || true)

if [[ "$WS_NAME" == "--all" ]]; then
  for WS_ENTRY in "$LOCAL_REPO"/*/; do
    WS="${WS_ENTRY%/}"; WS="${WS##*/}"
    [[ "$WS" == ".git" ]] && continue
    [[ -f "$LOCAL_REPO/$WS/manifest.json" ]] || continue
    rm -rf -- "$LOCAL_REPO/$WS"
  done
else
  WS_DIR="$LOCAL_REPO/$WS_NAME"
  [[ "$WS_DIR" == "$LOCAL_REPO/"* ]] || { echo "❌ 非法路径"; exit 1; }
  [[ -d "$WS_DIR" ]] || { echo "nothing to clean: $WS_NAME"; exit 0; }
  rm -rf -- "$WS_DIR"
fi

(
  cd "$LOCAL_REPO"
  git add -A
  git -c user.email="workspace-sync@local" -c user.name="workspace-sync" \
      commit -m "workspace: clean ${WS_NAME} from $(hostname)" \
    || echo "nothing to commit"
  no_proxy="$GITLAB_HOST" git push origin "$GITLAB_BRANCH"
)
```
