#!/usr/bin/env bash
# Test suite for Evaluation-based debug IPC endpoints
set -euo pipefail

LAUNCHER_IPC=(newshell ipc call query)
VERBOSE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose|-v) VERBOSE=true; shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

FAILED=0
PASSED=0
SKIPPED=0

call_debug() {
  local endpoint="$1"
  local args="$2"
  "${LAUNCHER_IPC[@]}" "$endpoint" "$args" 2>/dev/null || echo '{"error":"IPC call failed"}'
}

fail() {
  local test="$1"
  local message="$2"
  echo "FAIL: $test - $message"
  FAILED=$((FAILED + 1))
}

pass() {
  local test="$1"
  PASSED=$((PASSED + 1))
  if $VERBOSE; then echo "OK: $test"; fi
}

skip() {
  local test="$1"
  local reason="$2"
  echo "SKIP: $test - $reason"
  SKIPPED=$((SKIPPED + 1))
}

assert_jq() {
  local test="$1"
  local endpoint="$2"
  local args="$3"
  local expr="$4"
  local message="$5"
  local data
  data=$(call_debug "$endpoint" "$args") || { fail "$test" "IPC call failed"; return; }
  if echo "$data" | jq -e "$expr" >/dev/null 2>&1; then
    pass "$test"
  else
    if $VERBOSE; then
      echo "$data" | jq '.mode as $mode | {mode, query, evaluationId, source, result, warnings}' 2>/dev/null || echo "$data"
    fi
    fail "$test" "$message"
  fi
}

assert_json_safe() {
  local test="$1"
  local endpoint="$2"
  local args="$3"
  local data
  data=$(call_debug "$endpoint" "$args") || { fail "$test" "IPC call failed"; return; }
  # Verify it can be round-tripped through JSON
  if echo "$data" | jq '.' >/dev/null 2>&1; then
    pass "$test"
  else
    fail "$test" "Response is not valid JSON"
  fi
}

echo "=== Debug IPC V2 Test Suite ==="
echo ""

# ============================================================
# Section 1: debugOverview tests
# ============================================================
echo "--- debugOverview ---"

# 1.1 Overview returns envelope with version, mode, query
assert_jq "overview-envelope" "debugOverview" '{"query":"newxos"}' \
  '.version == 1 and .mode == "overview" and .query == "newxos"' \
  "Response envelope should have version=1, mode=overview"

# 1.2 Overview returns backendSummary
assert_jq "overview-backends" "debugOverview" '{"query":"newxos"}' \
  '.result.backendSummary | length > 0' \
  "Overview should include backendSummary"

# 1.3 Overview returns visible array
assert_jq "overview-visible" "debugOverview" '{"query":"newxos"}' \
  '.result.visible | length > 0' \
  "Overview should include visible rows"

# 1.4 Overview nodes have required fields
assert_jq "overview-node-fields" "debugOverview" '{"query":"newxos"}' \
  '.result.visible[0].id != "" and .result.visible[0].title != ""' \
  "Visible nodes should have id and title"

# 1.5 Overview node has placement
assert_jq "overview-placement" "debugOverview" '{"query":"newxos"}' \
  '.result.visible[0].placement != ""' \
  "Visible nodes should have placement"

# 1.6 Overview includes selection
assert_jq "overview-selection" "debugOverview" '{"query":"newxos"}' \
  '.result.selection != null' \
  "Overview should include selection"

# 1.7 Overview includes stats
assert_jq "overview-stats" "debugOverview" '{"query":"newxos"}' \
  '.result.stats.visibleNodeCount > 0' \
  "Overview should include stats with visibleNodeCount"

# 1.8 Overview for "zen priv" shows private window
assert_jq "overview-zen-priv" "debugOverview" '{"query":"zen priv"}' \
  '.result.visible | length > 0' \
  "zen priv should return visible results"

# 1.9 Overview for "vpn " shows results
assert_jq "overview-vpn" "debugOverview" '{"query":"vpn "}' \
  '.result.visible | length > 0' \
  "vpn should return visible results"

# ============================================================
# Section 2: debugInspect tests
# ============================================================
echo "--- debugInspect ---"

# 2.1 Inspect returns error for missing nodeId
assert_jq "inspect-no-nodeid" "debugInspect" '{"query":"newxos"}' \
  '.result.error.code == "no_node_id"' \
  "Inspect without nodeId should return error"

# 2.2 Inspect returns node info for valid nodeId
# Use debugOverview to find a node id first, then test inspect
INSPECT_NODE_ID=$(call_debug "debugOverview" '{"query":"newxos"}' | jq -r '.result.visible[0].id // "actions:newxos"')
assert_jq "inspect-node" "debugInspect" "{\"query\":\"newxos\",\"nodeId\":\"$INSPECT_NODE_ID\"}" \
  '.result.node.id != "" and .result.node.title != ""' \
  "Inspect should return node id and title for valid nodeId"

# 2.3 Inspect includes searchable fields
assert_jq "inspect-fields" "debugInspect" "{\"query\":\"newxos\",\"nodeId\":\"$INSPECT_NODE_ID\"}" \
  '.result.searchable != null' \
  "Inspect should include searchable fields"

# 2.4 Inspect includes matching info
assert_jq "inspect-matching" "debugInspect" "{\"query\":\"newxos\",\"nodeId\":\"$INSPECT_NODE_ID\"}" \
  '.result.matching != null' \
  "Inspect should include matching info"

# 2.5 Inspect includes scoring
assert_jq "inspect-scoring" "debugInspect" "{\"query\":\"newxos\",\"nodeId\":\"$INSPECT_NODE_ID\"}" \
  '.result.scoring != null' \
  "Inspect should include scoring"

