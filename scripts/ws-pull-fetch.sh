#!/usr/bin/env bash
# ws-pull-fetch.sh <ws_name>
# 下载 workspace、自动匹配项目路径、git checkout、导入 skill states
# 输出 JSON 到 stdout
# 退出码: 0=完成(含部分 skipped) 1=失败 3=有未解析的项目路径(需用户提供)
set -euo pipefail

WS_NAME="${1:-}"
[[ -n "$WS_NAME" ]] || { echo '{"error":"ws_name is required"}'; exit 1; }

SKILL_DIR="$HOME/.claude/skills/workspace-sync"
CONFIG="$SKILL_DIR/config.json"
[[ -f "$CONFIG" ]] || { echo '{"error":"config not found"}'; exit 1; }

_py() { python3 -c "$1" 2>/dev/null || echo ""; }

BACKEND=$(_py "import json; d=json.load(open('$CONFIG')); print(d.get('backend') or '')")
[[ -n "$BACKEND" ]] || { echo '{"error":"backend not configured"}'; exit 1; }

CACHE_DIR=$(_py "import json; d=json.load(open('$CONFIG')); print(d.get('cache_dir') or '~/.claude/workspace-cache')")
CACHE_DIR="${CACHE_DIR/#\~/$HOME}"
LOCAL_PATHS_FILE=$(_py "import json; d=json.load(open('$CONFIG')); print(d.get('local_paths_file') or '~/.claude/skills/workspace-sync/local-paths.json')")
LOCAL_PATHS_FILE="${LOCAL_PATHS_FILE/#\~/$HOME}"

# ── Step 1: 准备 staging 目录 & 下载 ────────────────────────────────────────
STAGE_ROOT="$CACHE_DIR/staging"
STAGE_DIR="$STAGE_ROOT/$WS_NAME"
[[ "$STAGE_DIR" == "$STAGE_ROOT/"* ]] || { echo '{"error":"illegal staging path"}'; exit 1; }
rm -rf -- "$STAGE_DIR"
mkdir -p "$STAGE_DIR"

