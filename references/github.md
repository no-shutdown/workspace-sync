# GitHub 后端实现

基于本地 clone + git push 实现，与 GitLab 后端逻辑一致，仅鉴权方式不同。

接口规范见 `references/backend-interface.md`。

## 配置

```json
"backend": "github",
"github": {
  "token": "ghp_xxxxxxxxxxxx",
  "repo": "your-username/claude-workspaces",
  "branch": "main"
}
```

token 需要 `repo` scope（私有仓库）或 `public_repo` scope（公开仓库）。
**仓库必须已存在**，skill 不会自动创建。

## 读取配置

```bash
GITHUB_TOKEN=$(jq -r '.github.token // ""' "$CONFIG")
GITHUB_REPO=$(jq -r '.github.repo // ""' "$CONFIG")
GITHUB_BRANCH=$(jq -r '.github.branch // "main"' "$CONFIG")
CACHE_DIR="${CACHE_DIR:-<当前 CLI 状态目录>/workspace-cache}"
```

## connect（含仓库验证）

```bash
RESULT=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  "https://api.github.com/repos/${GITHUB_REPO}")

if [[ "$RESULT" != "200" ]]; then
  echo "GitHub 仓库验证失败 (HTTP $RESULT)"
  [[ "$RESULT" == "401" ]] && echo "   token 无效或已过期"
  [[ "$RESULT" == "404" ]] && echo "   仓库不存在或无权限: $GITHUB_REPO"
  exit 1
fi
echo "GitHub 仓库验证通过"
```

## 准备本地 clone（push/pull/list/clean 均需要）

token 通过 `http.extraheader` 传递，不写入远端 URL，避免 token 持久化到 `.git/config`。

```bash
LOCAL_REPO="$CACHE_DIR/github/$(echo "$GITHUB_REPO" | sed 's|/|_|g')"

if [[ ! -d "$LOCAL_REPO/.git" ]]; then
  mkdir -p "$(dirname "$LOCAL_REPO")"
  git -c http.extraheader="Authorization: Bearer ${GITHUB_TOKEN}" \
      clone "https://github.com/${GITHUB_REPO}.git" "$LOCAL_REPO" \
    || { echo "GitHub clone 失败，请检查 token 和仓库路径"; exit 1; }
else
  (cd "$LOCAL_REPO" && \
    git -c http.extraheader="Authorization: Bearer ${GITHUB_TOKEN}" \
        pull --ff-only) \
    || { echo "GitHub pull 失败"; exit 1; }
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

## push

在 push 的上传阶段（Step 11）调用（此时 STAGE_DIR 已准备好，NEXT_VERSION 已确定）：

```bash
WS_DIR="$LOCAL_REPO/$WS_NAME"
[[ "$WS_DIR" == "$LOCAL_REPO/"* ]] || { echo "非法 workspace 路径"; exit 1; }
rm -rf -- "$WS_DIR"
mkdir -p "$WS_DIR"
cp -r "$STAGE_DIR"/* "$WS_DIR/"

(
  cd "$LOCAL_REPO"
  git checkout "$GITHUB_BRANCH" 2>/dev/null || git checkout -b "$GITHUB_BRANCH"
  git add "$WS_NAME"
  git -c user.email="workspace-sync@local" -c user.name="workspace-sync" \
      commit -m "workspace: update $WS_NAME v${NEXT_VERSION} from $(hostname)" \
    || echo "nothing to commit"
  git -c http.extraheader="Authorization: Bearer ${GITHUB_TOKEN}" \
      push origin "$GITHUB_BRANCH"
)
```

## pull

```bash
WS_DIR="$LOCAL_REPO/$WS_NAME"
[[ -d "$WS_DIR" ]] || { echo "工作空间 $WS_NAME 不存在"; exit 1; }
cp -r "$WS_DIR"/* "$STAGE_DIR/"
```

## list

```bash
(cd "$LOCAL_REPO" && git checkout "$GITHUB_BRANCH" 2>/dev/null || true)

for WS_ENTRY in "$LOCAL_REPO"/*/; do
  WS="${WS_ENTRY%/}"; WS="${WS##*/}"
  [[ "$WS" == ".git" ]] && continue
  MANIFEST="$LOCAL_REPO/$WS/manifest.json"
  [[ -f "$MANIFEST" ]] || continue

  VERSION=$(jq -r '.version // "-"' "$MANIFEST" 2>/dev/null || echo "-")
  UPDATED_AT=$(jq -r '.updated_at // "-"' "$MANIFEST" 2>/dev/null || echo "-")

  echo "$WS|$VERSION|$UPDATED_AT"
done
```

## clean

```bash
(cd "$LOCAL_REPO" && git checkout "$GITHUB_BRANCH" 2>/dev/null || true)

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
  git -c http.extraheader="Authorization: Bearer ${GITHUB_TOKEN}" \
      push origin "$GITHUB_BRANCH"
)
```
