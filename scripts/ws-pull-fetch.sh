#!/usr/bin/env bash
# ws-pull-fetch.sh <ws_name> [--force]
# 下载 workspace、自动匹配项目路径、git checkout、导入 skill states
# 退出码: 0=完成(含部分 skipped) 1=失败 3=有未解析的项目路径 4=本地比远端新(需用户确认)
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ws-backend.sh
source "$SCRIPT_DIR/ws-backend.sh"

WS_NAME="${1:-}"
FORCE_MODE=0
[[ "${2:-}" == "--force" ]] && FORCE_MODE=1
[[ -n "$WS_NAME" ]] || { echo '{"error":"ws_name is required"}'; exit 1; }

ws_backend_init

LOCAL_PATHS_FILE="$(ws_get_json_string "$WS_CONFIG" "local_paths_file")"
[[ -n "$LOCAL_PATHS_FILE" ]] || LOCAL_PATHS_FILE="~/.claude/skills/workspace-sync/local-paths.json"
LOCAL_PATHS_FILE="$(ws_expand_home "$LOCAL_PATHS_FILE")"

STAGE_ROOT="$WS_CACHE_DIR/staging"
STAGE_DIR="$STAGE_ROOT/$WS_NAME"
[[ "$STAGE_DIR" == "$STAGE_ROOT/"* ]] || { echo '{"error":"illegal staging path"}'; exit 1; }

# ── 版本比较工具函数 ──────────────────────────────────────────────

_get_version_from_file() {
  local manifest="$1"
  [[ -f "$manifest" ]] || { printf '0'; return; }
  python3 - "$manifest" <<'PYEOF'
import json, sys
try:
    with open(sys.argv[1], encoding='utf-8') as fh:
        v = json.load(fh).get('version', 0)
    print(int(v) if isinstance(v, (int, float)) else 0)
except Exception:
    print(0)
PYEOF
}

_get_version_from_json() {
  local json_str="$1"
  [[ -n "$json_str" ]] || { printf '0'; return; }
  printf '%s' "$json_str" | python3 -c "
import json, sys
try:
    v = json.load(sys.stdin).get('version', 0)
    print(int(v) if isinstance(v, (int, float)) else 0)
except Exception:
    print(0)
" 2>/dev/null || printf '0'
}

# ── 各后端：计算本地路径 + 轻量获取远端版本 ──────────────────────

LOCAL_MANIFEST=""
REMOTE_MANIFEST_JSON=""
REMOTE_FOUND=0
LOCAL_VERSION=0
REMOTE_VERSION=0
SOURCE=""   # "remote" | "local_only"

case "$WS_BACKEND" in
  local)
    ws_init_local
    LOCAL_MANIFEST="$WS_LOCAL_PATH/$WS_NAME/manifest.json"
    LOCAL_VERSION=$(_get_version_from_file "$LOCAL_MANIFEST")
    # local 后端：远端即本地，无需网络
    REMOTE_MANIFEST_JSON="$(cat "$LOCAL_MANIFEST" 2>/dev/null || true)"
    [[ -n "$REMOTE_MANIFEST_JSON" ]] && REMOTE_FOUND=1
    REMOTE_VERSION=$LOCAL_VERSION
    ;;

  github)
    ws_compute_github_path
    LOCAL_MANIFEST="$WS_GITHUB_LOCAL_REPO/$WS_NAME/manifest.json"
    LOCAL_VERSION=$(_get_version_from_file "$LOCAL_MANIFEST")
    REMOTE_MANIFEST_JSON="$(ws_github_fetch_manifest "$WS_NAME")" || true
    if [[ -n "$REMOTE_MANIFEST_JSON" ]]; then
      REMOTE_FOUND=1
      REMOTE_VERSION=$(_get_version_from_json "$REMOTE_MANIFEST_JSON")
    fi
    ;;

  gitlab)
    ws_compute_gitlab_path
    LOCAL_MANIFEST="$WS_GITLAB_LOCAL_REPO/$WS_NAME/manifest.json"
    LOCAL_VERSION=$(_get_version_from_file "$LOCAL_MANIFEST")
    REMOTE_MANIFEST_JSON="$(ws_gitlab_fetch_manifest "$WS_NAME")" || true
    if [[ -n "$REMOTE_MANIFEST_JSON" ]]; then
      REMOTE_FOUND=1
      REMOTE_VERSION=$(_get_version_from_json "$REMOTE_MANIFEST_JSON")
    fi
    ;;

  minio)
    ws_init_minio
    LOCAL_VERSION=0   # MinIO 无本地缓存
    TMP_MANIFEST="$(mktemp)"
    if no_proxy="" mc cp "${WS_MC_BASE}${WS_NAME}/manifest.json" "$TMP_MANIFEST" &>/dev/null; then
      REMOTE_MANIFEST_JSON="$(cat "$TMP_MANIFEST")"
      REMOTE_FOUND=1
      REMOTE_VERSION=$(_get_version_from_json "$REMOTE_MANIFEST_JSON")
    fi
    rm -f "$TMP_MANIFEST"
    ;;
