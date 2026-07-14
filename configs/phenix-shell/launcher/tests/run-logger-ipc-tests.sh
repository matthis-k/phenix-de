#!/usr/bin/env bash
# Test suite for Logger IPC endpoints
set -euo pipefail

LOGGER_IPC=(newshell ipc call logger)
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

call_logger() {
  local args="$1"
  "${LOGGER_IPC[@]}" handle "$args" 2>/dev/null || echo '{"error":"IPC call failed"}'
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
  local args="$2"
  local expr="$3"
  local message="$4"
  local data
  data=$(call_logger "$args") || { fail "$test" "IPC call failed"; return; }
  if echo "$data" | jq -e "$expr" >/dev/null 2>&1; then
    pass "$test"
  else
    if $VERBOSE; then
      echo "$data" | jq '.' 2>/dev/null || echo "$data"
    fi
    fail "$test" "$message"
  fi
}

assert_json_safe() {
  local test="$1"
  local args="$2"
  local data
  data=$(call_logger "$args") || { fail "$test" "IPC call failed"; return; }
  if echo "$data" | jq '.' >/dev/null 2>&1; then
    pass "$test"
  else
    fail "$test" "Response is not valid JSON"
  fi
}

echo "=== Logger IPC Test Suite ==="
echo ""

# ============================================================
# Section 1: logger.status
# ============================================================
echo "--- logger.status ---"

# 1.1 Status returns ok
assert_jq "status-ok" '{"op":"status"}' \
  '.installed == true' \
  "Status should indicate installed"

# 1.2 Status has eventCount
assert_jq "status-eventCount" '{"op":"status"}' \
  '.eventCount >= 0' \
  "Status should have eventCount"

# 1.3 Status has level info
assert_jq "status-levels" '{"op":"status"}' \
  '.installedMaxLevel != "" and .runtimeMaxLevel != ""' \
  "Status should have level info"

# ============================================================
# Section 2: logger.setLevel
# ============================================================
echo "--- logger.setLevel ---"

# 2.1 Set level to trace
assert_jq "setLevel-trace" '{"op":"setLevel","level":"trace"}' \
  '.ok == true and .level == "trace"' \
  "setLevel to trace should succeed"

# 2.2 Set level to off
assert_jq "setLevel-off" '{"op":"setLevel","level":"off"}' \
  '.ok == true and .level == "off"' \
  "setLevel to off should succeed"

# 2.3 Set level to error
assert_jq "setLevel-error" '{"op":"setLevel","level":"error"}' \
  '.ok == true and .level == "error"' \
  "setLevel to error should succeed"

# 2.4 Set invalid level
assert_jq "setLevel-invalid" '{"op":"setLevel","level":"invalid"}' \
  '.ok == false' \
  "setLevel to invalid should return error"

# 2.5 Reset to debug for subsequent tests
call_logger '{"op":"setLevel","level":"debug"}' > /dev/null 2>&1

# ============================================================
# Section 3: logger.reset
# ============================================================
echo "--- logger.reset ---"

# 3.1 Reset succeeds
assert_jq "reset-ok" '{"op":"reset"}' \
  '.ok == true' \
  "Reset should succeed"

# 3.2 After reset, eventCount is 0
assert_jq "reset-eventCount" '{"op":"status"}' \
  '.eventCount == 0' \
  "After reset eventCount should be 0"

# ============================================================
# Section 4: logger.collect
# ============================================================
echo "--- logger.collect ---"

# 4.1 Collect returns ok
assert_jq "collect-ok" '{"op":"collect"}' \
  '.ok == true' \
  "Collect should succeed"

# 4.2 Collect with includeEvents
assert_jq "collect-events" '{"op":"collect","includeEvents":true}' \
  '.events != null' \
  "Collect with includeEvents should return events array"

# 4.3 Collect with includeCounts
assert_jq "collect-counts" '{"op":"collect","includeCounts":true}' \
  '.counts != null and .counts.byLevel != null' \
  "Collect with includeCounts should return counts"

# ============================================================
# Section 5: logger.report
# ============================================================
echo "--- logger.report ---"

# 5.1 Report returns text
assert_jq "report-text" '{"op":"report"}' \
  '.ok == true and (.text | length > 0)' \
  "Report should return non-empty text"

# 5.2 Report header
assert_jq "report-header" '{"op":"report"}' \
  '.text | contains("Logger report")' \
  "Report should contain header"

# 5.3 Report contains level info
assert_jq "report-levels" '{"op":"report"}' \
  '.text | contains("installed level") and contains("runtime level")' \
  "Report should contain level info"

# ============================================================
# Section 6: logger.disable
# ============================================================
echo "--- logger.disable ---"

# 6.1 Disable succeeds
assert_jq "disable-ok" '{"op":"disable"}' \
  '.ok == true and .level == "off"' \
  "Disable should succeed and set level to off"

# Restore level
call_logger '{"op":"setLevel","level":"debug"}' > /dev/null 2>&1

# ============================================================
# Section 7: JSON safety
# ============================================================
echo "--- JSON safety ---"

# 7.1 All responses are valid JSON
for op in status setLevel disable reset collect report; do
  assert_json_safe "$op-json-safe" "{\"op\":\"$op\"}"
done

# 7.2 Unknown op returns error
assert_jq "unknown-op" '{"op":"unknown"}' \
  '.ok == false and (.error | length > 0)' \
  "Unknown op should return error"

# ============================================================
# Summary
# ============================================================
echo ""
echo "=== Logger IPC Test Summary ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo "Skipped: $SKIPPED"

if [[ $FAILED -gt 0 ]]; then
  exit 1
fi
