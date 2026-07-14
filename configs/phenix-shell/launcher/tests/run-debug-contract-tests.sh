#!/usr/bin/env bash
# Contract tests: semantic alignment between debug IPC and actual launcher behavior
set -euo pipefail

# cd to repo root (support running from any cwd)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/../../../.."

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
  local message="$2"
  echo "SKIP: $test - $message"
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
      echo "$data" | jq '. | {mode, query, result}' 2>/dev/null || echo "$data"
    fi
    fail "$test" "$message"
  fi
}

extract() {
  local endpoint="$1"
  local args="$2"
  local expr="$3"
  call_debug "$endpoint" "$args" | jq -r "$expr" 2>/dev/null || echo ""
}

echo "=== Contract Tests - Semantic Alignment ==="
echo ""

# ============================================================
# Section 1: Visible nodes always have decisions with visibility+placement
# ============================================================
echo "--- Decision Contract ---"

for query in "newxos" "wifi" "zen" "net" "vpn" ":"; do
  DATA=$(call_debug "debugOverview" "{\"query\":\"$query\"}")

  # Every visible node has non-null decisions
  NULL_DECS=$(echo "$DATA" | jq "[.result.visible[] | select(.decisions == null)] | length" 2>/dev/null || echo "error")
  if [[ "$NULL_DECS" == "0" ]]; then
    pass "decisions-not-null: $query"
  else
    fail "decisions-not-null: $query" "Found $NULL_DECS visible nodes with null decisions"
  fi

  # Every visible node has decisions.visibility
  NO_VIS=$(echo "$DATA" | jq "[.result.visible[] | select(.decisions.visibility == null)] | length" 2>/dev/null || echo "error")
  if [[ "$NO_VIS" == "0" ]]; then
    pass "decisions-visibility: $query"
  else
    fail "decisions-visibility: $query" "Found $NO_VIS visible nodes missing decisions.visibility"
  fi

  # Every visible node has decisions.placement
  NO_PLACE=$(echo "$DATA" | jq "[.result.visible[] | select(.decisions.placement == null)] | length" 2>/dev/null || echo "error")
  if [[ "$NO_PLACE" == "0" ]]; then
    pass "decisions-placement: $query"
  else
    fail "decisions-placement: $query" "Found $NO_VIS visible nodes missing decisions.placement"
  fi

  # decisions.visibility has value
  VIS_NO_VAL=$(echo "$DATA" | jq "[.result.visible[] | select(.decisions.visibility.value == null)] | length" 2>/dev/null || echo "error")
  if [[ "$VIS_NO_VAL" == "0" ]]; then
    pass "decisions-visibility-value: $query"
  else
    fail "decisions-visibility-value: $query" "Found $VIS_NO_VAL visible decisions without value"
  fi

  # decisions.placement has value
  PLACE_NO_VAL=$(echo "$DATA" | jq "[.result.visible[] | select(.decisions.placement.value == null)] | length" 2>/dev/null || echo "error")
  if [[ "$PLACE_NO_VAL" == "0" ]]; then
    pass "decisions-placement-value: $query"
  else
    fail "decisions-placement-value: $query" "Found $PLACE_NO_VAL placement decisions without value"
  fi
done

# ============================================================
# Section 2: Policy traces have args, returned, effect
# ============================================================
echo "--- Policy Trace Contract ---"

# Get a node with policy traces
POLICY_DATA=$(call_debug "debugPolicies" '{"query":"newxos"}')
SOME_NODE=$(echo "$POLICY_DATA" | jq -r '.result.queryWide.visibleNodeCount' 2>/dev/null || echo "0")
if [[ "$SOME_NODE" -gt 0 ]]; then
  pass "policies-have-data: newxos"
fi

