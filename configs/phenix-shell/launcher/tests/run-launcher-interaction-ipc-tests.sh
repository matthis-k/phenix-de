#!/usr/bin/env bash
# Semantic launcher interaction IPC test suite.
# Supports three instance ownership modes:
#   self-managed (default): script launches and kills newshell
#   external:              newshell is started externally (e.g. by Hyprland)
#                          requires NEWSHELL_TEST_INSTANCE_ID + NEWSHELL_IPC_NAMESPACE
#   session:               test against the currently running user service
#                          uses global IPC targets
# Never touches global launcher/query targets in self-managed or external modes.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
cd "$REPO_ROOT"

INSTANCE_MODE="${NEWSHELL_TEST_INSTANCE_MODE:-self-managed}"
INSTANCE_ID="${NEWSHELL_TEST_INSTANCE_ID:-newshell-test-$$-${RANDOM}}"
IPC_NS="${NEWSHELL_IPC_NAMESPACE:-$INSTANCE_ID}"
LOG_DIR="${TMPDIR:-/tmp}/newxos-newshell-tests"
LOG_FILE="$LOG_DIR/$INSTANCE_ID.log"
mkdir -p "$LOG_DIR"

NEWSHELL_BIN="${NEWSHELL_BIN:-newshell}"

FAILED=0
PASSED=0
VERBOSE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose|-v) VERBOSE=true; shift ;;
    *) echo "Usage: $0 [--verbose|-v]" >&2; exit 2 ;;
  esac
done

cleanup() {
  if [[ "${INSTANCE_MODE}" = "self-managed" ]] && [[ -n "${NEWSHELL_PID:-}" ]] && kill -0 "$NEWSHELL_PID" 2>/dev/null; then
    kill "$NEWSHELL_PID" 2>/dev/null || true
    wait "$NEWSHELL_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

case "$INSTANCE_MODE" in
  self-managed)
    export NEWSHELL_TEST_MODE=1
    export NEWSHELL_TEST_INSTANCE_ID="$INSTANCE_ID"
    export NEWSHELL_IPC_NAMESPACE="$IPC_NS"
    export NEWXOS_DEV="${NEWXOS_DEV:-1}"
    export NEWXOS_FLAKE="$REPO_ROOT"

    echo "=== Launcher Interaction IPC Test Suite ==="
    echo "Mode: self-managed"
    echo "Instance ID: $INSTANCE_ID"
    echo "IPC namespace: $IPC_NS"
    echo "Log: $LOG_FILE"
    echo ""

    "$NEWSHELL_BIN" >"$LOG_FILE" 2>&1 &
    NEWSHELL_PID=$!
    ;;
  external)
    if [ -z "$NEWSHELL_TEST_INSTANCE_ID" ]; then
      echo "error: external mode requires NEWSHELL_TEST_INSTANCE_ID" >&2
      exit 2
    fi
    if [ -z "$NEWSHELL_IPC_NAMESPACE" ]; then
      echo "error: external mode requires NEWSHELL_IPC_NAMESPACE" >&2
      exit 2
    fi
    echo "=== Launcher Interaction IPC Test Suite ==="
    echo "Mode: external (using externally managed newshell)"
    echo "Instance ID: $INSTANCE_ID"
    echo "IPC namespace: $IPC_NS"
    echo ""
    NEWSHELL_PID=""
    ;;
  session)
    echo "=== Launcher Interaction IPC Test Suite ==="
    echo "Mode: session (testing running service — not isolated, not CI-safe)"
    if [ "''${NEWSHELL_TEST_ALLOW_ACTIONS:-0}" = "1" ]; then
      echo "  NEWSHELL_TEST_ALLOW_ACTIONS=1: mutating tests will run (activateSelected, open/close/toggle, etc.)"
    fi
    echo ""
    NEWSHELL_PID=""
    ;;
  *)
    echo "error: unknown NEWSHELL_TEST_INSTANCE_MODE=$INSTANCE_MODE" >&2
    exit 2
    ;;
