#!/usr/bin/env bash
# Dispatcher push signal — blocks until a dispatcher job ENTERS one of the
# watched states, then exits 2 with a summary on stderr. Two ways to consume:
#
#   1. Architect session (primary): launch via the Bash tool with
#      run_in_background — the harness re-invokes the agent when the script
#      exits, replacing manual sqlite polling loops.
#   2. asyncRewake hook: register on an event with {"async":true,
#      "asyncRewake":true}; exit 2 wakes the agent with stderr as the reason.
#
# Exit codes: 2 = a job changed into a watched state (details on stderr),
# 0 = timeout reached with no change, 1 = usage/db error.
#
# Usage: dispatcher-watch.sh [--db PATH] [--states CSV] [--interval SECONDS]
#                            [--timeout-minutes MINUTES]
# Defaults: db ~/.mcp/dispatcher.db, states InReview,ChangesRequested,Failed,
# interval 15, timeout 120.
#
# Source: https://github.com/jahrik/agent-config (hooks/dispatcher-watch.sh).
# Self-test: dispatcher-watch.sh --test
set -euo pipefail

export PATH="${HOME}/.local/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"

DB="${HOME}/.mcp/dispatcher.db"
STATES="InReview,ChangesRequested,Failed"
INTERVAL=15
TIMEOUT_MINUTES=120

snapshot() { # rows of "id|status" for jobs currently in a watched state
  local quoted
  quoted="'${STATES//,/\',\'}'"
  sqlite3 -readonly "$DB" \
    "SELECT id || '|' || status FROM jobs WHERE status IN (${quoted}) ORDER BY id;"
}

watch() {
  [[ -f $DB ]] || {
    echo "dispatcher-watch: no database at $DB" >&2
    exit 1
  }
  local baseline current new deadline
  baseline=$(snapshot)
  deadline=$((SECONDS + TIMEOUT_MINUTES * 60))
  while ((SECONDS < deadline)); do
    sleep "$INTERVAL"
    current=$(snapshot)
    new=$(comm -13 <(sort <<<"$baseline") <(sort <<<"$current"))
    if [[ -n $new ]]; then
      echo "dispatcher-watch: job(s) entered a watched state (${STATES}):" >&2
      while IFS='|' read -r id _; do
        [[ -z $id ]] && continue
        sqlite3 -readonly "$DB" \
          "SELECT '  ' || id || '  ' || status || '  ' || worker_type || '  ' || substr(payload, 1, 120) FROM jobs WHERE id = '${id//\'/}';" >&2
      done <<<"$new"
      exit 2
    fi
  done
  exit 0
}

self_test() {
  local dir pass=0 fail=0 rc out
  dir=$(mktemp -d)
  # shellcheck disable=SC2064  # expand now: dir is local and gone at EXIT
  trap "rm -rf '$dir'" EXIT
  DB="$dir/dispatcher.db"
  INTERVAL=1
  TIMEOUT_MINUTES=1

  sqlite3 "$DB" "CREATE TABLE jobs (id TEXT PRIMARY KEY, status TEXT, worker_type TEXT, payload TEXT);
    INSERT INTO jobs VALUES ('job-a', 'Running', 'devlead', '{\"title\":\"t\"}');
    INSERT INTO jobs VALUES ('job-b', 'InReview', 'devlead', '{\"title\":\"old\"}');"

  # watch() calls exit, so every self-test invocation must run in a subshell
  # a state change into a watched state must trip the watcher with exit 2;
  # job-b is already InReview at baseline and must NOT be reported
  (
    sleep 2
    sqlite3 "$DB" "UPDATE jobs SET status = 'InReview' WHERE id = 'job-a';"
  ) &
  rc=0
  out=$( (watch) 2>&1) || rc=$?
  wait
  if [[ $rc -eq 2 && $out == *"job-a"* && $out != *"job-b"* ]]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "FAIL: expected exit 2 reporting only job-a; rc=$rc out=$out" >&2
  fi

  # no change within the timeout must exit 0
  TIMEOUT_MINUTES=0
  rc=0
  # shellcheck disable=SC2319  # $? is the subshell's exit code, intended
  (watch) >/dev/null 2>&1 || rc=$?
  if [[ $rc -eq 0 ]]; then pass=$((pass + 1)); else
    fail=$((fail + 1))
    echo "FAIL: timeout path expected exit 0, got $rc" >&2
  fi

  # a missing database must exit 1
  DB="$dir/missing.db"
  rc=0
  # shellcheck disable=SC2319  # $? is the subshell's exit code, intended
  (watch) >/dev/null 2>&1 || rc=$?
  if [[ $rc -eq 1 ]]; then pass=$((pass + 1)); else
    fail=$((fail + 1))
    echo "FAIL: missing db expected exit 1, got $rc" >&2
  fi

  echo "dispatcher-watch self-test: $pass passed, $fail failed"
  [[ $fail -eq 0 ]]
}

while [[ $# -gt 0 ]]; do
  case $1 in
  --test)
    self_test
    exit $?
    ;;
  --db)
    DB=$2
    shift 2
    ;;
  --states)
    STATES=$2
    shift 2
    ;;
  --interval)
    INTERVAL=$2
    shift 2
    ;;
  --timeout-minutes)
    TIMEOUT_MINUTES=$2
    shift 2
    ;;
  *)
    echo "dispatcher-watch: unknown option: $1" >&2
    exit 1
    ;;
  esac
done

watch