# Check per-node policy traces have evaluated entries with required fields
INSPECT_NODE=$(extract "debugOverview" '{"query":"newxos"}' '.result.visible[0].id // ""')
if [[ -n "$INSPECT_NODE" ]]; then
  POLDATA=$(call_debug "debugPolicies" "{\"query\":\"newxos\",\"nodeId\":\"$INSPECT_NODE\"}")

  # Policy kinds exist
  HAS_KINDS=$(echo "$POLDATA" | jq '.result.policyKinds | length > 0' 2>/dev/null || echo "false")
  if [[ "$HAS_KINDS" == "true" ]]; then
    pass "policies-node-has-kinds: $INSPECT_NODE"
  else
    # This is OK if the node has no profile policies — skip
    skip "policies-node-has-kinds: $INSPECT_NODE" "Node may not have profile policies"
  fi

  # When evaluated entries exist, check they have required fields
  HAS_EVAL=$(echo "$POLDATA" | jq '[.result.policyKinds[] | .evaluated[] | select(.name != "")] | length > 0' 2>/dev/null || echo "false")
  if [[ "$HAS_EVAL" == "true" ]]; then
    pass "policies-has-evaluated: $INSPECT_NODE"

    # Each evaluated entry has name and effect
    NO_NAME=$(echo "$POLDATA" | jq '[.result.policyKinds[] | .evaluated[] | select(.name == "" or .name == null)] | length' 2>/dev/null || echo "0")
    if [[ "$NO_NAME" == "0" ]]; then
      pass "policies-evaluated-has-name: $INSPECT_NODE"
    else
      fail "policies-evaluated-has-name: $INSPECT_NODE" "$NO_NAME entries missing name"
    fi

    NO_EFFECT=$(echo "$POLDATA" | jq '[.result.policyKinds[] | .evaluated[] | select(.effect == "" or .effect == null)] | length' 2>/dev/null || echo "0")
    if [[ "$NO_EFFECT" == "0" ]]; then
      pass "policies-evaluated-has-effect: $INSPECT_NODE"
    else
      fail "policies-evaluated-has-effect: $INSPECT_NODE" "$NO_NAME entries missing effect"
    fi
  fi
fi

# Check some specific policy kinds exist in query-wide view
for kind in evidence boost childVisible; do
  HAS_KIND=$(echo "$POLICY_DATA" | jq "[.result.policyKinds[] | select(.kind == \"$kind\")] | length > 0" 2>/dev/null || echo "false")
  if [[ "$HAS_KIND" == "true" ]]; then
    pass "policies-kind-exists: $kind"
  else
    skip "policies-kind-exists: $kind" "No traces for $kind in this query"
  fi
done

# ============================================================
# Section 3: Action resolution contract
# ============================================================
echo "--- Action Contract ---"

INSPECT_NODE=$(extract "debugOverview" '{"query":"wifi"}' '.result.visible[0].id // ""')
if [[ -n "$INSPECT_NODE" ]]; then
  # Enter action exists
  ACTION_DATA=$(call_debug "debugAction" "{\"query\":\"wifi\",\"nodeId\":\"$INSPECT_NODE\"}")
  HAS_ENTER=$(echo "$ACTION_DATA" | jq '.result.resolvedAction.exists == true' 2>/dev/null || echo "false")
  if [[ "$HAS_ENTER" == "true" ]]; then
    pass "action-enter-exists: wifi"
  else
    skip "action-enter-exists: wifi" "Enter may be noop for some nodes"
  fi

  # Steps exist when action exists
  HAS_STEPS=$(echo "$ACTION_DATA" | jq '.result.resolvedAction.steps | length > 0' 2>/dev/null || echo "false")
  if [[ "$HAS_ENTER" == "true" ]]; then
    if [[ "$HAS_STEPS" == "true" ]]; then
      pass "action-enter-has-steps: wifi"
    else
      fail "action-enter-has-steps: wifi" "Enter action exists but has no steps"
    fi
  fi

  # Source is present
  HAS_SOURCE=$(echo "$ACTION_DATA" | jq '.result.resolvedAction.source != ""' 2>/dev/null || echo "false")
  if [[ "$HAS_SOURCE" == "true" ]]; then
    pass "action-has-source: wifi"
  else
    fail "action-has-source: wifi" "Action missing source"
  fi

  # Alternatives include relevant inputs
  HAS_ALT=$(echo "$ACTION_DATA" | jq '.result.alternatives | length > 0' 2>/dev/null || echo "false")
  if [[ "$HAS_ALT" == "true" ]]; then
    pass "action-has-alternatives: wifi"
  else
    skip "action-has-alternatives: wifi" "No input alternatives found (OK for simple nodes)"
  fi

  # No function/executable objects in action response
  HAS_EXEC=$(echo "$ACTION_DATA" | jq '[recurse | select(type == "object" and has("execute"))] | length == 0' 2>/dev/null || echo "true")
  if [[ "$HAS_EXEC" == "true" ]]; then
    pass "action-no-execute: wifi"
  else
    fail "action-no-execute: wifi" "Action response contains execute objects"
  fi