esac

# IPC wrappers — use namespaced targets in self-managed/external, global in session
if [ "$INSTANCE_MODE" = "session" ]; then
  ipc_launcher() { "$NEWSHELL_BIN" ipc call launcher "$@"; }
  ipc_query()    { "$NEWSHELL_BIN" ipc call query "$@"; }
  IPC_TARGET_DESC="global launcher/query via $NEWSHELL_BIN"
else
  ipc_launcher() { "$NEWSHELL_BIN" ipc call "$IPC_NS.launcher" "$@"; }
  ipc_query()    { "$NEWSHELL_BIN" ipc call "$IPC_NS.query" "$@"; }
  IPC_TARGET_DESC="namespaced $IPC_NS.launcher/$IPC_NS.query"
fi

wait_for_instance() {
  local tries="${1:-100}"

  if [ "$INSTANCE_MODE" = "session" ]; then
    # In session mode, just check if the global launcher responds
    local data
    data="$(ipc_launcher state 2>/dev/null || true)"
    if echo "$data" | jq -e '.version == 1' >/dev/null 2>&1; then
      return 0
    fi
    echo "error: no running newshell service found" >&2
    return 1
  fi

  for _ in $(seq 1 "$tries"); do
    if [[ -n "${NEWSHELL_PID:-}" ]] && ! kill -0 "$NEWSHELL_PID" 2>/dev/null; then
      echo "error: spawned newshell exited early" >&2
      cat "$LOG_FILE" >&2 || true
      return 1
    fi

    local data
    data="$(ipc_launcher interactJson '{"action":"state"}' 2>/dev/null || true)"
    if echo "$data" | jq -e \
      --arg id "$INSTANCE_ID" \
      --arg ns "$IPC_NS" \
      '.ok == true and .after.testMode == true and .after.testInstanceId == $id and .after.ipcNamespace == $ns' \
      >/dev/null 2>&1; then
      return 0
    fi

    sleep 0.05
  done

  echo "error: test newshell instance did not become reachable via $IPC_TARGET_DESC" >&2
  if [ "$INSTANCE_MODE" = "self-managed" ]; then
    cat "$LOG_FILE" >&2 || true
  fi
  return 1
}

echo "--- Instance readiness ---"
wait_for_instance || exit 1
echo "OK: instance ready"

call_interact()   { ipc_launcher interactJson "$1"; }
state()           { ipc_launcher state; }
fail()            { echo "FAIL: $1 - $2"; FAILED=$((FAILED + 1)); }
pass()            { PASSED=$((PASSED + 1)); $VERBOSE && echo "OK: $1"; }

# assert_jq_data name data [jq args...] message
# Supports optional --arg etc. before the jq expression.
# The last positional arg is always the failure message.
assert_jq_data() {
  local name="$1" data="$2"
  shift 2
  local msg="${*: -1}"
  set -- "${@:1:$(($#-1))}"
  if echo "$data" | jq -e "$@" >/dev/null 2>&1; then
    pass "$name"
  else
    $VERBOSE && echo "$data" | jq '.' 2>/dev/null || true
    fail "$name" "$msg"
  fi
}

wait_for_query() {
  local expected="$1" tries="${2:-20}"
  for _ in $(seq 1 "$tries"); do
    local s
    s=$(state || true)
    if echo "$s" | jq -e --arg q "$expected" '.query == $q or .inputText == $q' >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.05
  done
  return 1
}

echo ""
echo "--- IPC envelope and launch identity ---"

data="$(state)"
if [ "$INSTANCE_MODE" = "session" ]; then
  assert_jq_data "session-state-shape" "$data" \
    '.version == 1 and .type == "launcherInteractionState"' \
    "session state should return launcher interaction state"
  echo "(session mode: skipping testMode/testInstanceId/ipcNamespace identity assertions)"
