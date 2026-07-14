#!/usr/bin/env bash
# Visible launcher animation replay — drives the real launcher semantically.
# No keyboard events are simulated.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/../../../.."

IPC=(newshell ipc call launcher)

CASE=animation-smoke
STEP_MS=120
LEAVE_OPEN=false
QUERIES=()
FAILED=0
STEP_NUM=0

usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  --case NAME       Replay case: animation-smoke (default), fast-typing, groups, actions
  --step-ms N       Delay between steps in ms (default: $STEP_MS, min: 10)
  --leave-open      Do not close launcher after replay
  -q/--query TEXT   Custom query steps (repeatable)

Examples:
  $0 --case fast-typing --step-ms 70
  $0 --case groups --step-ms 250 --leave-open
  $0 -q n -q ne -q net -q network -q wifi
EOF
  exit 0
}

sleep_s() {
  awk -v ms="$STEP_MS" 'BEGIN { printf "%.3f", ms / 1000 }'
}

interact() {
  local label="${1:-step$((++STEP_NUM))}" payload="$2"
  local result
  result=$("${IPC[@]}" interactJson "$payload" 2>&1) || {
    echo "  [WARN] step '$label' IPC failed: $result" >&2
    FAILED=$((FAILED + 1))
    return
  }
  local ok
  ok=$(echo "$result" | jq -r '.ok // false' 2>/dev/null || echo "false")
  if [[ "$ok" != "true" ]]; then
    local reason
    reason=$(echo "$result" | jq -r '.error.reason // .error.message // "unknown"' 2>/dev/null)
    echo "  [WARN] step '$label' rejected: $reason" >&2
    FAILED=$((FAILED + 1))
  fi
}

queries_for_case() {
  case "$1" in
    animation-smoke)
      printf '%s\n' \
        n ne net network networking network net \
        wifi 'wifi ' 'wifi on' 'wifi off' 'wifi toggle' \
        vpn 'vpn ' 'vpn ger' 'vpn germany' \
        newxos 'newxos ' 'newxos ai' ai \
        zen 'zen ' 'zen p' 'zen pr' 'zen priv'
      ;;
    fast-typing)
      printf '%s\n' \
        z ze zen 'zen ' 'zen p' 'zen pr' 'zen pri' 'zen priv' \
        n ne new newx newxo newxos 'newxos ' \
        w wi wif wifi 'wifi ' 'wifi o' 'wifi on'
      ;;
    groups)
      printf '%s\n' \
        network net networking \
        newxos 'newxos ' \
        ':' ':wifi' ':wifi ' ':db wifi' \
        '@apps' '@apps zen'
      ;;
    actions)
      printf '%s\n' \
        zen 'zen ' 'zen win' 'zen priv' \
        switch rebuild shutdown ': shutdown' \
        '= 1+2' 'web nix' 'web !gh nix'
      ;;
    *)
      echo "Unknown case: $1" >&2
      exit 2
      ;;
  esac
}

collect_queries() {
  if [[ ${#QUERIES[@]} -gt 0 ]]; then
    printf '%s\n' "${QUERIES[@]}"
  else
    queries_for_case "$CASE"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --case) CASE="$2"; shift 2 ;;
    --step-ms) STEP_MS="$2"; shift 2 ;;
    --leave-open) LEAVE_OPEN=true; shift ;;
    -q|--query) QUERIES+=("$2"); shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

delay="$(sleep_s)"

if ! [[ "$STEP_MS" =~ ^[0-9]+$ ]] || [[ "$STEP_MS" -lt 10 ]]; then
  echo "ERROR: --step-ms must be a positive integer >= 10, got: $STEP_MS" >&2
  exit 2
fi

echo "=== Launcher Visible Replay ==="
echo "Case: $CASE  |  Step delay: ${STEP_MS}ms  |  Leave open: $LEAVE_OPEN"
echo ""

interact "open-launcher" '{"action":"open"}'
sleep "$delay"

while IFS= read -r query; do
  printf '  query: %q\n' "$query"
  json=$(jq -cn --arg q "$query" '{action:"setQuery", query:$q}')
  interact "setQuery:$query" "$json"
  sleep "$delay"
done < <(collect_queries)

# Navigation/expansion smoke at end
echo ""
echo "--- Navigation smoke ---"
interact "moveSelection:1" '{"action":"moveSelection","delta":1}'
sleep "$delay"
interact "expandSelected" '{"action":"expandSelected"}'
sleep "$delay"
interact "collapseSelected" '{"action":"collapseSelected"}'
sleep "$delay"

if ! $LEAVE_OPEN; then
  interact "close-launcher" '{"action":"close"}'
fi

echo ""
echo "=== Summary ==="
echo "Steps: $STEP_NUM  |  IPC warnings: $FAILED"
echo ""

if $LEAVE_OPEN; then
  echo "--leave-open: launcher stays open. Close manually or run:"
  echo "  newshell ipc call launcher interactJson '{\"action\":\"close\"}'"
  echo ""
fi

[[ $FAILED -eq 0 ]]