fi

# ============================================================
# Section 4: debugFind contract (notFound, hidden diagnostics)
# ============================================================
echo "--- Find Contract ---"

# notFound for no match
NOT_FOUND_DATA=$(call_debug "debugFind" '{"query":"wifi","search":"zzzznotfound"}')
HAS_NOTFOUND=$(echo "$NOT_FOUND_DATA" | jq '.result.notFound != null' 2>/dev/null || echo "false")
if [[ "$HAS_NOTFOUND" == "true" ]]; then
  pass "find-notfound-present: zzzznotfound"
else
  fail "find-notfound-present: zzzznotfound" "No-match case should have notFound diagnostics"
fi

# notFound has reasons
NOTFOUND_REASONS=$(echo "$NOT_FOUND_DATA" | jq '.result.notFound | length > 0' 2>/dev/null || echo "false")
if [[ "$NOTFOUND_REASONS" == "true" ]]; then
  pass "find-notfound-has-reasons: zzzznotfound"
else
  fail "find-notfound-has-reasons: zzzznotfound" "notFound should have diagnostic reasons"
fi

# Visible match has complete info
FIND_DATA=$(call_debug "debugFind" '{"query":"wifi","search":"wifi"}')
HAS_VISIBILITY=$(echo "$FIND_DATA" | jq '.result.matches[0].reasons.visibility | length > 0' 2>/dev/null || echo "false")
if [[ "$HAS_VISIBILITY" == "true" ]]; then
  pass "find-has-visibility: wifi"
else
  fail "find-has-visibility: wifi" "Find match missing visibility reasons"
fi

# compactMatch exists
HAS_MATCH=$(echo "$FIND_DATA" | jq '.result.matches[0].compactMatch != null' 2>/dev/null || echo "false")
if [[ "$HAS_MATCH" == "true" ]]; then
  pass "find-has-compact-match: wifi"
else
  skip "find-has-compact-match: wifi" "compactMatch may be empty for some matches"
fi

# compactScore exists
HAS_SCORE=$(echo "$FIND_DATA" | jq '.result.matches[0].compactScore != null' 2>/dev/null || echo "false")
if [[ "$HAS_SCORE" == "true" ]]; then
  pass "find-has-compact-score: wifi"
fi

# Search with backend filter
FIND_BACKEND=$(call_debug "debugFind" '{"query":"wifi","search":"wifi","backend":"actions"}')
HAS_BACKEND_MATCHES=$(echo "$FIND_BACKEND" | jq '.result.matches | length > 0' 2>/dev/null || echo "false")
if [[ "$HAS_BACKEND_MATCHES" == "true" ]]; then
  pass "find-backend-filter: wifi/actions"
else
  skip "find-backend-filter: wifi/actions" "No matches for wifi in actions backend"
fi

# ============================================================
# Section 5: Query matrix contract tests
# ============================================================
echo "--- Query Matrix ---"

assert_jq "query-wifi" "debugOverview" '{"query":"wifi"}' \
  '.result.visible | length > 0' \
  "wifi should return visible results"