else
  assert_jq_data "response-test-mode" "$data" \
    '.testMode == true' \
    "state should have testMode true"

  assert_jq_data "response-test-instance-id" "$data" \
    --arg id "$INSTANCE_ID" '.testInstanceId == $id' \
    "state should have matching testInstanceId"

  assert_jq_data "response-ipc-namespace" "$data" \
    --arg ns "$IPC_NS" '.ipcNamespace == $ns' \
    "state should have matching ipcNamespace"
fi

data=$(call_interact '{"action":"state"}')
assert_jq_data "state-envelope" "$data" \
  '.version == 1 and .ok == true and .after.type == "launcherInteractionState"' \
  "state action should return state envelope"

if [ "$INSTANCE_MODE" = "session" ]; then
  echo "(session mode: skipping testMode/testInstanceId/ipcNamespace envelope assertions)"
else
  assert_jq_data "state-envelope-test-mode" "$data" \
    '.after.testMode == true' \
    "state envelope should have testMode"

  assert_jq_data "state-envelope-instance-id" "$data" \
    --arg id "$INSTANCE_ID" '.after.testInstanceId == $id' \
    "state envelope should have matching instance ID"

  assert_jq_data "state-envelope-namespace" "$data" \
    --arg ns "$IPC_NS" '.after.ipcNamespace == $ns' \
    "state envelope should have matching IPC namespace"
fi

if [ "$INSTANCE_MODE" = "session" ] && [ "''${NEWSHELL_TEST_ALLOW_ACTIONS:-0}" != "1" ]; then
  echo "(session mode: skipping open/close/toggle — would change running service launcher visibility)"
else
  data=$(call_interact '{"action":"open"}')
  assert_jq_data "open" "$data" \
    '.ok == true' \
    "open should return ok"

  data=$(call_interact '{"action":"close"}')
  assert_jq_data "close" "$data" \
    '.ok == true' \
    "close should return ok"

  data=$(call_interact '{"action":"toggle"}')
  assert_jq_data "toggle" "$data" \
    '.ok == true' \
    "toggle should return ok"
fi

echo ""
echo "--- Query interactions ---"

data=$(call_interact '{"action":"setQuery","query":"wifi"}')
assert_jq_data "set-query-response" "$data" \
  '.ok == true' \
  "setQuery should return ok"
wait_for_query "wifi" || fail "set-query-wait" "state query did not become wifi"

data=$(call_interact '{"action":"typeText","text":" on"}')
assert_jq_data "type-text" "$data" \
  '.ok == true' \
  "typeText should return ok"
wait_for_query "wifi on" || fail "type-text-wait" "state query did not become 'wifi on'"

data=$(call_interact '{"action":"backspace","count":3}')
assert_jq_data "backspace" "$data" \
  '.ok == true' \
  "backspace should return ok"
wait_for_query "wifi" || fail "backspace-wait" "state query did not revert to 'wifi'"

data=$(call_interact '{"action":"clearQuery"}')
assert_jq_data "clear-query" "$data" \
  '.ok == true' \
  "clearQuery should return ok"
wait_for_query "" || true

echo ""
echo "--- Navigation ---"

data=$(call_interact '{"action":"setQuery","query":"ze"}')
assert_jq_data "nav-set-query" "$data" \
  '.ok == true' \
  "setQuery for navigation should succeed"
wait_for_query "ze" || fail "nav-query-wait" "state query did not become 'ze'"

data=$(call_interact '{"action":"moveSelection","delta":1}')
assert_jq_data "move-selection" "$data" \
  '.ok == true and (.after.selectedIndex | type == "number")' \
  "moveSelection should return valid state"

data=$(call_interact '{"action":"moveSelection","delta":-1}')
assert_jq_data "move-selection-back" "$data" \
  '.ok == true' \
  "moveSelection negative should return valid state"

echo ""
echo "--- Expand/collapse ---"

