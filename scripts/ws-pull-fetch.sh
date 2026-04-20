#!/usr/bin/env bash
# ws-pull-fetch.sh <ws_name>
# 下载 workspace、自动匹配项目路径、git checkout、导入 skill states
# 退出码: 0=完成(含部分 skipped) 1=失败 3=有未解析的项目路径
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ws-backend.sh
source "$SCRIPT_DIR/ws-backend.sh"

WS_NAME="${1:-}"
[[ -n "$WS_NAME" ]] || { echo '{"error":"ws_name is required"}'; exit 1; }

ws_backend_init

LOCAL_PATHS_FILE="$(ws_get_json_string "$WS_CONFIG" "local_paths_file")"
[[ -n "$LOCAL_PATHS_FILE" ]] || LOCAL_PATHS_FILE="~/.claude/skills/workspace-sync/local-paths.json"
LOCAL_PATHS_FILE="$(ws_expand_home "$LOCAL_PATHS_FILE")"

STAGE_ROOT="$WS_CACHE_DIR/staging"
STAGE_DIR="$STAGE_ROOT/$WS_NAME"
[[ "$STAGE_DIR" == "$STAGE_ROOT/"* ]] || { echo '{"error":"illegal staging path"}'; exit 1; }
rm -rf -- "$STAGE_DIR"
mkdir -p "$STAGE_DIR"

copy_workspace_to_stage() {
  local workspace_dir="$1"
  [[ -d "$workspace_dir" ]] || { echo "{\"error\":\"workspace $WS_NAME not found\"}"; exit 1; }
  cp -r "$workspace_dir"/* "$STAGE_DIR/"
}

case "$WS_BACKEND" in
  local)
    ws_init_local
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
    ws_init_minio
    mc ls "${WS_MC_BASE}${WS_NAME}/" &>/dev/null || {
      echo "{\"error\":\"workspace $WS_NAME not found\"}"
      exit 1
    }
    mc cp --recursive "${WS_MC_BASE}${WS_NAME}/" "$STAGE_DIR/"
    ;;

  *)
    echo "{\"error\":\"unknown backend: $WS_BACKEND\"}"
    exit 1
    ;;
esac

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

python3 - "$STAGE_DIR" "$RESULTS_FILE" "$UNRESOLVED_FILE" "$SKILL_IMPORT_STATUS" <<'PYEOF'
import json, os, sys

stage_dir = sys.argv[1]
results_file = sys.argv[2]
unresolved_file = sys.argv[3]
skill_status = sys.argv[4]

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
