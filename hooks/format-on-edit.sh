#!/usr/bin/env bash
# PostToolUse formatter — after an Edit/Write succeeds, run the matching
# formatter on the touched file so lint-before-CI happens mechanically.
#
# Source: https://github.com/jahrik/agent-config (hooks/format-on-edit.sh);
# registered into agent settings by the ansible-ai-agents role.
#
# Formatters by extension (skipped silently when the tool is not installed):
#   *.sh *.bash  -> shfmt -w -i 2
#   *.py         -> ruff format
#   *.go         -> gofmt -w
#
# Never blocks: always exits 0 (a formatter failure must not fail the edit).
# Claude Code contract only (stdin JSON with .tool_input.file_path); AGY
# registration is deferred until its write-tool arg names are verified.
#
# Self-test: format-on-edit.sh --test
set -uo pipefail

LOCAL_BIN=~/.local/bin
export PATH="${LOCAL_BIN}:${HOME}/.local/go/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"

format_file() {
  local file=$1
  [[ -f $file ]] || return 0
  case $file in
  *.sh | *.bash)
    command -v shfmt >/dev/null && shfmt -w -i 2 "$file"
    ;;
  *.py)
    command -v ruff >/dev/null && ruff format --quiet "$file"
    ;;
  *.go)
    command -v gofmt >/dev/null && gofmt -w "$file"
    ;;
  esac
  return 0
}

self_test() {
  local dir pass=0 fail=0
  dir=$(mktemp -d)
  # shellcheck disable=SC2064  # expand now: dir is local and gone at EXIT
  trap "rm -rf '$dir'" EXIT

  printf 'x=1\ny  =  2\n' >"$dir/t.py"
  printf 'if true; then\n        echo hi\nfi\n' >"$dir/t.sh"
  printf 'not a known extension\n' >"$dir/t.txt"

  format_file "$dir/t.py"
  if grep -q 'y = 2' "$dir/t.py"; then pass=$((pass + 1)); else
    fail=$((fail + 1))
    echo "FAIL: ruff format did not normalize t.py" >&2
  fi
  format_file "$dir/t.sh"
  if grep -q '^  echo hi' "$dir/t.sh"; then pass=$((pass + 1)); else
    fail=$((fail + 1))
    echo "FAIL: shfmt did not reindent t.sh" >&2
  fi
  if format_file "$dir/t.txt" && format_file "$dir/missing.py"; then pass=$((pass + 1)); else
    fail=$((fail + 1))
    echo "FAIL: unknown extension / missing file must be a silent no-op" >&2
  fi

  local rc=0
  echo '{"tool_name":"Write","tool_input":{"file_path":"'"$dir"'/t.sh"}}' | "${BASH_SOURCE[0]}" || rc=$?
  if [[ $rc -eq 0 ]]; then pass=$((pass + 1)); else
    fail=$((fail + 1))
    echo "FAIL: contract round-trip expected exit 0, got $rc" >&2
  fi

  echo "format-on-edit self-test: $pass passed, $fail failed"
  [[ $fail -eq 0 ]]
}

if [[ ${1:-} == "--test" ]]; then
  self_test
  exit $?
fi

input=$(cat)
file=$(jq -r '.tool_input.file_path // empty' <<<"$input" 2>/dev/null || true)
[[ -n $file ]] && format_file "$file"
exit 0
