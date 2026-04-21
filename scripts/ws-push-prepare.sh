#!/usr/bin/env bash
# ws-push-prepare.sh <ws_name>
# push 的 shell 准备阶段：定位 session、检测项目、校验 git 状态、读取远端版本
# 成功时输出 JSON 到 stdout，并写入 $STAGE_DIR/.prepare-result.json
# 退出码: 0=成功 1=致命错误
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./workspace-sync-lib.sh
source "$SCRIPT_DIR/workspace-sync-lib.sh"

WS_NAME="${1:-}"
[[ -n "$WS_NAME" ]] || { echo '{"error":"ws_name is required"}'; exit 1; }

SKILL_DIR="$(ws_workspace_sync_dir "$SCRIPT_DIR")"
CONFIG="$(ws_workspace_sync_config_path "$SCRIPT_DIR")"
[[ -f "$CONFIG" ]] || { echo '{"error":"config not found"}'; exit 1; }

_py() { python3 -c "$1" 2>/dev/null || echo ""; }

BACKEND=$(_py "import json; d=json.load(open('$CONFIG')); print(d.get('backend') or '')")
[[ -n "$BACKEND" ]] || { echo '{"error":"backend not configured"}'; exit 1; }

CACHE_DIR=$(_py "import json; d=json.load(open('$CONFIG')); print(d.get('cache_dir') or '')")
[[ -n "$CACHE_DIR" ]] || CACHE_DIR="$(ws_default_workspace_cache_dir "$CONFIG")"
CACHE_DIR="$(ws_expand_home "$CACHE_DIR")"
PROJECTS_DIR="$(ws_projects_dir)"

# ── Step 2: 定位 session JSONL ──────────────────────────────────────────────
WIN_PWD=$(cygpath -w "$PWD" 2>/dev/null || echo "$PWD")
ENCODED_CWD=$(echo "$WIN_PWD" | sed 's|[:\\/]|-|g')
SESSION_JSONL=$(ls -t "$PROJECTS_DIR/$ENCODED_CWD/"*.jsonl 2>/dev/null | head -1 || echo "")

if [[ -z "$SESSION_JSONL" ]]; then
  SESSION_JSONL=$(
    find "$PROJECTS_DIR" -name "*.jsonl" 2>/dev/null \
    | xargs ls -t 2>/dev/null \
    | while read -r f; do
        if grep -qF "\"cwd\":\"$PWD\"" "$f" 2>/dev/null || \
           grep -qF "\"cwd\":\"$WIN_PWD\"" "$f" 2>/dev/null; then
          echo "$f"; break
        fi
      done
  )
fi
[[ -n "$SESSION_JSONL" ]] || { echo '{"error":"session jsonl not found"}'; exit 1; }

# ── Step 3: 检测涉及的项目 ───────────────────────────────────────────────────
chmod +x "$SKILL_DIR/scripts/detect-projects.sh"
PROJECTS_JSON=$(bash "$SKILL_DIR/scripts/detect-projects.sh" "$SESSION_JSONL" 2>/dev/null || echo "[]")

# ── Step 5: 准备 staging 目录 ────────────────────────────────────────────────
STAGE_ROOT="$CACHE_DIR/staging"
STAGE_DIR="$STAGE_ROOT/$WS_NAME"
[[ "$STAGE_DIR" == "$STAGE_ROOT/"* ]] || { echo '{"error":"illegal staging path"}'; exit 1; }
rm -rf -- "$STAGE_DIR"
mkdir -p "$STAGE_DIR/projects"
cp "$SESSION_JSONL" "$STAGE_DIR/conversation.jsonl"

