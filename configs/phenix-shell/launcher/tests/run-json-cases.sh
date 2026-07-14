#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CASES_DIR="${CASES_DIR:-"$SCRIPT_DIR/cases"}"
PHENIX_SHELL="${PHENIX_SHELL_BIN:-phenix-shell}"
VERBOSE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose|-v) VERBOSE=true; shift ;;
    --cases-dir) CASES_DIR="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

FAILED=0
PASSED=0

run_case() {
  local query="$1"
  local expect="$2"
  local description="$3"

  local data
  data=$($PHENIX_SHELL ipc call query pipeline "$query" 2>/dev/null) || {
    echo "FAIL: $description (query: $query) - IPC call failed"
    FAILED=$((FAILED + 1))
    return
  }

  if echo "$data" | jq -e "$expect" >/dev/null 2>&1; then
    PASSED=$((PASSED + 1))
    if $VERBOSE; then
      echo "OK: $description"
    fi
  else
    echo "FAIL: $description (query: $query)"
    if $VERBOSE; then
      echo "$data" | jq '{query, rows: [.rows[] | {title, placement, ownVisible, breadcrumbText, executable, defaultAction, recipes, semantics}]}'
    fi
    FAILED=$((FAILED + 1))
  fi
}

shopt -s nullglob
for case_file in "$CASES_DIR"/*.json; do
  filename="$(basename "$case_file")"
  if $VERBOSE; then
    echo "Loading cases from $filename"
  fi

  while IFS= read -r case; do
    [ -z "$case" ] && continue
    query=$(echo "$case" | jq -r '.query // empty')
    expect=$(echo "$case" | jq -r '.expect // empty')
    description=$(echo "$case" | jq -r '.description // empty')
    [ -z "$query" ] && continue
    run_case "$query" "$expect" "$description"
  done < <(jq -c '.[]' "$case_file")
done

echo ""
echo "=== Summary ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [[ $FAILED -gt 0 ]]; then
  exit 1
fi
