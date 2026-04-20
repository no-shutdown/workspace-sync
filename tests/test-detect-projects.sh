#!/usr/bin/env bash
# 测试 detect-projects.sh 的核心行为

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DETECT="$SCRIPT_DIR/../scripts/detect-projects.sh"
PASS=0
FAIL=0

assert_eq() {
  local label="$1"
  local expected="$2"
  local actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo "  ✓ $label"
    ((PASS++))
  else
    echo "  ✗ $label"
    echo "    expected: $expected"
    echo "    actual:   $actual"
    ((FAIL++))
  fi
}

assert_contains() {
  local label="$1"
  local needle="$2"
  local haystack="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    echo "  ✓ $label"
    ((PASS++))
  else
    echo "  ✗ $label"
    echo "    expected to contain: $needle"
    echo "    actual: $haystack"
    ((FAIL++))
  fi
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "=== test-detect-projects.sh ==="

# --- Case 1: 空路径返回 [] ---
echo ""
echo "Case 1: 无效路径"
result=$(bash "$DETECT" "" 2>/dev/null)
assert_eq "空路径返回 []" "[]" "$result"

result=$(bash "$DETECT" "/nonexistent/path.jsonl" 2>/dev/null)
assert_eq "不存在的文件返回 []" "[]" "$result"

# --- Case 2: 空 jsonl 返回 [] ---
echo ""
echo "Case 2: 空 jsonl"
touch "$TMP/empty.jsonl"
result=$(bash "$DETECT" "$TMP/empty.jsonl" 2>/dev/null)
assert_eq "空 jsonl 返回 []" "[]" "$result"

# --- Case 3: jsonl 中包含当前仓库路径 ---
echo ""
echo "Case 3: 包含 file_path 的 jsonl"

REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SAMPLE_FILE="$REPO_ROOT/SKILL.md"

if [[ -f "$SAMPLE_FILE" ]]; then
  cat > "$TMP/with-file.jsonl" <<EOF
{"type":"tool_result","content":[{"type":"text","text":"ok"}],"tool_use_id":"x","file_path":"$SAMPLE_FILE"}
EOF
  result=$(bash "$DETECT" "$TMP/with-file.jsonl" 2>/dev/null)
  assert_contains "检测到 workspace-sync 仓库" "workspace-sync" "$result"
  assert_contains "输出包含 name 字段" '"name"' "$result"
  assert_contains "输出包含 path 字段" '"path"' "$result"
  assert_contains "输出包含 head 字段" '"head"' "$result"
else
  echo "  skip: SKILL.md not found at $SAMPLE_FILE"
fi

# --- Case 4: 损坏 JSON 行不崩溃 ---
echo ""
echo "Case 4: 包含损坏 JSON 的 jsonl"
cat > "$TMP/corrupt.jsonl" <<'EOF'
{"valid": "json"}
{corrupt json line
{"another": "valid"}
EOF
result=$(bash "$DETECT" "$TMP/corrupt.jsonl" 2>/dev/null)
assert_eq "损坏行不导致崩溃，返回 []" "[]" "$result"

# --- Case 5: cwd 字段也能触发检测 ---
echo ""
echo "Case 5: 通过 cwd 字段检测"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cat > "$TMP/with-cwd.jsonl" <<EOF
{"type":"assistant","cwd":"$REPO_ROOT"}
EOF
result=$(bash "$DETECT" "$TMP/with-cwd.jsonl" 2>/dev/null)
# cwd-only 路径进 ROOT_DIRS 但不进 ROOT_HITS，不影响结果格式
if echo "$result" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null; then
  echo "  ✓ cwd jsonl 输出合法 JSON"
  ((PASS++))
else
  echo "  ✗ cwd jsonl 输出不是合法 JSON: $result"
  ((FAIL++))
fi

# --- Case 6: 输出始终是合法 JSON 数组 ---
echo ""
echo "Case 6: 输出格式验证"
for f in "$TMP/empty.jsonl" "$TMP/corrupt.jsonl"; do
  result=$(bash "$DETECT" "$f" 2>/dev/null)
  if echo "$result" | python3 -c "import json,sys; v=json.load(sys.stdin); assert isinstance(v,list)" 2>/dev/null; then
    echo "  ✓ $(basename $f) 输出是合法 JSON 数组"
    ((PASS++))
  else
    echo "  ✗ $(basename $f) 输出不是合法 JSON 数组: $result"
    ((FAIL++))
  fi
done

# --- 结果汇总 ---
echo ""
echo "=== 结果: $PASS passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