esac

# ── 版本决策 ──────────────────────────────────────────────────────

if [[ $REMOTE_FOUND -eq 0 && $LOCAL_VERSION -eq 0 ]]; then
  printf '{"error":"workspace %s not found locally or remotely"}\n' "$(ws_json_escape "$WS_NAME")"
  exit 1
fi

if [[ $REMOTE_FOUND -eq 0 ]]; then
  # 仅本地存在 → 直接从本地缓存恢复，不做 git pull
  SOURCE="local_only"
elif [[ $FORCE_MODE -eq 0 && $LOCAL_VERSION -gt $REMOTE_VERSION ]]; then
  # 本地比远端新 → 返回冲突信息，由 Claude 询问用户
  printf '{"conflict":true,"local_version":%d,"remote_version":%d,"workspace":"%s"}\n' \
    "$LOCAL_VERSION" "$REMOTE_VERSION" "$(ws_json_escape "$WS_NAME")"
  exit 4
else
  # 远端 >= 本地（或 --force）→ 从远端拉取
  SOURCE="remote"
fi

# ── 下载到 staging ─────────────────────────────────────────────────

rm -rf -- "$STAGE_DIR"
mkdir -p "$STAGE_DIR"

copy_workspace_to_stage() {
  local workspace_dir="$1"
  [[ -d "$workspace_dir" ]] || { echo "{\"error\":\"workspace $WS_NAME not found\"}"; exit 1; }
  cp -r "$workspace_dir"/* "$STAGE_DIR/"
}

if [[ "$SOURCE" == "remote" ]]; then
  case "$WS_BACKEND" in
    local)
      copy_workspace_to_stage "$WS_LOCAL_PATH/$WS_NAME"
      ;;
    github)
      ws_ensure_github
      copy_workspace_to_stage "$WS_GITHUB_LOCAL_REPO/$WS_NAME"
      ;;
    gitlab)
      ws_ensure_gitlab
      copy_workspace_to_stage "$WS_GITLAB_LOCAL_REPO/$WS_NAME"
      ;;
    minio)
      mc ls "${WS_MC_BASE}${WS_NAME}/" &>/dev/null || {
        echo "{\"error\":\"workspace $WS_NAME not found\"}"
        exit 1
      }
      mc cp --recursive "${WS_MC_BASE}${WS_NAME}/" "$STAGE_DIR/"
      ;;
  esac
else
  # local_only：直接从本地缓存复制，不拉远端
  case "$WS_BACKEND" in
    github)
      copy_workspace_to_stage "$WS_GITHUB_LOCAL_REPO/$WS_NAME"
      ;;
    gitlab)
      copy_workspace_to_stage "$WS_GITLAB_LOCAL_REPO/$WS_NAME"
      ;;
    local)
      copy_workspace_to_stage "$WS_LOCAL_PATH/$WS_NAME"
      ;;
    *)
      echo "{\"error\":\"local_only not supported for backend $WS_BACKEND\"}"
      exit 1
      ;;
  esac
fi

[[ -f "$STAGE_DIR/manifest.json" ]] || {
  echo '{"error":"manifest.json missing in downloaded workspace"}'
  exit 1
}

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
RESULTS_FILE="$TMP_DIR/project-results.jsonl"
UNRESOLVED_FILE="$TMP_DIR/unresolved.jsonl"
: > "$RESULTS_FILE"
: > "$UNRESOLVED_FILE"

declare -a PROJECT_ARGS=()

run_git_checkout() {
  local path="$1"
  local head="$2"
  local branch="$3"
  local upstream="$4"

  if [[ -n "$(git -C "$path" status --porcelain 2>/dev/null)" ]]; then
    printf 'skipped_dirty\n'
    return 0
  fi

  git -C "$path" fetch --all --prune &>/dev/null || true
  if ! git -C "$path" cat-file -e "${head}^{commit}" &>/dev/null; then
    printf 'skipped_head_missing\n'
    return 0
  fi

  git -C "$path" checkout -B "$branch" "$head" &>/dev/null || {
    printf 'skipped_head_missing\n'
    return 0
  }

  if [[ -n "$upstream" ]]; then
    git -C "$path" branch --set-upstream-to "$upstream" "$branch" &>/dev/null || true
  fi

  printf 'restored\n'
}

while IFS=$'\t' read -r name remote head branch upstream; do
  [[ -n "$name" ]] || continue

  resolution_json="$(
    bash "$SCRIPT_DIR/resolve-project-path.sh" \
      --remote "$remote" \
      --repo-name "$name" \
      --head "$head" \
      --config "$WS_CONFIG" \
      --local-paths "$LOCAL_PATHS_FILE"
  )"

  resolution_status="$(
    printf '%s' "$resolution_json" | python3 -c "import json,sys; print(json.load(sys.stdin).get('status',''))"
  )"
  remote_key="$(
    printf '%s' "$resolution_json" | python3 -c "import json,sys; print(json.load(sys.stdin).get('remote_key',''))"
  )"
  candidates_json="$(
    printf '%s' "$resolution_json" | python3 -c "import json,sys; print(json.dumps(json.load(sys.stdin).get('candidates', []), ensure_ascii=False))"
  )"

  case "$resolution_status" in
    exact)
      local_path="$(
        printf '%s' "$resolution_json" | python3 -c "import json,sys; print(json.load(sys.stdin).get('path',''))"
      )"
      local_path_unix="$(ws_to_unix_path "$local_path")"
      checkout_status="$(run_git_checkout "$local_path_unix" "$head" "$branch" "$upstream")"
      PROJECT_ARGS+=(--project "$name=$local_path")
      printf '{"name":"%s","status":"%s","path":"%s","head":"%s","branch":"%s"}\n' \
        "$(ws_json_escape "$name")" \
        "$(ws_json_escape "$checkout_status")" \
        "$(ws_json_escape "$local_path")" \
        "$(ws_json_escape "$head")" \
        "$(ws_json_escape "$branch")" >> "$RESULTS_FILE"
      ;;

    ambiguous)
      printf '{"name":"%s","status":"multiple_matches","candidates":%s}\n' \
        "$(ws_json_escape "$name")" \
        "$candidates_json" >> "$RESULTS_FILE"
      printf '{"name":"%s","remote_key":"%s","candidates":%s}\n' \
        "$(ws_json_escape "$name")" \
        "$(ws_json_escape "$remote_key")" \
        "$candidates_json" >> "$UNRESOLVED_FILE"
      ;;

    *)
      printf '{"name":"%s","status":"not_found","remote_key":"%s"}\n' \
        "$(ws_json_escape "$name")" \
        "$(ws_json_escape "$remote_key")" >> "$RESULTS_FILE"
      printf '{"name":"%s","remote_key":"%s","candidates":%s}\n' \
        "$(ws_json_escape "$name")" \
        "$(ws_json_escape "$remote_key")" \
        "$candidates_json" >> "$UNRESOLVED_FILE"
      ;;
  esac
done < <(python3 - "$STAGE_DIR/manifest.json" <<'PYEOF'
import json, sys

manifest = json.load(open(sys.argv[1], encoding="utf-8"))
for project in manifest.get("projects", []):
    print("\t".join([
        project.get("name", "") or "",
        project.get("remote", "") or "",
        project.get("head", "") or "",
        project.get("branch", "") or "",
        project.get("upstream", "") or "",
    ]))
PYEOF
)

SKILL_IMPORT_STATUS="skipped"
if bash "$WS_SKILL_DIR/scripts/import-skill-states.sh" \
     --workspace-name "$WS_NAME" \
     --stage-dir "$STAGE_DIR" \
     --manifest "$STAGE_DIR/manifest.json" \
     "${PROJECT_ARGS[@]}" 2>/dev/null; then
  SKILL_IMPORT_STATUS="done"
fi

python3 - "$STAGE_DIR" "$RESULTS_FILE" "$UNRESOLVED_FILE" "$SKILL_IMPORT_STATUS" "$SOURCE" <<'PYEOF'
import json, os, sys

stage_dir = sys.argv[1]
results_file = sys.argv[2]
unresolved_file = sys.argv[3]
skill_status = sys.argv[4]
source = sys.argv[5]

def load_jsonl(path):
    items = []
    if not os.path.isfile(path):
        return items
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if line:
                items.append(json.loads(line))
    return items

manifest = json.load(open(os.path.join(stage_dir, "manifest.json"), encoding="utf-8"))
output = {
    "stage_dir": stage_dir,
    "summary_path": os.path.join(stage_dir, "summary.md"),
    "source": source,
    "manifest": {
        "name": manifest.get("name"),
        "version": manifest.get("version"),
        "source_device": manifest.get("source_device"),
        "updated_at": manifest.get("updated_at"),
    },
    "project_results": load_jsonl(results_file),
    "unresolved": load_jsonl(unresolved_file),
    "skill_states": skill_status,
}
print(json.dumps(output, ensure_ascii=False, indent=2))
PYEOF

if [[ -s "$UNRESOLVED_FILE" ]]; then
  exit 3
fi
