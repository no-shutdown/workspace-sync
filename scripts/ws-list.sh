#!/usr/bin/env bash
# 列出所有 workspace，输出 name|version|updated_at（每行一条）
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ws-backend.sh
source "$SCRIPT_DIR/ws-backend.sh"

ws_backend_init

list_dir() {
  local dir="$1"
  local ws_entry
  local ws
  local manifest
  local version
  local updated_at

  for ws_entry in "$dir"/*/; do
    [[ -d "$ws_entry" ]] || continue
    ws="${ws_entry%/}"
    ws="${ws##*/}"
    [[ "$ws" == ".git" ]] && continue

    manifest="$dir/$ws/manifest.json"
    [[ -f "$manifest" ]] || continue

    version="$(ws_get_json_string "$manifest" "version")"
    updated_at="$(ws_get_json_string "$manifest" "updated_at")"
    [[ -n "$version" ]] || version="-"
    [[ -n "$updated_at" ]] || updated_at="-"
    printf '%s|%s|%s\n' "$ws" "$version" "$updated_at"
  done
}

case "$WS_BACKEND" in
  local)
    ws_init_local
    list_dir "$WS_LOCAL_PATH"
    ;;

  github)
    ws_ensure_github
    list_dir "$WS_GITHUB_LOCAL_REPO"
    ;;

  gitlab)
    ws_ensure_gitlab
    list_dir "$WS_GITLAB_LOCAL_REPO"
    ;;

  minio)
    ws_init_minio
    mc ls "$WS_MC_BASE" 2>/dev/null | awk '{print $NF}' | sed 's|/$||' | while read -r ws; do
      local_manifest="$(mktemp)"
      [[ -n "$ws" ]] || continue
      mc cp "${WS_MC_BASE}${ws}/manifest.json" "$local_manifest" &>/dev/null || {
        rm -f "$local_manifest"
        continue
      }
      version="$(ws_get_json_string "$local_manifest" "version")"
      updated_at="$(ws_get_json_string "$local_manifest" "updated_at")"
      rm -f "$local_manifest"
      [[ -n "$version" ]] || version="-"
      [[ -n "$updated_at" ]] || updated_at="-"
      printf '%s|%s|%s\n' "$ws" "$version" "$updated_at"
    done
    ;;

  *)
    echo "unknown backend: $WS_BACKEND" >&2
    exit 1
    ;;
esac
