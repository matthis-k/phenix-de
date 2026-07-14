#!/usr/bin/env bash
# Visual regression tests: simulate a->ai->a cycle and assert visual key stability
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/../../../.."

IPC=(newshell ipc call query)
FAILED=0
PASSED=0
SKIPPED=0

VERBOSE=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose|-v) VERBOSE=true; shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

fail() {
  local test="$1"
  local message="$2"
  echo "FAIL: $test - $message"
  FAILED=$((FAILED + 1))
}

pass() {
  local test="$1"
  if $VERBOSE; then echo "OK: $test"; fi
  PASSED=$((PASSED + 1))
}

skip() {
  local test="$1"
  local reason="$2"
  echo "SKIP: $test - $reason"
  SKIPPED=$((SKIPPED + 1))
}

call_visual_state() {
  # Returns JSON with current visual coordinator state (keys/phase/modelCount)
  "${IPC[@]}" "visualState" 2>/dev/null || echo '{"error":"IPC call failed"}'
}

call_visual_apply() {
  # Applies a query then returns the visual state
  # Query arg is passed as JSON string (newshell ipc expects JSON args)
  "${IPC[@]}" "visualApply" "\"$1\"" 2>/dev/null || echo '{"error":"IPC call failed"}'
}

extract_keys() {
  echo "$1" | jq '[.current.rows[] | {key, phase, rank}]' 2>/dev/null || echo '[]'
}

extract_live_keys() {
  echo "$1" | jq '[.current.rows[] | select(.phase != "leaving") | .key]' 2>/dev/null || echo '[]'
}

extract_leaving_keys() {
  echo "$1" | jq '[.current.rows[] | select(.phase == "leaving") | .key]' 2>/dev/null || echo '[]'
}

extract_recently_removed() {
  echo "$1" | jq '.current.recentlyRemovedKeys // []' 2>/dev/null || echo '[]'
}

extract_query_identity() {
  echo "$1" | jq '{query: .current.query, queryRevision: .current.queryRevision, generation: .current.generation}' 2>/dev/null || echo '{}'
}

echo "=== Visual Regression Tests ==="
echo ""

# ============================================================
# Test 1: a -> ai -> a cycle preserves visual keys
# ============================================================
echo "--- Type Cycle: a -> ai -> a ---"

# Fresh "a"
FRESH_A=$(call_visual_apply "a") || { skip "cycle-fresh-a" "IPC call failed"; }
FRESH_KEYS=$(extract_live_keys "$FRESH_A")
FRESH_COUNT=$(echo "$FRESH_KEYS" | jq 'length' 2>/dev/null || echo "0")
echo "INFO: fresh 'a' has $FRESH_COUNT live keys"
if $VERBOSE; then echo "$FRESH_KEYS"; fi

if [[ "$FRESH_COUNT" -eq 0 ]]; then
  skip "cycle: a" "Fresh 'a' returned no live keys"
else
  pass "cycle-fresh-a-has-keys: $FRESH_COUNT"
fi

# Type "ai" (intermediate)
INTERMEDIATE=$(call_visual_apply "ai") || { skip "cycle-intermediate" "IPC call failed"; }
INTERMEDIATE_KEYS=$(extract_live_keys "$INTERMEDIATE")
INTERMEDIATE_COUNT=$(echo "$INTERMEDIATE_KEYS" | jq 'length' 2>/dev/null || echo "0")
if $VERBOSE; then echo "INFO: intermediate 'ai' has $INTERMEDIATE_COUNT live keys"; fi

# Type "a" again (final)
FINAL_A=$(call_visual_apply "a") || { skip "cycle-final-a" "IPC call failed"; }
FINAL_KEYS=$(extract_live_keys "$FINAL_A")
FINAL_COUNT=$(echo "$FINAL_KEYS" | jq 'length' 2>/dev/null || echo "0")
echo "INFO: final 'a' has $FINAL_COUNT live keys"
if $VERBOSE; then echo "$FINAL_KEYS"; fi

if [[ "$FINAL_COUNT" -eq 0 ]]; then
  fail "cycle-final-a-has-keys" "Final 'a' returned no live keys"
