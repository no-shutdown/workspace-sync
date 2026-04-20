#!/usr/bin/env bash
# 列出所有 workspace，输出 name|version|updated_at（每行一条）
set -euo pipefail

SKILL_DIR="$HOME/.claude/skills/workspace-sync"
CONFIG="$SKILL_DIR/config.json"

[[ -f "$CONFIG" ]] || { echo "❌ 未找到配置文件: $CONFIG"; exit 1; }

_py() { python3 -c "$1" 2>/dev/null || echo ""; }

BACKEND=$(_py "import json; d=json.load(open('$CONFIG')); print(d.get('backend') or '')")
[[ -n "$BACKEND" ]] || { echo "❌ 未配置 backend，请先运行 /workspace-sync connect"; exit 1; }

CACHE_DIR=$(_py "import json; d=json.load(open('$CONFIG')); print(d.get('cache_dir') or '~/.claude/workspace-cache')")
CACHE_DIR="${CACHE_DIR/#\~/$HOME}"

_list_dir() {
  local dir="$1"
  for WS_ENTRY in "$dir"/*/; do
    [[ -d "$WS_ENTRY" ]] || continue
    local WS="${WS_ENTRY%/}"; WS="${WS##*/}"
    [[ "$WS" == ".git" ]] && continue
    local MANIFEST="$dir/$WS/manifest.json"
    [[ -f "$MANIFEST" ]] || continue
    local VERSION UPDATED_AT
    VERSION=$(_py "import json; d=json.load(open('$MANIFEST')); print(d.get('version') or '-')")
    UPDATED_AT=$(_py "import json; d=json.load(open('$MANIFEST')); print(d.get('updated_at') or '-')")
    echo "$WS|$VERSION|$UPDATED_AT"
  done
}

case "$BACKEND" in

  local)
    LOCAL_PATH=$(_py "import json; d=json.load(open('$CONFIG')); print((d.get('local') or {}).get('path') or '')")
    LOCAL_PATH="${LOCAL_PATH/#\~/$HOME}"
    [[ -d "$LOCAL_PATH" ]] || { echo "❌ local.path 不存在: $LOCAL_PATH"; exit 1; }
    _list_dir "$LOCAL_PATH"
    ;;

  github)
    GITHUB_TOKEN=$(_py "import json; d=json.load(open('$CONFIG')); print((d.get('github') or {}).get('token') or '')")
    GITHUB_REPO=$(_py "import json; d=json.load(open('$CONFIG')); print((d.get('github') or {}).get('repo') or '')")
    GITHUB_BRANCH=$(_py "import json; d=json.load(open('$CONFIG')); print((d.get('github') or {}).get('branch') or 'main')")
    [[ -n "$GITHUB_TOKEN" && -n "$GITHUB_REPO" ]] || { echo "❌ github token/repo 未配置"; exit 1; }
    LOCAL_REPO="$CACHE_DIR/github/$(echo "$GITHUB_REPO" | sed 's|/|_|g')"

    if [[ ! -d "$LOCAL_REPO/.git" ]]; then
      mkdir -p "$(dirname "$LOCAL_REPO")"
      git clone "https://${GITHUB_TOKEN}@github.com/${GITHUB_REPO}.git" "$LOCAL_REPO" \
        || { echo "❌ GitHub clone 失败，请检查 token 和仓库路径"; exit 1; }
    else
      (cd "$LOCAL_REPO" && git pull --ff-only 2>/dev/null) || true
    fi
    (cd "$LOCAL_REPO" && git checkout "$GITHUB_BRANCH" 2>/dev/null || true)
    _list_dir "$LOCAL_REPO"
    ;;

  gitlab)
    GITLAB_HOST=$(_py "import json; d=json.load(open('$CONFIG')); print((d.get('gitlab') or {}).get('host') or '')")
    GITLAB_TOKEN=$(_py "import json; d=json.load(open('$CONFIG')); print((d.get('gitlab') or {}).get('token') or '')")
    GITLAB_PROJECT=$(_py "import json; d=json.load(open('$CONFIG')); print((d.get('gitlab') or {}).get('project_path') or '')")
    GITLAB_BRANCH=$(_py "import json; d=json.load(open('$CONFIG')); print((d.get('gitlab') or {}).get('branch') or 'main')")
    [[ -n "$GITLAB_HOST" && -n "$GITLAB_TOKEN" && -n "$GITLAB_PROJECT" ]] \
      || { echo "❌ gitlab host/token/project_path 未配置"; exit 1; }
    LOCAL_REPO="$CACHE_DIR/gitlab/$(echo "$GITLAB_PROJECT" | sed 's|/|_|g')"

    if [[ ! -d "$LOCAL_REPO/.git" ]]; then
      mkdir -p "$(dirname "$LOCAL_REPO")"
      no_proxy="$GITLAB_HOST" git clone \
        "https://oauth2:${GITLAB_TOKEN}@${GITLAB_HOST}/${GITLAB_PROJECT}.git" \
        "$LOCAL_REPO" || { echo "❌ GitLab clone 失败"; exit 1; }
    else
      (cd "$LOCAL_REPO" && no_proxy="$GITLAB_HOST" git pull --ff-only 2>/dev/null) || true
    fi
    (cd "$LOCAL_REPO" && git checkout "$GITLAB_BRANCH" 2>/dev/null || true)
    _list_dir "$LOCAL_REPO"
    ;;

  minio)
    MC_ALIAS=$(_py "import json; d=json.load(open('$CONFIG')); print((d.get('minio') or {}).get('mc_alias') or 'workspace-sync')")
    MINIO_BUCKET=$(_py "import json; d=json.load(open('$CONFIG')); print((d.get('minio') or {}).get('bucket') or '')")
    MINIO_PREFIX=$(_py "import json; d=json.load(open('$CONFIG')); print((d.get('minio') or {}).get('prefix') or 'workspaces/')")
    [[ -n "$MINIO_BUCKET" ]] || { echo "❌ minio bucket 未配置"; exit 1; }
    command -v mc &>/dev/null || { echo "❌ mc 未安装"; exit 1; }
    BUCKET_PATH="$MC_ALIAS/$MINIO_BUCKET/$MINIO_PREFIX"

    mc ls "$BUCKET_PATH" 2>/dev/null | awk '{print $NF}' | sed 's|/$||' | while read -r WS; do
      [[ -n "$WS" ]] || continue
      MANIFEST_TMP=$(mktemp)
      mc cp "${BUCKET_PATH}${WS}/manifest.json" "$MANIFEST_TMP" &>/dev/null \
        || { rm -f "$MANIFEST_TMP"; continue; }
      VERSION=$(_py "import json; d=json.load(open('$MANIFEST_TMP')); print(d.get('version') or '-')")
      UPDATED_AT=$(_py "import json; d=json.load(open('$MANIFEST_TMP')); print(d.get('updated_at') or '-')")
      rm -f "$MANIFEST_TMP"
      echo "$WS|$VERSION|$UPDATED_AT"
    done
    ;;

  *)
    echo "❌ 未知 backend: $BACKEND"
    exit 1
    ;;
esac