if [ "$INSTANCE_MODE" = "session" ] && [ "${NEWSHELL_TEST_ALLOW_ACTIONS:-0}" != "1" ]; then
  echo "(session mode: skipping expand/collapse — may trigger backend actions)"
else
  data=$(call_interact '{"action":"expandSelected"}')
  assert_jq_data "expand-selected" "$data" \
    '.ok == true' \
    "expandSelected should not crash"

  data=$(call_interact '{"action":"collapseSelected"}')
  assert_jq_data "collapse-selected" "$data" \
    '.ok == true' \
    "collapseSelected should not crash"
fi

echo ""
echo "--- Risk/confirmation safety ---"

if [ "$INSTANCE_MODE" = "session" ] && [ "${NEWSHELL_TEST_ALLOW_ACTIONS:-0}" != "1" ]; then
  echo "(skipped in session mode — cannot safely execute destructive actions against running service)"
else
  data=$(call_interact '{"action":"setQuery","query":"shutdown"}')
  assert_jq_data "risky-query" "$data" \
    '.ok == true' \
    "shutdown query should be accepted"
  wait_for_query "shutdown" || true

  data=$(call_interact '{"action":"activateSelected"}')
  assert_jq_data "risky-activation-dry-run" "$data" \
    '.ok == true and (.result.dryRun == true or .after.visible == true or .after.closing == false)' \
    "risky activation must not execute shutdown in test mode; should dry-run or remain open"
fi

echo ""
echo "--- Error handling ---"

data=$(call_interact '{"action":"doesNotExist"}')
assert_jq_data "unknown-action" "$data" \
  '.ok == false and .error.code == "unknown_action"' \
  "unknown action should return structured error"

data=$(call_interact 'not-json-at-all')
assert_jq_data "invalid-json" "$data" \
  '.ok == false and .error.code == "invalid_json"' \
  "invalid JSON should return structured invalid_json error"

echo ""
echo "--- Two-argument interact ---"

data=$(ipc_launcher interact setQuery '{"query":"network"}')
assert_jq_data "interact-two-arg-set-query" "$data" \
  '.ok == true' \
  "two-argument interact should accept a JSON payload"
wait_for_query "network" || fail "interact-two-arg-wait" "state query did not become network"

echo ""
echo "--- Visual state ---"

data=$(call_interact '{"action":"state","visual":true}')
assert_jq_data "state-with-visual" "$data" \
  '.ok == true and (.after.visual.items | type == "array")' \
  "state visual=true should include visual metrics"

echo ""
echo "--- Query debug endpoints ---"

data=$(ipc_query cases 2>/dev/null || echo '{}')
assert_jq_data "query-cases-exists" "$data" \
  '.version == 1 or (. | length > 0)' \
  "query cases should return data"

data=$(ipc_query visualDebug on 2>/dev/null || echo '{}')
assert_jq_data "query-visual-debug-on" "$data" \
  '.version == 1 or (.current != null)' \
  "query visualDebug on should respond"

data=$(ipc_query visualDebug off 2>/dev/null || echo '{}')
assert_jq_data "query-visual-debug-off" "$data" \
  '.version == 1 or (.current != null)' \
  "query visualDebug off should respond"

data=$(ipc_query visualState 2>/dev/null || echo '{}')
assert_jq_data "query-visual-state" "$data" \
  '.version == 1 or (.current != null)' \
  "query visualState should respond"

echo ""
echo "--- Activation structured result ---"

if [ "$INSTANCE_MODE" = "session" ] && [ "${NEWSHELL_TEST_ALLOW_ACTIONS:-0}" != "1" ]; then
  echo "(skipped in session mode — activateSelected may execute real running-service actions)"
else
  data=$(call_interact '{"action":"activateSelected"}')
  assert_jq_data "activate-structured-result" "$data" \
    '.ok == true and .result != null' \
    "activateSelected should return structured semantic result"
fi

echo ""
echo "=== Summary ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"
[[ $FAILED -eq 0 ]]
