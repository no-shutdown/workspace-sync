#!/usr/bin/env bash
# 删除远端 workspace 并清理本地缓存
set -euo pipefail

WS_NAME="${1:-}"
[[ -n "$WS_NAME" ]] || { echo "Usage: ws-clean.sh <ws_name|--all>"; exit 1; }

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ws-backend.sh
source "$SCRIPT_DIR/ws-backend.sh"

ws_backend_init

git_commit_push() {
  local repo="$1"
  local branch="$2"
  local message="$3"
  local no_proxy_host="${4:-}"

  if [[ -n "$no_proxy_host" ]]; then
    (
      cd "$repo"
      no_proxy="$no_proxy_host" git add -A
      git -c user.email="workspace-sync@local" -c user.name="workspace-sync" \
        commit -m "$message" 2>/dev/null || echo "nothing to commit"
      no_proxy="$no_proxy_host" git push origin "$branch"
    )
  else
    (
      cd "$repo"
      git add -A
      git -c user.email="workspace-sync@local" -c user.name="workspace-sync" \
        commit -m "$message" 2>/dev/null || echo "nothing to commit"
      git push origin "$branch"
    )
  fi
}

clean_local_cache() {
  local stage_root="$WS_CACHE_DIR/staging"
  local stage_dir

  if [[ "$WS_NAME" == "--all" ]]; then
    [[ -d "$stage_root" ]] && rm -rf -- "$stage_root"/*
    return 0
  fi

  stage_dir="$stage_root/$WS_NAME"
  [[ "$stage_dir" == "$stage_root/"* ]] || {
    echo "illegal staging path" >&2
    exit 1
  }
  [[ -d "$stage_dir" ]] && rm -rf -- "$stage_dir"
}

clean_remote_dir() {
  local root="$1"
  local ws_entry
  local ws
  local ws_dir

  if [[ "$WS_NAME" == "--all" ]]; then
    for ws_entry in "$root"/*/; do
      [[ -d "$ws_entry" ]] || continue
      ws="${ws_entry%/}"
      ws="${ws##*/}"
      [[ "$ws" == ".git" ]] && continue
      [[ -f "$root/$ws/manifest.json" ]] || continue
      rm -rf -- "$root/$ws"
    done
    return 0
  fi

  ws_dir="$root/$WS_NAME"
  [[ "$ws_dir" == "$root/"* ]] || {
    echo "illegal workspace path" >&2
    exit 1
  }
  if [[ ! -d "$ws_dir" ]]; then
    echo "nothing to clean: $WS_NAME"
    return 0
  fi
  rm -rf -- "$ws_dir"
}

case "$WS_BACKEND" in
  local)
    ws_init_local
    clean_remote_dir "$WS_LOCAL_PATH"
    ;;

  github)
    ws_ensure_github
    clean_remote_dir "$WS_GITHUB_LOCAL_REPO"
    git_commit_push \
      "$WS_GITHUB_LOCAL_REPO" \
      "$WS_GITHUB_BRANCH" \
      "workspace: clean ${WS_NAME} from $(hostname)"
    ;;

  gitlab)
    ws_ensure_gitlab
    clean_remote_dir "$WS_GITLAB_LOCAL_REPO"
    git_commit_push \
      "$WS_GITLAB_LOCAL_REPO" \
      "$WS_GITLAB_BRANCH" \
      "workspace: clean ${WS_NAME} from $(hostname)" \
      "$WS_GITLAB_HOST"
    ;;

  minio)
    ws_init_minio
    if [[ "$WS_NAME" == "--all" ]]; then
      mc rm --recursive --force "$WS_MC_BASE" 2>/dev/null || echo "nothing to clean"
    else
      ws_path="${WS_MC_BASE}${WS_NAME}/"
      mc ls "$ws_path" &>/dev/null || {
        echo "nothing to clean: $WS_NAME"
        exit 0
      }
      mc rm --recursive --force "$ws_path"
    fi
    ;;

  *)
    echo "unknown backend: $WS_BACKEND" >&2
    exit 1
    ;;
esac

clean_local_cache
echo "已清理 workspace: $WS_NAME"