case "$BACKEND" in

  local)
    LP=$(_py "import json; d=json.load(open('$CONFIG')); print((d.get('local') or {}).get('path') or '')")
    LP="${LP/#\~/$HOME}"
    WS_DIR="$LP/$WS_NAME"
    [[ -d "$WS_DIR" ]] || { echo "{\"error\": \"workspace $WS_NAME not found\"}"; exit 1; }
    cp -r "$WS_DIR"/* "$STAGE_DIR/"
    ;;

  github)
    TOKEN=$(_py "import json; d=json.load(open('$CONFIG')); print((d.get('github') or {}).get('token') or '')")
    REPO=$(_py "import json; d=json.load(open('$CONFIG')); print((d.get('github') or {}).get('repo') or '')")
    BRANCH=$(_py "import json; d=json.load(open('$CONFIG')); print((d.get('github') or {}).get('branch') or 'main')")
    LOCAL_REPO="$CACHE_DIR/github/$(echo "$REPO" | sed 's|/|_|g')"
    if [[ ! -d "$LOCAL_REPO/.git" ]]; then
      mkdir -p "$(dirname "$LOCAL_REPO")"
      git clone "https://${TOKEN}@github.com/${REPO}.git" "$LOCAL_REPO" \
        || { echo '{"error":"GitHub clone failed"}'; exit 1; }
    else
      (cd "$LOCAL_REPO" && git pull --ff-only 2>/dev/null) || true
    fi
    WS_DIR="$LOCAL_REPO/$WS_NAME"
    [[ -d "$WS_DIR" ]] || { echo "{\"error\": \"workspace $WS_NAME not found\"}"; exit 1; }
    cp -r "$WS_DIR"/* "$STAGE_DIR/"
    ;;

  gitlab)
    HOST=$(_py "import json; d=json.load(open('$CONFIG')); print((d.get('gitlab') or {}).get('host') or '')")
    TOKEN=$(_py "import json; d=json.load(open('$CONFIG')); print((d.get('gitlab') or {}).get('token') or '')")
    PROJ=$(_py "import json; d=json.load(open('$CONFIG')); print((d.get('gitlab') or {}).get('project_path') or '')")
    BRANCH=$(_py "import json; d=json.load(open('$CONFIG')); print((d.get('gitlab') or {}).get('branch') or 'main')")
    LOCAL_REPO="$CACHE_DIR/gitlab/$(echo "$PROJ" | sed 's|/|_|g')"
    if [[ ! -d "$LOCAL_REPO/.git" ]]; then
      mkdir -p "$(dirname "$LOCAL_REPO")"
      no_proxy="$HOST" git clone \
        "https://oauth2:${TOKEN}@${HOST}/${PROJ}.git" "$LOCAL_REPO" \
        || { echo '{"error":"GitLab clone failed"}'; exit 1; }
    else
      (cd "$LOCAL_REPO" && no_proxy="$HOST" git pull --ff-only 2>/dev/null) || true
    fi
    WS_DIR="$LOCAL_REPO/$WS_NAME"
    [[ -d "$WS_DIR" ]] || { echo "{\"error\": \"workspace $WS_NAME not found\"}"; exit 1; }
    cp -r "$WS_DIR"/* "$STAGE_DIR/"
    ;;

  minio)
    MC_ALIAS=$(_py "import json; d=json.load(open('$CONFIG')); print((d.get('minio') or {}).get('mc_alias') or 'workspace-sync')")
    BUCKET=$(_py "import json; d=json.load(open('$CONFIG')); print((d.get('minio') or {}).get('bucket') or '')")
    PREFIX=$(_py "import json; d=json.load(open('$CONFIG')); print((d.get('minio') or {}).get('prefix') or 'workspaces/')")
    mc ls "${MC_ALIAS}/${BUCKET}/${PREFIX}${WS_NAME}/" &>/dev/null \
      || { echo "{\"error\": \"workspace $WS_NAME not found\"}"; exit 1; }
    mc cp --recursive "${MC_ALIAS}/${BUCKET}/${PREFIX}${WS_NAME}/" "$STAGE_DIR/"
    ;;

  *)
    echo "{\"error\": \"unknown backend: $BACKEND\"}"; exit 1 ;;
esac

[[ -f "$STAGE_DIR/manifest.json" ]] || { echo '{"error":"manifest.json missing in downloaded workspace"}'; exit 1; }

# ── Step 2: 自动匹配本地项目路径 & Step 3: checkout ─────────────────────────
FETCH_RESULT=$(python3 - "$STAGE_DIR" "$CONFIG" "$LOCAL_PATHS_FILE" <<'PYEOF'
import json, subprocess, os, sys

stage_dir       = sys.argv[1]
config_path     = sys.argv[2]
local_paths_file = sys.argv[3]

config   = json.load(open(config_path))
manifest = json.load(open(os.path.join(stage_dir, "manifest.json")))

scan_roots = [os.path.expanduser(r) for r in (config.get("scan_roots") or [])]

# Load local-paths.json
local_paths = {}
if os.path.isfile(local_paths_file):
    try:
        d = json.load(open(local_paths_file))
        local_paths = d.get("projects", {})
    except:
        pass

def normalize_remote(url):
    import re
    url = url.strip()
    url = re.sub(r'^ssh://', '', url)
    url = re.sub(r'^git@([^:]+):', r'\1/', url)
    url = re.sub(r'^https?://', '', url)
    url = re.sub(r'^[^@]+@', '', url)
    url = re.sub(r'\.git$', '', url)
    parts = url.split('/', 1)
    if len(parts) == 2:
        url = parts[0].lower() + '/' + parts[1]
    return url

def find_in_scan_roots(remote_key):
    matches = []
    for root in scan_roots:
        if not os.path.isdir(root): continue
        for entry in os.listdir(root):
            candidate = os.path.join(root, entry)
            git_dir = os.path.join(candidate, ".git")
            if not os.path.isdir(git_dir): continue
            r = subprocess.run(["git", "config", "--get", "remote.origin.url"],
                               cwd=candidate, capture_output=True, text=True)
            if normalize_remote(r.stdout.strip()) == remote_key:
                matches.append(candidate)
    return matches

def run_git_checkout(path, head, branch, upstream):
    r = subprocess.run(["git", "status", "--porcelain"], cwd=path, capture_output=True, text=True)
    if r.stdout.strip():
        return "skipped_dirty"
    subprocess.run(["git", "fetch", "--all", "--prune"], cwd=path, capture_output=True)
    r = subprocess.run(["git", "cat-file", "-e", f"{head}^{{commit}}"],
                       cwd=path, capture_output=True)
    if r.returncode != 0:
        return "skipped_head_missing"
    subprocess.run(["git", "checkout", "-B", branch, head], cwd=path, capture_output=True)
    if upstream:
        subprocess.run(["git", "branch", "--set-upstream-to", upstream, branch],
                       cwd=path, capture_output=True)
    return "restored"

results    = []
unresolved = []

for proj in manifest.get("projects", []):
    name     = proj.get("name", "")
    remote   = proj.get("remote", "")
    head     = proj.get("head", "")
    branch   = proj.get("branch", "")
    upstream = proj.get("upstream", "")
    remote_key = normalize_remote(remote)

    local_path = None

    # 1. Check local-paths.json
    if remote_key in local_paths:
        cached = local_paths[remote_key].get("path", "")
        if os.path.isdir(cached):
            r = subprocess.run(["git", "config", "--get", "remote.origin.url"],
                               cwd=cached, capture_output=True, text=True)
            if normalize_remote(r.stdout.strip()) == remote_key:
                local_path = cached

    # 2. Scan roots
    if not local_path:
        matches = find_in_scan_roots(remote_key)
        if len(matches) == 1:
            local_path = matches[0]
            # Auto-save to local-paths.json
            local_paths[remote_key] = {"path": local_path, "repo_name": name}
            try:
                d = json.load(open(local_paths_file)) if os.path.isfile(local_paths_file) else {"version": 1, "projects": {}}
            except:
                d = {"version": 1, "projects": {}}
            d["projects"][remote_key] = {"path": local_path, "repo_name": name}
            os.makedirs(os.path.dirname(local_paths_file), exist_ok=True)
            with open(local_paths_file, "w") as f:
                json.dump(d, f, ensure_ascii=False, indent=2)
        elif len(matches) > 1:
            results.append({"name": name, "status": "multiple_matches", "candidates": matches})
            unresolved.append({"name": name, "remote_key": remote_key, "candidates": matches})
            continue

    if not local_path:
        results.append({"name": name, "status": "not_found", "remote_key": remote_key})
        unresolved.append({"name": name, "remote_key": remote_key, "candidates": []})
        continue

    status = run_git_checkout(local_path, head, branch, upstream)
    results.append({"name": name, "status": status, "path": local_path,
                    "head": head, "branch": branch})

print(json.dumps({
    "project_results": results,
    "unresolved":      unresolved
}))
PYEOF
)

# ── Step 4: 导入 skill states ────────────────────────────────────────────────
SKILL_IMPORT_STATUS="skipped"
if bash "$SKILL_DIR/scripts/import-skill-states.sh" \
     --workspace-name "$WS_NAME" \
     --stage-dir "$STAGE_DIR" \
     --manifest "$STAGE_DIR/manifest.json" 2>/dev/null; then
  SKILL_IMPORT_STATUS="done"
fi

# ── 组装最终输出 ─────────────────────────────────────────────────────────────
HAS_UNRESOLVED=$(echo "$FETCH_RESULT" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print('true' if d.get('unresolved') else 'false')
" 2>/dev/null || echo "false")

python3 - "$STAGE_DIR" "$FETCH_RESULT" "$SKILL_IMPORT_STATUS" <<'PYEOF'
import json, sys, os

stage_dir    = sys.argv[1]
fetch_data   = json.loads(sys.argv[2])
skill_status = sys.argv[3]

manifest = json.load(open(os.path.join(stage_dir, "manifest.json")))

output = {
    "stage_dir":       stage_dir,
    "summary_path":    os.path.join(stage_dir, "summary.md"),
    "manifest":        {"name": manifest.get("name"), "version": manifest.get("version"),
                        "source_device": manifest.get("source_device"), "updated_at": manifest.get("updated_at")},
    "project_results": fetch_data.get("project_results", []),
    "unresolved":      fetch_data.get("unresolved", []),
    "skill_states":    skill_status,
}
print(json.dumps(output, ensure_ascii=False, indent=2))
PYEOF

# 有未解析路径时用退出码 3 通知 Claude
if [[ "$HAS_UNRESOLVED" == "true" ]]; then
  exit 3
fi
