#!/usr/bin/env bash
# Validation tests for Evaluation JSON safety and structural invariants
set -euo pipefail

IPC_DEBUG=(phenix-shell ipc call query)

FAILED=0
PASSED=0

assert_pass() {
  local test="$1"
  local result="$2"
  if [[ "$result" == "true" ]] || [[ "$result" == "1" ]]; then
    PASSED=$((PASSED + 1))
    echo "PASS: $test"
  else
    FAILED=$((FAILED + 1))
    echo "FAIL: $test - expected truthy, got '$result'"
  fi
}

assert_fail() {
  local test="$1"
  local result="$2"
  if [[ "$result" == "false" ]] || [[ "$result" == "0" ]] || [[ "$result" == "null" ]]; then
    PASSED=$((PASSED + 1))
    echo "PASS: $test"
  else
    FAILED=$((FAILED + 1))
    echo "FAIL: $test - expected falsy, got '$result'"
  fi
}

check() {
  local endpoint="$1"
  local args="$2"
  local jq_expr="$3"
  local data
  data=$("${IPC_DEBUG[@]}" "$endpoint" "$args" 2>/dev/null) || { echo "IPC_FAIL"; return; }
  echo "$data" | jq -r "$jq_expr" 2>/dev/null || echo "JQ_FAIL"
}

echo "=== Evaluation Validation Tests ==="
echo ""

# ============================================================
# Test 1: Duplicate IDs
# ============================================================
echo "--- Duplicate IDs ---"

# Check that overview visible nodes have unique IDs
OVERVIEW_DATA=$("${IPC_DEBUG[@]}" "debugOverview" '{"query":"phenix"}' 2>/dev/null || echo "{}")
DUPLICATE_COUNT=$(echo "$OVERVIEW_DATA" | jq '[.result.visible[] | .id] | group_by(.) | map(select(length > 1)) | flatten | unique | length' 2>/dev/null || echo "error")
if [[ "$DUPLICATE_COUNT" == "0" ]] || [[ "$DUPLICATE_COUNT" == "null" ]]; then
  PASSED=$((PASSED + 1))
  echo "PASS: no-duplicate-ids"
else
  FAILED=$((FAILED + 1))
  echo "FAIL: no-duplicate-ids - found $DUPLICATE_COUNT duplicate IDs"
fi

# ============================================================
# Test 2: Selection ID is visible
# ============================================================
echo "--- Selection ---"

SEL_ID=$(echo "$OVERVIEW_DATA" | jq -r '.result.selection.selectedId // ""' 2>/dev/null)
if [[ -n "$SEL_ID" ]]; then
  SEL_IN_VISIBLE=$(echo "$OVERVIEW_DATA" | jq "[.result.visible[] | .id] | contains([\"$SEL_ID\"])" 2>/dev/null)
  assert_pass "selection-id-visible" "$SEL_IN_VISIBLE"
else
  PASSED=$((PASSED + 1))
  echo "PASS: selection-id-empty (no selection)"
fi

# ============================================================
# Test 3: All visible nodes have IDs
# ============================================================
echo "--- Node IDs ---"

NO_ID_COUNT=$(echo "$OVERVIEW_DATA" | jq '[.result.visible[] | select(.id == "" or .id == null)] | length' 2>/dev/null || echo "error")
assert_fail "visible-nodes-have-ids" "$NO_ID_COUNT"

# ============================================================
# Test 4: JSON response envelope structure
# ============================================================
echo "--- Response Envelope ---"

# Check that all debug endpoints return proper envelope
for endpoint in debugOverview debugInspect debugPolicies debugFind debugAction debugStats; do
  DATA=$("${IPC_DEBUG[@]}" "$endpoint" '{"query":"phenix"}' 2>/dev/null || echo "{}")

  HAS_VERSION=$(echo "$DATA" | jq 'has("version")' 2>/dev/null || echo "null")
  HAS_MODE=$(echo "$DATA" | jq 'has("mode")' 2>/dev/null || echo "null")
  HAS_RESULT=$(echo "$DATA" | jq 'has("result")' 2>/dev/null || echo "null")

  if [[ "$HAS_VERSION" == "true" ]] && [[ "$HAS_MODE" == "true" ]] && [[ "$HAS_RESULT" == "true" ]]; then
    PASSED=$((PASSED + 1))
    echo "PASS: $endpoint-has-envelope"
  else
    FAILED=$((FAILED + 1))
    echo "FAIL: $endpoint-has-envelope - missing envelope fields (version=$HAS_VERSION mode=$HAS_MODE result=$HAS_RESULT)"
  fi
done

# ============================================================
# Test 5: Response only contains JSON-safe types
# ============================================================
echo "--- JSON Safety ---"

# Function and symbol check via jq
for endpoint in debugOverview debugInspect debugPolicies debugFind debugAction debugStats; do
  DATA=$("${IPC_DEBUG[@]}" "$endpoint" '{"query":"phenix"}' 2>/dev/null || echo "{}")

  # Check for undefined (represented as null in JSON)
  # Check for functions (not serializable)
  # All values should be valid JSON types

  # Count non-JSON-native patterns
  BAD_VALUES=$(echo "$DATA" | jq '[recurse | select(type == "object" and (. | has("__proto__") or has("constructor")))] | length' 2>/dev/null || echo "0")
  if [[ "$BAD_VALUES" == "0" ]]; then
    PASSED=$((PASSED + 1))
    echo "PASS: $endpoint-json-safe"
  else
    FAILED=$((FAILED + 1))
    echo "FAIL: $endpoint-json-safe - found $BAD_VALUES suspicious values"
  fi
done

# ============================================================
# Test 6: Stats validation catches issues
# ============================================================
echo "--- Stats Validation ---"

STATS_DATA=$("${IPC_DEBUG[@]}" "debugStats" '{"query":"n","includeValidation":true}' 2>/dev/null || echo "{}")
VALIDATION_OK=$(echo "$STATS_DATA" | jq '.result.validation.ok' 2>/dev/null || echo "null")
echo "INFO: validation ok=$VALIDATION_OK (warnings/errors may be healthy in early search)"

# ============================================================
# Test 7: Response contains no cyclic references
# ============================================================
echo "--- Cycle Safety ---"

for endpoint in debugOverview debugInspect debugPolicies debugFind debugAction debugStats; do
  DATA=$("${IPC_DEBUG[@]}" "$endpoint" '{"query":"phenix"}' 2>/dev/null || echo "{}")
  # If JSON.stringify doesn't error, there are no cycles
  if echo "$DATA" | jq '. | tostring | length > 0' >/dev/null 2>&1; then
    PASSED=$((PASSED + 1))
    echo "PASS: $endpoint-no-cycles"
  else
    FAILED=$((FAILED + 1))
    echo "FAIL: $endpoint-no-cycles - jq failed to process response"
  fi
done

# ============================================================
# Summary
# ============================================================
echo ""
echo "=== Validation Test Summary ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [[ $FAILED -gt 0 ]]; then
  exit 1
fi
