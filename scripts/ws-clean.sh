#!/usr/bin/env bash
# 删除远端 workspace 并清理本地缓存
# Usage: ws-clean.sh <ws_name|--all>
set -euo pipefail

WS_NAME="${1:-}"
[[ -n "$WS_NAME" ]] || { echo "Usage: ws-clean.sh <ws_name|--all>"; exit 1; }

SKILL_DIR="$HOME/.claude/skills/workspace-sync"
CONFIG="$SKILL_DIR/config.json"

[[ -f "$CONFIG" ]] || { echo "❌ 未找到配置文件: $CONFIG"; exit 1; }

_py() { python3 -c "$1" 2>/dev/null || echo ""; }

BACKEND=$(_py "import json; d=json.load(open('$CONFIG')); print(d.get('backend') or '')")
[[ -n "$BACKEND" ]] || { echo "❌ 未配置 backend"; exit 1; }

CACHE_DIR=$(_py "import json; d=json.load(open('$CONFIG')); print(d.get('cache_dir') or '~/.claude/workspace-cache')")
CACHE_DIR="${CACHE_DIR/#\~/$HOME}"

_git_commit_push() {
  local repo="$1" branch="$2" msg="$3"
  cd "$repo"
  git add -A
  git -c user.email="workspace-sync@local" -c user.name="workspace-sync" \
      commit -m "$msg" 2>/dev/null || echo "nothing to commit"
  git push origin "$branch"
}

_clean_local_cache() {
  if [[ "$WS_NAME" == "--all" ]]; then
    local stage_root="$CACHE_DIR/staging"
    [[ -d "$stage_root" ]] && rm -rf -- "$stage_root"/*
  else
    local stage_dir="$CACHE_DIR/staging/$WS_NAME"
    [[ "$stage_dir" == "$CACHE_DIR/staging/"* ]] || { echo "❌ 非法路径"; exit 1; }
    [[ -d "$stage_dir" ]] && rm -rf -- "$stage_dir"
  fi
}

_clean_remote_dir() {
  local root="$1"
  if [[ "$WS_NAME" == "--all" ]]; then
    for WS_ENTRY in "$root"/*/; do
      local WS="${WS_ENTRY%/}"; WS="${WS##*/}"
      [[ "$WS" == ".git" ]] && continue
      [[ -f "$root/$WS/manifest.json" ]] || continue
      rm -rf -- "$root/$WS"
    done
  else
    local ws_dir="$root/$WS_NAME"
    [[ "$ws_dir" == "$root/"* ]] || { echo "❌ 非法路径"; exit 1; }
    if [[ ! -d "$ws_dir" ]]; then
      echo "nothing to clean: $WS_NAME"
      return 0
    fi
    rm -rf -- "$ws_dir"
  fi
}

case "$BACKEND" in

  local)
    LOCAL_PATH=$(_py "import json; d=json.load(open('$CONFIG')); print((d.get('local') or {}).get('path') or '')")
    LOCAL_PATH="${LOCAL_PATH/#\~/$HOME}"
    [[ -d "$LOCAL_PATH" ]] || { echo "❌ local.path 不存在: $LOCAL_PATH"; exit 1; }
    _clean_remote_dir "$LOCAL_PATH"
    ;;

  github)
    GITHUB_TOKEN=$(_py "import json; d=json.load(open('$CONFIG')); print((d.get('github') or {}).get('token') or '')")
    GITHUB_REPO=$(_py "import json; d=json.load(open('$CONFIG')); print((d.get('github') or {}).get('repo') or '')")
    GITHUB_BRANCH=$(_py "import json; d=json.load(open('$CONFIG')); print((d.get('github') or {}).get('branch') or 'main')")
    LOCAL_REPO="$CACHE_DIR/github/$(echo "$GITHUB_REPO" | sed 's|/|_|g')"

    [[ -d "$LOCAL_REPO/.git" ]] || { echo "❌ 本地缓存不存在，请先执行 list"; exit 1; }
    (cd "$LOCAL_REPO" && git checkout "$GITHUB_BRANCH" 2>/dev/null || true)
    _clean_remote_dir "$LOCAL_REPO"
    _git_commit_push "$LOCAL_REPO" "$GITHUB_BRANCH" "workspace: clean ${WS_NAME} from $(hostname)"
    ;;

  gitlab)
    GITLAB_HOST=$(_py "import json; d=json.load(open('$CONFIG')); print((d.get('gitlab') or {}).get('host') or '')")
    GITLAB_TOKEN=$(_py "import json; d=json.load(open('$CONFIG')); print((d.get('gitlab') or {}).get('token') or '')")
    GITLAB_PROJECT=$(_py "import json; d=json.load(open('$CONFIG')); print((d.get('gitlab') or {}).get('project_path') or '')")
    GITLAB_BRANCH=$(_py "import json; d=json.load(open('$CONFIG')); print((d.get('gitlab') or {}).get('branch') or 'main')")
    LOCAL_REPO="$CACHE_DIR/gitlab/$(echo "$GITLAB_PROJECT" | sed 's|/|_|g')"

    [[ -d "$LOCAL_REPO/.git" ]] || { echo "❌ 本地缓存不存在，请先执行 list"; exit 1; }
    (cd "$LOCAL_REPO" && no_proxy="$GITLAB_HOST" git checkout "$GITLAB_BRANCH" 2>/dev/null || true)
    _clean_remote_dir "$LOCAL_REPO"
    (cd "$LOCAL_REPO" && no_proxy="$GITLAB_HOST" git add -A && \
      git -c user.email="workspace-sync@local" -c user.name="workspace-sync" \
          commit -m "workspace: clean ${WS_NAME} from $(hostname)" 2>/dev/null || echo "nothing to commit" && \
      no_proxy="$GITLAB_HOST" git push origin "$GITLAB_BRANCH")
    ;;

  minio)
    MC_ALIAS=$(_py "import json; d=json.load(open('$CONFIG')); print((d.get('minio') or {}).get('mc_alias') or 'workspace-sync')")
    MINIO_BUCKET=$(_py "import json; d=json.load(open('$CONFIG')); print((d.get('minio') or {}).get('bucket') or '')")
    MINIO_PREFIX=$(_py "import json; d=json.load(open('$CONFIG')); print((d.get('minio') or {}).get('prefix') or 'workspaces/')")
    command -v mc &>/dev/null || { echo "❌ mc 未安装"; exit 1; }
    BUCKET_PATH="$MC_ALIAS/$MINIO_BUCKET/$MINIO_PREFIX"

    if [[ "$WS_NAME" == "--all" ]]; then
      mc rm --recursive --force "$BUCKET_PATH" 2>/dev/null || echo "nothing to clean"
    else
      WS_PATH="${BUCKET_PATH}${WS_NAME}/"
      mc ls "$WS_PATH" &>/dev/null \
        || { echo "nothing to clean: $WS_NAME"; exit 0; }
      mc rm --recursive --force "$WS_PATH"
    fi
    ;;

  *)
    echo "❌ 未知 backend: $BACKEND"
    exit 1
    ;;
esac

# 清理本地 staging 缓存
_clean_local_cache

echo "✓ 已清理 workspace: $WS_NAME"