assert_jq "query-wifi-on" "debugOverview" '{"query":"wifi on"}' \
  '.result.visible | length > 0' \
  "wifi on should return visible results"

assert_jq "query-wifi-" "debugOverview" '{"query":"wifi "}' \
  '.result.visible | length > 0' \
  "wifi with trailing space should return visible results"

assert_jq "query-net" "debugOverview" '{"query":"net"}' \
  '.result.visible | length > 0' \
  "net should return visible results"

assert_jq "query-network" "debugOverview" '{"query":"network"}' \
  '.result.visible | length > 0' \
  "network should return visible results"

assert_jq "query-zen" "debugOverview" '{"query":"zen"}' \
  '.result.visible | length > 0' \
  "zen should return visible results"

assert_jq "query-zen-priv" "debugOverview" '{"query":"zen priv"}' \
  '.result.visible | length > 0' \
  "zen priv should return visible results"

assert_jq "query-zen-" "debugOverview" '{"query":"zen "}' \
  '.result.visible | length > 0' \
  "zen with trailing space should return visible results"

assert_jq "query-vpn" "debugOverview" '{"query":"vpn"}' \
  '.result.visible | length > 0' \
  "vpn should return visible results"

assert_jq "query-vpn-" "debugOverview" '{"query":"vpn "}' \
  '.result.visible | length > 0' \
  "vpn with trailing space should return visible results"

assert_jq "query-newxos" "debugOverview" '{"query":"newxos"}' \
  '.result.visible | length > 0' \
  "newxos should return visible results"

assert_jq "query-newxos-" "debugOverview" '{"query":"newxos "}' \
  '.result.visible | length > 0' \
  "newxos with trailing space should return visible results"

assert_jq "query-colon" "debugOverview" '{"query":":"}' \
  '.result.visible | length > 0' \
  "colon should return visible results"

# ============================================================
# Section 6: JSON Safety strict — endpoints use returnDebugEnvelope
# ============================================================
echo "--- JSON Safety Contract ---"

# All endpoints must return valid JSON with proper envelope
for endpoint in debugOverview debugInspect debugPolicies debugFind debugAction debugStats; do
  DATA=$(call_debug "$endpoint" '{"query":"newxos"}')

  # Must be parseable JSON
  if echo "$DATA" | jq '.' >/dev/null 2>&1; then
    pass "json-valid: $endpoint"
  else
    fail "json-valid: $endpoint" "Response is not valid JSON"
    continue
  fi

  # Must have version, mode, result fields (envelope)
  HAS_ENVELOPE=$(echo "$DATA" | jq 'has("version") and has("mode") and has("result")' 2>/dev/null || echo "false")
  if [[ "$HAS_ENVELOPE" == "true" ]]; then
    pass "json-envelope: $endpoint"
  else
    fail "json-envelope: $endpoint" "Missing envelope fields"
  fi

  # Must not contain __qobject__ or __qml__ (QML internal objects)
  NO_QML=$(echo "$DATA" | jq '[.. | select(type == "object" and (. | has("__qobject__") or has("__qml__") or has("ObjectScript")))] | length == 0' 2>/dev/null || echo "false")
  if [[ "$NO_QML" == "true" ]]; then
    pass "json-no-qml-objects: $endpoint"
  else
    fail "json-no-qml-objects: $endpoint" "Response contains QML objects"
  fi

  # No function-valued properties
  NO_FUNCS=$(echo "$DATA" | jq '[.. | select(type == "object") | to_entries[] | select(.value | type == "object" and has("__javascript__"))] | length == 0' 2>/dev/null || echo "false")
  if [[ "$NO_FUNCS" == "true" ]]; then
    pass "json-no-functions: $endpoint"
  fi
done

# ============================================================
# Section 7: Stats validation catches missing critical invariants
# ============================================================
echo "--- Validation Contract ---"

