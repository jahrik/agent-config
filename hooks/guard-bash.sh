#!/usr/bin/env bash
# PreToolUse guard for shell commands — mechanical backing for the Hard Rules.
#
# Source: https://github.com/jahrik/agent-config (hooks/guard-bash.sh);
# registered into agent settings by the ansible-ai-agents role.
#
# Blocks:
#   1. `gh` invoked as a command word anywhere in the command line, including
#      inside compound commands (`cd x && gh pr merge`), pipes, and command
#      substitution. Closes the gap in the `Bash(gh:*)` permission deny, which
#      only matches prefixes. Agents act as the GitHub App identity via the
#      mcp-github tools; `gh` is the human's own session (Hard Rule 7).
#   2. `git push` targeting main/master, by branch arg or refspec (Hard Rule 5).
#
# Speaks both hook contracts:
#   - Claude Code: stdin JSON with .tool_input.command;
#     exit 0 = allow, exit 2 = block (reason on stderr).
#   - AGY/Antigravity: stdin JSON with .toolCall.args.CommandLine;
#     stdout {} = no opinion, {"decision":"deny","reason":...} = block.
#
# Self-test: guard-bash.sh --test
set -euo pipefail

REASON=""

check() { # sets REASON and returns 1 when the command must be blocked
  local cmd=$1 stripped
  # Drop quoted strings so text arguments (rg 'gh pr', commit messages) can't
  # false-positive; command words are never quoted.
  stripped=$(sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g" <<<"$cmd")

  # gh as a command word: start of line/segment (; & | ` $( subshell) or after
  # wrappers that exec their arguments.
  local seg='(^|[;&|`(]|\$\()[[:space:]]*'
  local wrap='(^|[[:space:]])(env|exec|command|xargs|nohup|timeout [0-9smh]+)[[:space:]]+([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*'
  if grep -qE "${seg}gh([[:space:]]|\$)|${wrap}gh([[:space:]]|\$)" <<<"$stripped"; then
    REASON="the gh CLI is the human's session — use the mcp-github (gh_*) tools; missing capability => open an issue on jahrik/mcp-servers (Hard Rule 7)"
    return 1
  fi

  # git push to main/master: bare branch arg, remote+branch, or refspec :main.
  if grep -qE "${seg}git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+push([[:space:]]+[^;&|]*)?([[:space:]]|:)(main|master)([[:space:]]|\$)" <<<"$stripped"; then
    REASON="never push to main/master — branch and open a PR; the maintainer merges (Hard Rule 5)"
    return 1
  fi
  return 0
}

self_test() {
  local self=${BASH_SOURCE[0]} pass=0 fail=0
  expect() { # expect <allow|block> <command...>
    local want=$1 cmd=$2 got=allow
    check "$cmd" || got=block
    if [[ $got == "$want" ]]; then
      pass=$((pass + 1))
    else
      fail=$((fail + 1))
      echo "FAIL: expected $want, got $got: $cmd" >&2
    fi
  }
  # gh must be blocked
  expect block 'gh pr merge 5'
  expect block 'cd /tmp && gh pr create'
  expect block 'git fetch; gh run list'
  expect block 'echo x | gh api -'
  expect block 'env GH_PAGER= gh api user'
  expect block 'xargs gh repo view'
  # shellcheck disable=SC2016  # the $( must reach the check un-expanded
  expect block 'FOO=$(gh api user)'
  # gh as text/substring must be allowed
  expect allow "rg 'gh pr' skills/"
  expect allow 'git commit -m "use gh workflow"'
  expect allow 'echo high'
  expect allow 'cat ghsweep.log'
  expect allow 'mcp-github --help'
  # push-to-main must be blocked
  expect block 'git push origin main'
  expect block 'git push origin HEAD:main'
  expect block 'cd /x && git push origin master'
  expect block 'git -C /home/x/repo push origin main'
  # legitimate pushes must be allowed
  expect allow 'git push -u origin feat/tooling-refinements'
  expect allow 'git push origin fix/main-menu'
  expect allow 'git checkout main'
  expect allow 'git pull origin main'

  # full-contract round trips
  local rc=0 out
  echo '{"tool_input":{"command":"gh pr list"}}' | "$self" 2>/dev/null || rc=$?
  if [[ $rc -eq 2 ]]; then pass=$((pass + 1)); else
    fail=$((fail + 1))
    echo "FAIL: Claude contract expected exit 2, got $rc" >&2
  fi
  out=$(echo '{"toolCall":{"name":"run_command","args":{"CommandLine":"gh pr list"}}}' | "$self")
  if [[ $(jq -r '.decision' <<<"$out") == "deny" ]]; then pass=$((pass + 1)); else
    fail=$((fail + 1))
    echo "FAIL: AGY contract expected decision=deny, got: $out" >&2
  fi
  out=$(echo '{"toolCall":{"name":"run_command","args":{"CommandLine":"ls"}}}' | "$self")
  if [[ $out == "{}" ]]; then pass=$((pass + 1)); else
    fail=$((fail + 1))
    echo "FAIL: AGY contract expected {} for allow, got: $out" >&2
  fi

  echo "guard-bash self-test: $pass passed, $fail failed"
  [[ $fail -eq 0 ]]
}

if [[ ${1:-} == "--test" ]]; then
  self_test
  exit $?
fi

input=$(cat)
command=$(jq -r '.tool_input.command // .toolCall.args.CommandLine // empty' <<<"$input" 2>/dev/null || true)

if jq -e '.toolCall' <<<"$input" >/dev/null 2>&1; then
  # AGY contract: JSON verdict on stdout, always exit 0.
  if [[ -z $command ]] || check "$command"; then
    echo '{}'
  else
    jq -cn --arg reason "$REASON" '{decision: "deny", reason: $reason}'
  fi
  exit 0
fi

# Claude Code contract: exit 2 blocks, reason on stderr.
[[ -z $command ]] && exit 0
if ! check "$command"; then
  echo "BLOCKED by guard-bash hook: $REASON" >&2
  exit 2
fi