# 2.6 Inspect includes decisions
assert_jq "inspect-decisions" "debugInspect" "{\"query\":\"newxos\",\"nodeId\":\"$INSPECT_NODE_ID\"}" \
  '.result.decisions != null' \
  "Inspect should include decisions"

# 2.7 Inspect includes childrenSummary
assert_jq "inspect-children" "debugInspect" "{\"query\":\"newxos\",\"nodeId\":\"$INSPECT_NODE_ID\"}" \
  '.result.childrenSummary != null' \
  "Inspect should include childrenSummary"

# ============================================================
# Section 3: debugPolicies tests
# ============================================================
echo "--- debugPolicies ---"

# 3.1 Policies returns scope
assert_jq "policies-scope" "debugPolicies" '{"query":"newxos"}' \
  '.result.scope == "query"' \
  "Policies without nodeId should return query scope"

# 3.2 Policies with nodeId returns node scope
assert_jq "policies-node-scope" "debugPolicies" "{\"query\":\"newxos\",\"nodeId\":\"$INSPECT_NODE_ID\"}" \
  '.result.scope == "node"' \
  "Policies with nodeId should return node scope"

# 3.3 Policies node scope includes node info
assert_jq "policies-node-info" "debugPolicies" "{\"query\":\"newxos\",\"nodeId\":\"$INSPECT_NODE_ID\"}" \
  '.result.node.id != ""' \
  "Policy node scope should include node info"

# ============================================================
# Section 4: debugFind tests
# ============================================================
echo "--- debugFind ---"

# 4.1 Find returns error for missing search
assert_jq "find-no-search" "debugFind" '{"query":"newxos"}' \
  '.result.error.code == "no_search"' \
  "Find without search should return error"

# 4.2 Find returns matches
assert_jq "find-matches" "debugFind" '{"query":"newxos","search":"newxos"}' \
  '.result.matches | length > 0' \
  "Find should return matches"

# 4.3 Find matches have required fields
assert_jq "find-match-fields" "debugFind" '{"query":"newxos","search":"newxos"}' \
  '.result.matches[0].id != "" and .result.matches[0].title != ""' \
  "Find matches should have id and title"

# 4.4 Find shows visibility info
assert_jq "find-visibility" "debugFind" '{"query":"newxos","search":"newxos"}' \
  '.result.matches[0].reasons.visibility | length > 0' \
  "Find matches should include visibility reasons"

# 4.5 Find matches are inspectable
assert_jq "find-inspectable" "debugFind" '{"query":"newxos","search":"newxos"}' \
  '.result.matches[0].inspectable == true' \
  "Find matches should be inspectable"

# ============================================================
# Section 5: debugAction tests
# ============================================================
echo "--- debugAction ---"

# 5.1 Action returns error for missing nodeId
assert_jq "action-no-nodeid" "debugAction" '{"query":"newxos"}' \
  '.result.error.code == "no_node_id"' \
  "Action without nodeId should return error"

# 5.2 Action returns node info
assert_jq "action-node" "debugAction" "{\"query\":\"newxos\",\"nodeId\":\"$INSPECT_NODE_ID\"}" \
  '.result.node.id != "" and .result.node.title != ""' \
  "Action should return node id and title"

# 5.3 Action returns input
assert_jq "action-input" "debugAction" "{\"query\":\"newxos\",\"nodeId\":\"$INSPECT_NODE_ID\"}" \
  '.result.input == "enter"' \
  "Action should default to enter input"

# 5.4 Action returns resolvedAction
assert_jq "action-resolved" "debugAction" "{\"query\":\"newxos\",\"nodeId\":\"$INSPECT_NODE_ID\"}" \
  '.result.resolvedAction != null' \
  "Action should include resolvedAction"

# ============================================================
# Section 6: debugStats tests
# ============================================================
echo "--- debugStats ---"

# 6.1 Stats returns total
assert_jq "stats-total" "debugStats" '{"query":"n"}' \
  '.result.total.backendCount > 0' \
  "Stats should include total with backendCount"

# 6.2 Stats includes backend details
assert_jq "stats-backends" "debugStats" '{"query":"n"}' \
  '.result.backends | length > 0' \
  "Stats should include backend details"

# 6.3 Stats includes validation
assert_jq "stats-validation" "debugStats" '{"query":"n"}' \
  '.result.validation != null' \
  "Stats should include validation"

# ============================================================
# Section 7: JSON safety tests
# ============================================================
echo "--- JSON safety ---"

# 7.1 All responses are valid JSON
for endpoint in debugOverview debugInspect debugPolicies debugFind debugAction debugStats; do
  assert_json_safe "$endpoint-json-safe" "$endpoint" '{"query":"newxos"}'
done

# 7.2 Response only uses JSON-native types
for endpoint in debugOverview debugInspect debugPolicies debugFind debugAction debugStats; do
  data=$(call_debug "$endpoint" '{"query":"newxos"}')
  if echo "$data" | jq '[.. | select(type == "object" and (. | has("__qobject__") or has("__qml__")))] | length == 0' | grep -q true; then
    pass "$endpoint-no-qml"
  else
    fail "$endpoint-no-qml" "Response contains QML/Qt objects"
  fi
done

# 7.3 Response round-trips through JSON
for endpoint in debugOverview debugInspect debugPolicies debugFind debugAction debugStats; do
  data=$(call_debug "$endpoint" '{"query":"newxos"}')
  if echo "$data" | jq '.' | jq '.' >/dev/null 2>&1; then
    pass "$endpoint-roundtrip"
  else
    fail "$endpoint-roundtrip" "Response does not round-trip through JSON"
  fi
done

# ============================================================
# Summary
# ============================================================
echo ""
echo "=== Debug IPC V2 Test Summary ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo "Skipped: $SKIPPED"

if [[ $FAILED -gt 0 ]]; then
  exit 1
fi
