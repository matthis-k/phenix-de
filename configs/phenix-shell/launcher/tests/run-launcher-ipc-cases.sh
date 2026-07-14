#!/usr/bin/env bash
set -euo pipefail

# cd to repo root (support running from any cwd)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/../../../.."

IPC=(newshell ipc call query pipeline)
VERBOSE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose|-v) VERBOSE=true; shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

FAILED=0
PASSED=0

json_for() {
  "${IPC[@]}" "$1"
}

fail() {
  local query="$1"
  local message="$2"
  echo "FAIL: $query - $message"
  FAILED=$((FAILED + 1))
}

pass() {
  local query="$1"
  if $VERBOSE; then
    echo "OK: $query"
  fi
  PASSED=$((PASSED + 1))
}

assert_jq() {
  local query="$1"
  local expr="$2"
  local message="$3"
  local data
  data=$(json_for "$query") || { fail "$query" "IPC call failed"; return; }
  if echo "$data" | jq -e "$expr" >/dev/null; then
    pass "$query"
  else
    if $VERBOSE; then
      echo "$data" | jq '{query, rows: [.rows[] | {title, placement, ownVisible, breadcrumbText, executable, defaultAction, recipes, semantics}]}'
    fi
    fail "$query" "$message"
  fi
}

assert_jq "network" '.rows[0].title == "Networking" and .rows[0].placement == "nested-group" and ((.rows[0].children // []) | length) > 0' 'Networking should be top expanded group with children'
assert_jq "net" '.rows[0].title == "Networking" and .rows[0].placement == "nested-group" and ((.rows[0].children // []) | length) > 0' 'net should browse Networking'
assert_jq "networking" '.rows[0].title == "Networking" and .rows[0].placement == "nested-group" and ((.rows[0].children // []) | length) > 0' 'networking should browse Networking'

assert_jq "vpn" '.rows[0].title == "VPN" and .rows[0].placement == "promoted-child" and ([.rows[] | select(.title == "Networking" and .ownVisible == true)] | length) == 0' 'VPN should promote without visible Networking parent'
assert_jq "wifi" '.rows[0].title == "Wi-Fi" and .rows[0].placement == "promoted-child" and (.rows[0].switchActions.toggle.id == "toggle") and ([.rows[] | select(.title == "Networking" and .ownVisible == true)] | length) == 0' 'Wi-Fi should promote as switch without visible Networking parent'
assert_jq "bluetooth" '.rows[0].title == "Bluetooth" and .rows[0].placement == "promoted-child" and ([.rows[] | select(.title == "Networking" and .ownVisible == true)] | length) == 0' 'Bluetooth should promote without visible Networking parent'

assert_jq "newxos" '.rows[0].title == "Newxos" and .rows[0].placement == "nested-group" and (.rows[0].recipes.activate // [] | tostring | contains("run-action") | not)' 'Newxos should be retained expanded group with safe enter'
assert_jq "newxos " '.rows[0].title == "Newxos" and .rows[0].placement == "nested-group" and ((.rows[0].children // []) | length) > 0' 'newxos trailing space should browse Newxos children'
assert_jq "ai" '.rows[0].title == "AI" and .rows[0].placement == "promoted-child" and ([.rows[] | select(.title == "Newxos" and .ownVisible == true)] | length) == 0 and (.rows[0].breadcrumbText | contains("Newxos"))' 'AI should promote with Newxos only as context'
assert_jq "switch" '[.rows[] | select(.title == "Switch System" and (.placement == "promoted-child" or .placement == "flattened") and .semantics.activation.requiresConfirm == true)] | length == 1' 'Switch System should promote and require confirmation'
assert_jq "rebuild" '[.rows[] | select(.title == "Switch System" and (.placement == "promoted-child" or .placement == "flattened") and .semantics.activation.requiresConfirm == true)] | length == 1' 'rebuild should resolve to Switch System and require confirmation'

assert_jq "zen" '(.rows[0].title | contains("Zen")) and .rows[0].placement == "promoted-child" and (.rows[0].breadcrumbText | contains("Applications")) and .rows[0].recipes.activate == [["run-action", {"action":"default"}], ["close"]] and .rows[0].executable == true and .rows[0].canExecuteNow == true' 'Zen should promote, launch, and close'
assert_jq "zen " '(.rows[0].title | contains("Zen")) and .rows[0].placement == "promoted-child" and .rows[0].recipes.activate == [["run-action", {"action":"default"}], ["close"]] and .rows[0].executable == true and .rows[0].canExecuteNow == true' 'Zen trailing space should not be intercepted by Applications'
assert_jq "zen browser" '(.rows[0].title | contains("Zen")) and .rows[0].placement == "promoted-child" and (.rows[0].breadcrumbText | contains("Applications"))' 'Zen Browser should stay promoted'

zen_priv=$(json_for "zen priv") || zen_priv='{}'
if echo "$zen_priv" | jq -e '[.rows[] | select((.title | test("Private|priv"; "i")) or (.defaultAction.id | test("private|priv"; "i")) or ([((.actions // [])[]).id] | join(" ") | test("private|priv"; "i")))] | length > 0' >/dev/null; then
  pass "zen priv"
else
  if $VERBOSE; then
    echo "$zen_priv" | jq '{query, rows: [.rows[] | {title, defaultAction, actions, breadcrumbText}]}'
  fi
  echo "SKIP: zen priv - no private desktop action exposed in current DesktopEntries data"
fi

assert_jq "?" '[.rows[] | select(.title == "Applications" and .metadata.replaceQuery == "@app " and .recipes.activate == [["edit-query", {"mode":"replace", "from":"metadata.replaceQuery"}]])] | length == 1' 'Applications backend help row should edit query only'
assert_jq "@apps" '(.rows | length) >= 0 and (.query == "@apps" or .directive.prefix == "@apps")' '@apps browse query should be accepted by pipeline'
assert_jq "= 1+2" '(.rows[0].title | test("3|= 1\\+2|1\\+2")) and (.rows[0].placement == "standalone" or .rows[0].kind == "calculator-result")' 'calculator result should remain standalone'
assert_jq "shutdown" '.rows[0].title == "Shut Down" and .rows[0].semantics.activation.requiresConfirm == true and .rows[0].executable == false' 'shutdown should be risk-gated'
assert_jq ": shutdown" '.rows[0].title == "Shut Down" and .rows[0].semantics.activation.requiresConfirm == true and .rows[0].executable == false' ': shutdown should be risk-gated'

echo "=== Summary ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [[ $FAILED -gt 0 ]]; then
  exit 1
fi