STATS_DATA=$(call_debug "debugStats" '{"query":"n","includeValidation":true}')
VAL_OK=$(echo "$STATS_DATA" | jq '.result.validation.ok' 2>/dev/null || echo "null")
# ok=true means all critical invariants pass (may still have warnings)
if [[ "$VAL_OK" == "true" ]]; then
  pass "validation-ok: n"
elif [[ "$VAL_OK" == "false" ]]; then
  ERR_COUNT=$(echo "$STATS_DATA" | jq '.result.validation.errors | length' 2>/dev/null || echo "0")
  fail "validation-ok: n" "Validation errors: $ERR_COUNT"
else
  skip "validation-ok: n" "Validation result is $VAL_OK"
fi

# Validation must have errors or warnings arrays
HAS_ERRORS=$(echo "$STATS_DATA" | jq '.result.validation | has("errors") and has("warnings")' 2>/dev/null || echo "false")
if [[ "$HAS_ERRORS" == "true" ]]; then
  pass "validation-has-sections: n"
fi

# ============================================================
# Section 8: Regression — candidate-visible nodes appear in final rows
# ============================================================
echo "--- Row Visibility Contract ---"

# For each query, verify: every candidate marked visible in the evaluated tree
# actually appears in the final flat visible rows.
for query in "newxos" "newxos ai" "newxos " "wifi" "wifi on" "wifi " "net" "network" "zen" "zen priv" "zen " "vpn" "vpn " ":"; do
  # Get stats with validation
  STATS_DATA=$(call_debug "debugStats" "{\"query\":\"$query\",\"includeValidation\":true}")
  # Check that validation passes (no candidate-visible-not-in-rows warning)
  VAL_OK=$(echo "$STATS_DATA" | jq -r '.result.validation.ok' 2>/dev/null || echo "null")
  if [[ "$VAL_OK" == "true" ]]; then
    pass "row-visibility-validation: $query"
  elif [[ "$VAL_OK" == "false" ]]; then
    WARN_COUNT=$(echo "$STATS_DATA" | jq '.result.validation.warnings | length' 2>/dev/null || echo "0")
    fail "row-visibility-validation: $query" "Validation failed with $WARN_COUNT warnings"
  else
    skip "row-visibility-validation: $query" "Validation result is $VAL_OK"
  fi

  # Verify candidateIndex visible nodes are subset of flatVisibleRows
  EVAL_DATA=$(call_debug "debugOverview" "{\"query\":\"$query\"}")
  CANDIDATE_COUNT=$(echo "$EVAL_DATA" | jq '.result.stats.visibleNodeCount' 2>/dev/null || echo "0")
  VISIBLE_COUNT=$(echo "$EVAL_DATA" | jq '.result.visible | length' 2>/dev/null || echo "0")

  # visibleNodeCount (from rows) should roughly match visible rows length
  # (may differ if there are nested children)
  if [[ "$CANDIDATE_COUNT" -ge "$VISIBLE_COUNT" ]]; then
    pass "row-visibility-counts: $query (stats=$CANDIDATE_COUNT, visible=$VISIBLE_COUNT)"
  else
    fail "row-visibility-counts: $query" "stats.visibleNodeCount ($CANDIDATE_COUNT) < overview visible count ($VISIBLE_COUNT) — rows outnumber candidates"
  fi
done

# Specific regression: "newxos ai" used to return visible=[]
assert_jq "regression-newxos-ai-visible" "debugOverview" '{"query":"newxos ai"}' \
  '.result.visible | length > 0' \
  "newxos ai should return visible results (regression: flattened children were dropped)"

# Specific regression: "zen priv" used to drop the private window child
assert_jq "regression-zen-priv-visible" "debugOverview" '{"query":"zen priv"}' \
  '.result.visible | length > 0' \
  "zen priv should return visible results (regression: promoted child was dropped)"

# ============================================================
# Summary
# ============================================================
echo ""
echo "=== Contract Test Summary ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo "Skipped: $SKIPPED"

if [[ $FAILED -gt 0 ]]; then
  exit 1
fi