# ── Step 7: 检查每个项目的 git 状态 ─────────────────────────────────────────
PREPARE_DATA=$(python3 - "$PROJECTS_JSON" "$CONFIG" "$CACHE_DIR" "$BACKEND" "$WS_NAME" <<'PYEOF'
import json, subprocess, os, sys

projects_json = sys.argv[1]
config_path   = sys.argv[2]
cache_dir     = sys.argv[3]
backend       = sys.argv[4]
ws_name       = sys.argv[5]

config = json.load(open(config_path))
projects = json.loads(projects_json)

results  = []
warnings = []

for proj in projects:
    path = proj.get("path", "")
    name = proj.get("name", "")
    if not os.path.isdir(os.path.join(path, ".git")):
        continue

    code_status = "clean"

    # dirty check
    r = subprocess.run(["git", "status", "--porcelain"], cwd=path, capture_output=True, text=True)
    if r.stdout.strip():
        code_status = "dirty"
        warnings.append(f"⚠  {name}: 存在未提交改动")

    # upstream check (fatal: can't record remote pointer without it)
    r = subprocess.run(
        ["git", "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"],
        cwd=path, capture_output=True, text=True)
    upstream = r.stdout.strip()
    if not upstream:
        print(json.dumps({"error": f"{name} 没有上游分支，请先 git push -u"}))
        sys.exit(1)

    # sync check
    subprocess.run(["git", "fetch", "--prune"], cwd=path, capture_output=True)
    r = subprocess.run(
        ["git", "rev-list", "--left-right", "--count", "HEAD...@{u}"],
        cwd=path, capture_output=True, text=True)
    counts = r.stdout.strip().split()
    if len(counts) == 2 and (counts[0] != "0" or counts[1] != "0"):
        if code_status == "clean":
            code_status = "out_of_sync"
        warnings.append(f"⚠  {name}: 与上游不同步 (ahead={counts[0]} behind={counts[1]})")

    head     = subprocess.run(["git", "rev-parse", "HEAD"], cwd=path, capture_output=True, text=True).stdout.strip()
    branch   = subprocess.run(["git", "rev-parse", "--abbrev-ref", "HEAD"], cwd=path, capture_output=True, text=True).stdout.strip()
    remote   = subprocess.run(["git", "config", "--get", "remote.origin.url"], cwd=path, capture_output=True, text=True).stdout.strip()

    results.append({**proj, "code_status": code_status,
                    "head": head, "branch": branch,
                    "upstream": upstream, "remote": remote})

# ── Step 6: 读取远端版本 ──────────────────────────────────────────────────
remote_version    = 0
remote_created_at = ""
old_summary_path  = ""

def read_manifest(path):
    global remote_version, remote_created_at
    if os.path.isfile(path):
        d = json.load(open(path))
        remote_version    = d.get("version") or 0
        remote_created_at = d.get("created_at") or ""

if backend == "local":
    lp = (config.get("local") or {}).get("path") or ""
    lp = os.path.expanduser(lp)
    read_manifest(os.path.join(lp, ws_name, "manifest.json"))
    old_sum = os.path.join(lp, ws_name, "summary.md")
    if os.path.isfile(old_sum): old_summary_path = old_sum

elif backend == "github":
    repo = (config.get("github") or {}).get("repo") or ""
    local_repo = os.path.join(cache_dir, "github", repo.replace("/", "_"))
    read_manifest(os.path.join(local_repo, ws_name, "manifest.json"))
    old_sum = os.path.join(local_repo, ws_name, "summary.md")
    if os.path.isfile(old_sum): old_summary_path = old_sum

elif backend == "gitlab":
    proj_path = (config.get("gitlab") or {}).get("project_path") or ""
    local_repo = os.path.join(cache_dir, "gitlab", proj_path.replace("/", "_"))
    read_manifest(os.path.join(local_repo, ws_name, "manifest.json"))
    old_sum = os.path.join(local_repo, ws_name, "summary.md")
    if os.path.isfile(old_sum): old_summary_path = old_sum

elif backend == "minio":
    # MinIO: manifest already fetched by ws-list or will be fetched fresh in upload step
    # For now, skip pre-read; concurrency check happens in upload
    pass

print(json.dumps({
    "projects": results,
    "code_warnings": warnings,
    "remote_version": remote_version,
    "remote_created_at": remote_created_at,
    "old_summary_path": old_summary_path
}))
PYEOF
)

# Check for fatal error in python output
if echo "$PREPARE_DATA" | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(1 if 'error' in d else 0)" 2>/dev/null; then
  :
else
  echo "$PREPARE_DATA"
  exit 1
fi

# ── 输出完整 JSON ────────────────────────────────────────────────────────────
python3 - "$STAGE_DIR" "$SESSION_JSONL" "$BACKEND" "$PREPARE_DATA" <<'PYEOF'
import json, sys

stage_dir    = sys.argv[1]
session_jsonl = sys.argv[2]
backend       = sys.argv[3]
prep          = json.loads(sys.argv[4])

result = {
    "stage_dir":         stage_dir,
    "session_jsonl":     session_jsonl,
    "backend":           backend,
    "projects":          prep["projects"],
    "code_warnings":     prep["code_warnings"],
    "remote_version":    prep["remote_version"],
    "remote_created_at": prep["remote_created_at"],
    "old_summary_path":  prep["old_summary_path"],
}

output = json.dumps(result, ensure_ascii=False, indent=2)

# 写入 staging 供 upload 阶段读取
with open(f"{stage_dir}/.prepare-result.json", "w") as f:
    f.write(output)

print(output)
PYEOF