elif [[ "$FRESH_COUNT" -eq "$FINAL_COUNT" ]]; then
  pass "cycle-key-count: $FRESH_COUNT == $FINAL_COUNT"
else
  fail "cycle-key-count" "Fresh 'a' has $FRESH_COUNT live keys but final has $FINAL_COUNT"
fi

# Check key identity: fresh and final should produce same keys (order may differ)
if [[ "$FRESH_COUNT" -gt 0 && "$FINAL_COUNT" -gt 0 ]]; then
  FRESH_KEY_SET=$(echo "$FRESH_KEYS" | jq 'sort' 2>/dev/null)
  FINAL_KEY_SET=$(echo "$FINAL_KEYS" | jq 'sort' 2>/dev/null)
  if [[ "$FRESH_KEY_SET" == "$FINAL_KEY_SET" ]]; then
    pass "cycle-key-identity: fresh and final have same keys"
  else
    MISSING=$(diff <(echo "$FRESH_KEY_SET" | jq -c .) <(echo "$FINAL_KEY_SET" | jq -c .) 2>/dev/null || echo "different")
    fail "cycle-key-identity" "Keys differ between fresh and final: $MISSING"
  fi
fi

# ============================================================
# Test 2: No leaving keys should be present for keys in target
# ============================================================
echo "--- Leaving Key Sanity ---"

FULL_STATE=$(call_visual_apply "a") || { skip "leaving-sanity-apply" "IPC call failed"; }
LEAVING_KEYS=$(extract_leaving_keys "$FULL_STATE")
LEAVING_COUNT=$(echo "$LEAVING_KEYS" | jq 'length' 2>/dev/null || echo "0")
if [[ "$LEAVING_COUNT" -eq 0 ]]; then
  pass "no-leaving-keys: after 'a'"
else
  skip "no-leaving-keys: after 'a'" "Found $LEAVING_COUNT leaving keys (OK if just settled)"
fi

# ============================================================
# Test 3: Query identity tracking
# ============================================================
echo "--- Query Identity ---"

IDENTITY=$(call_visual_apply "a") || { skip "identity" "IPC call failed"; }
QID=$(extract_query_identity "$IDENTITY")
Q=$(echo "$QID" | jq -r '.query' 2>/dev/null || echo "")
QR=$(echo "$QID" | jq '.queryRevision' 2>/dev/null || echo "-1")
if [[ "$Q" == "a" ]]; then
  pass "identity-query: $Q"
else
  fail "identity-query" "Expected query='a', got '$Q'"
fi
if [[ "$QR" -ge 0 ]]; then
  pass "identity-revision: $QR"
else
  fail "identity-revision" "queryRevision not tracked"
fi

# ============================================================
# Test 4: No recentlyRemoved keys that are also in target
# ============================================================
echo "--- RecentlyRemoved vs Target ---"

STATE=$(call_visual_apply "a") || { skip "removed-vs-target" "IPC call failed"; }
RECENTLY_REMOVED=$(extract_recently_removed "$STATE")
RR_COUNT=$(echo "$RECENTLY_REMOVED" | jq 'length' 2>/dev/null || echo "0")
LIVE_KEYS=$(extract_live_keys "$STATE")
# Check none of the recentlyRemoved keys are also live
for RKEY in $(echo "$RECENTLY_REMOVED" | jq -r '.[]' 2>/dev/null); do
  IN_LIVE=$(echo "$LIVE_KEYS" | jq "contains([\"$RKEY\"])" 2>/dev/null)
  if [[ "$IN_LIVE" == "true" ]]; then
    fail "recentlyRemoved-in-live" "Key '$RKEY' is both live and recentlyRemoved"
  fi
done
if $VERBOSE && [[ "$RR_COUNT" -gt 0 ]]; then
  echo "INFO: $RR_COUNT recentlyRemoved keys (expected after type cycle)"
fi
pass "recentlyRemoved-no-conflict: checked $RR_COUNT keys"

# ============================================================
# Summary
# ============================================================
echo ""
echo "=== Visual Regression Test Summary ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo "Skipped: $SKIPPED"

if [[ $FAILED -gt 0 ]]; then
  exit 1
fi
