# GitLab 后端实现

接口规范见 `references/backend-interface.md`。

## 配置

```json
"backend": "gitlab",
"gitlab": {
  "host": "gitlab.com",
  "token": "<your-personal-access-token>",
  "project_path": "<namespace>/<repo-name>",
  "branch": "main",
  "protocol": "https"
}
```

**仓库必须已存在**，skill 不会自动创建。

## 读取配置

token 通过 `http.extraheader` 传递，不写入远端 URL，避免 token 持久化到 `.git/config`。

```bash
GITLAB_HOST=$(jq -r '.gitlab.host // ""' "$CONFIG")
GITLAB_TOKEN=$(jq -r '.gitlab.token // ""' "$CONFIG")
GITLAB_PROJECT_PATH=$(jq -r '.gitlab.project_path // ""' "$CONFIG")
GITLAB_BRANCH=$(jq -r '.gitlab.branch // "main"' "$CONFIG")
CACHE_DIR="${CACHE_DIR:-<当前 CLI 状态目录>/workspace-cache}"
```

## 准备本地 clone（push/pull/list/clean 均需要）

```bash
LOCAL_REPO="$CACHE_DIR/gitlab/$(echo "$GITLAB_PROJECT_PATH" | sed 's|/|_|g')"

if [[ ! -d "$LOCAL_REPO/.git" ]]; then
  mkdir -p "$(dirname "$LOCAL_REPO")"
  no_proxy="$GITLAB_HOST" \
  git -c http.extraheader="Authorization: Bearer ${GITLAB_TOKEN}" \
      clone "https://${GITLAB_HOST}/${GITLAB_PROJECT_PATH}.git" "$LOCAL_REPO" \
    || { echo "GitLab clone 失败，请检查 token 和仓库路径"; exit 1; }
else
  (cd "$LOCAL_REPO" && \
    no_proxy="$GITLAB_HOST" \
    git -c http.extraheader="Authorization: Bearer ${GITLAB_TOKEN}" \
        pull --ff-only) \
    || { echo "GitLab pull 失败"; exit 1; }
fi
```

clone/pull 失败直接报错退出，不尝试创建仓库。

## read_version

在 push 的基线读取（Step 5）和并发校验（Step 10）时调用：

```bash
WS_DIR="$LOCAL_REPO/$WS_NAME"
CURRENT_REMOTE_VERSION=0
CURRENT_REMOTE_CREATED_AT=""

if [[ -f "$WS_DIR/manifest.json" ]]; then
  CURRENT_REMOTE_VERSION=$(jq -r '.version // 0' "$WS_DIR/manifest.json" 2>/dev/null || echo 0)
  CURRENT_REMOTE_CREATED_AT=$(jq -r '.created_at // ""' "$WS_DIR/manifest.json" 2>/dev/null || echo "")
fi
```

## Push

在 push 的上传阶段（Step 11）调用（此时 STAGE_DIR 已准备好，NEXT_VERSION 已确定）：

```bash
WS_DIR="$LOCAL_REPO/$WS_NAME"
[[ "$WS_DIR" == "$LOCAL_REPO/"* ]] || { echo "非法 workspace 路径"; exit 1; }
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
  no_proxy="$GITLAB_HOST" \
  git -c http.extraheader="Authorization: Bearer ${GITLAB_TOKEN}" \
      push origin "$GITLAB_BRANCH"
)
```

## Pull

在 pull 的 Step 3 中调用（下载到 STAGE_DIR）：

```bash
# LOCAL_REPO 已通过"准备本地 clone"更新至最新
WS_DIR="$LOCAL_REPO/$WS_NAME"
[[ -d "$WS_DIR" ]] || { echo "工作空间 $WS_NAME 不存在"; exit 1; }
cp -r "$WS_DIR"/* "$STAGE_DIR/"
```

## List

返回格式 `name|version|updated_at`，每行一条：

```bash
(cd "$LOCAL_REPO" && git checkout "$GITLAB_BRANCH" 2>/dev/null || true)

for WS_ENTRY in "$LOCAL_REPO"/*/; do
  WS="${WS_ENTRY%/}"
  WS="${WS##*/}"
  [[ "$WS" == ".git" ]] && continue
  MANIFEST="$LOCAL_REPO/$WS/manifest.json"
  [[ -f "$MANIFEST" ]] || continue

  VERSION=$(jq -r '.version // "-"' "$MANIFEST" 2>/dev/null || echo "-")
  UPDATED_AT=$(jq -r '.updated_at // "-"' "$MANIFEST" 2>/dev/null || echo "-")

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
  [[ "$WS_DIR" == "$LOCAL_REPO/"* ]] || { echo "非法路径"; exit 1; }
  [[ -d "$WS_DIR" ]] || { echo "nothing to clean: $WS_NAME"; exit 0; }
  rm -rf -- "$WS_DIR"
fi

(
  cd "$LOCAL_REPO"
  git add -A
  git -c user.email="workspace-sync@local" -c user.name="workspace-sync" \
      commit -m "workspace: clean ${WS_NAME} from $(hostname)" \
    || echo "nothing to commit"
  no_proxy="$GITLAB_HOST" \
  git -c http.extraheader="Authorization: Bearer ${GITLAB_TOKEN}" \
      push origin "$GITLAB_BRANCH"
)
```
