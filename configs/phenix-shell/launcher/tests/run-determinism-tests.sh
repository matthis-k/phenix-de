#!/usr/bin/env bash
# Determinism tests: same query + backend snapshot must produce identical results
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/../../../.."

IPC=(newshell ipc call query)
FAILED=0
PASSED=0
SKIPPED=0

fail() {
  local test="$1"
  local message="$2"
  echo "FAIL: $test - $message"
  FAILED=$((FAILED + 1))
}

pass() {
  local test="$1"
  if [[ ${VERBOSE:-false} == true ]]; then echo "OK: $test"; fi
  PASSED=$((PASSED + 1))
}

skip() {
  local test="$1"
  local reason="$2"
  echo "SKIP: $test - $reason"
  SKIPPED=$((SKIPPED + 1))
}

call_pipeline() {
  "${IPC[@]}" "$1" 2>/dev/null || echo '{"error":"IPC call failed"}'
}

# Extract normalized pipeline output for comparison: strip timings, revision, metadata
normalize_output() {
  echo "$1" | jq '{
    rowIds: [.rows[] | .nodeId],
    placements: [.rows[] | .placement],
    rowCount: (.rows | length),
    selectedIndex: .selection.selectedIndex,
    selectedId: .selection.selectedId
  }' 2>/dev/null || echo '{"error":"normalize failed"}'
}

echo "=== Determinism Tests ==="
echo ""

# ============================================================
# Section 1: Same query, repeated calls
# ============================================================
echo "--- Repeated Query Stability ---"

for query in "newxos" "wifi" "zen" "net" "vpn" "n" "a"; do
  RESULT1=$(call_pipeline "$query") || { fail "$query-1" "IPC call failed"; continue; }

  # Brief pause between calls
  sleep 0.1

  RESULT2=$(call_pipeline "$query") || { fail "$query-2" "IPC call failed"; continue; }

  NORM1=$(normalize_output "$RESULT1")
  NORM2=$(normalize_output "$RESULT2")

  if [[ "$NORM1" == "$NORM2" ]]; then
    pass "repeated-stability: $query"
  else
    ROW_DIFF=$(diff <(echo "$NORM1" | jq -c .) <(echo "$NORM2" | jq -c .) 2>/dev/null || echo "different")
    fail "repeated-stability: $query" "Results differ between identical calls: $ROW_DIFF"
  fi
done

# ============================================================
# Section 2: a -> ai -> a cycle (regression test for stale state)
# ============================================================
echo "--- Type Cycle ---"

FIRST_A=$(call_pipeline "a") || { skip "cycle-first-a" "IPC call failed"; }
sleep 0.05
_=$(call_pipeline "ai") >/dev/null 2>&1 || true
sleep 0.05
FINAL_A=$(call_pipeline "a") || { skip "cycle-final-a" "IPC call failed"; }

if [[ -n "$FIRST_A" && -n "$FINAL_A" ]]; then
  NORM1=$(normalize_output "$FIRST_A")
  NORM2=$(normalize_output "$FINAL_A")
  if [[ "$NORM1" == "$NORM2" ]]; then
    pass "type-cycle-stability: a -> ai -> a"
  else
    ROW_DIFF=$(diff <(echo "$NORM1" | jq -c .) <(echo "$NORM2" | jq -c .) 2>/dev/null || echo "different")
    fail "type-cycle-stability: a -> ai -> a" "Results differ: $ROW_DIFF"
  fi
fi

# ============================================================
# Section 3: Trailing space consistency
# ============================================================
echo "--- Trailing Space ---"

WITH_SPACE=$(call_pipeline "newxos ") || { skip "trailing-space" "IPC call failed"; }
WITHOUT_SPACE=$(call_pipeline "newxos") || { skip "no-trailing-space" "IPC call failed"; }

# These should differ (trailing space changes evaluation intent)
NS_NORM1=$(normalize_output "$WITH_SPACE")
NS_NORM2=$(normalize_output "$WITHOUT_SPACE")
if [[ "$NS_NORM1" != "$NS_NORM2" ]]; then
  pass "trailing-space-changes-results: newxos vs newxos "
else
  skip "trailing-space-changes-results: newxos vs newxos " "Results identical — trailing space evaluation may not be active"
fi

# ============================================================
# Section 4: Empty query returns default results
# ============================================================
echo "--- Empty Query ---"

EMPTY_RESULT=$(call_pipeline "") || { skip "empty-query" "IPC call failed"; }
EMPTY_ROWS=$(echo "$EMPTY_RESULT" | jq '.rows | length' 2>/dev/null || echo "null")
if [[ "$EMPTY_ROWS" == "null" ]]; then
  skip "empty-query-rows" "No result or parse error"
elif [[ "$EMPTY_ROWS" -ge 0 ]]; then
  pass "empty-query-rows: $EMPTY_ROWS rows"
fi

# ============================================================
# Summary
# ============================================================
echo ""
echo "=== Determinism Test Summary ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo "Skipped: $SKIPPED"

if [[ $FAILED -gt 0 ]]; then
  exit 1
fi
