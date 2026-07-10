#!/usr/bin/env bash
# PreToolUse guard for file writes — mechanical backing for Hard Rule 1
# (never write secrets, API keys, tokens, passwords, or credentials into any file).
#
# Source: https://github.com/jahrik/agent-config (hooks/guard-write.sh);
# registered into agent settings by the ansible-ai-agents role.
#
# Scans only NEW content (Write content, Edit new_string, NotebookEdit
# new_source) so an edit that *removes* a secret is never blocked. Patterns
# are high-precision provider token formats — no generic "password=" heuristic,
# which false-positives on fixtures and docs.
#
# Speaks both hook contracts:
#   - Claude Code: stdin JSON with .tool_input;
#     exit 0 = allow, exit 2 = block (reason on stderr).
#   - AGY/Antigravity: stdin JSON with .toolCall.args (all string values are
#     scanned); stdout {"decision":"allow"} / {"decision":"deny","reason":...}.
#
# Self-test: guard-write.sh --test
set -euo pipefail

LOCAL_BIN=~/.local/bin
export PATH="${LOCAL_BIN}:/usr/local/bin:/usr/bin:/bin:${PATH:-}"

REASON=""

# Documented placeholder credentials (e.g. AWS's canonical docs example) stay
# writable — they appear in READMEs and tests by design. Split so secret
# scanners (and this guard itself) never see a joinable token in this file.
ALLOWLIST='AKIA''IOSFODNN7EXAMPLE'

check() { # sets REASON and returns 1 when the content must be blocked
  local content=$1 stripped
  stripped=$(grep -vE "$ALLOWLIST" <<<"$content" || true)

  local -A patterns=(
    ['AWS access key']='(^|[^A-Z0-9])A(KIA|SIA)[0-9A-Z]{16}([^A-Z0-9]|$)'
    ['GitHub token']='gh[pousr]_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{22,}'
    ['Anthropic API key']='sk-ant-[A-Za-z0-9_-]{20,}'
    ['OpenAI API key']='sk-proj-[A-Za-z0-9_-]{20,}'
    ['Slack token']='xox[baprs]-[A-Za-z0-9-]{10,}'
    ['Stripe live key']='(sk|rk)_live_[0-9a-zA-Z]{24,}'
    ['GitLab token']='glpat-[A-Za-z0-9_-]{20,}'
    ['private key block']='-----BEGIN( RSA| EC| OPENSSH| DSA| PGP)? PRIVATE KEY( BLOCK)?-----'
  )
  local name
  for name in "${!patterns[@]}"; do
    if grep -qE -e "${patterns[$name]}" <<<"$stripped"; then
      REASON="content matches a ${name} pattern — never write credentials to files; use a secrets manager or environment variables (Hard Rule 1)"
      return 1
    fi
  done
  return 0
}

self_test() {
  local self=${BASH_SOURCE[0]} pass=0 fail=0
  expect() { # expect <allow|block> <content>
    local want=$1 content=$2 got=allow
    check "$content" || got=block
    if [[ $got == "$want" ]]; then
      pass=$((pass + 1))
    else
      fail=$((fail + 1))
      echo "FAIL: expected $want, got $got: ${content:0:60}" >&2
    fi
  }
  # Fixtures are concatenated so neither the repo's secret scanners
  # (gitleaks, detect-secrets) nor this guard itself — which must stay able
  # to edit this file — see a joinable token in the source.
  local aws_key='AKIA''IOSFODNN7RE4LKEY'
  local gh_token='ghp_''abcdefghijklmnopqrstuvwxyz0123456789'
  local ant_key='sk-ant-''api03-abcdefghij0123456789'
  local oai_key='sk-proj-''Ab3dEf6hIj9kLm2nOp5q'
  local slack_token='xoxb-''1234567890-abcdefghijk'
  local stripe_key='sk_live_''4eC39HqLyjWDarjtT1zdp7dc'
  local gitlab_token='glpat-''AbCdEfGhIjKlMnOpQrSt'
  local key_header='-----BEGIN OPENSSH PRIV''ATE KEY-----'
  local key_header_bare='-----BEGIN PRIV''ATE KEY-----'

  # real-shaped credentials must be blocked
  expect block "aws_access_key_id = ${aws_key}"
  expect block "token: ${gh_token}"
  expect block "ANTHROPIC_API_KEY=${ant_key}"
  expect block "key = \"${oai_key}\""
  expect block "slack: ${slack_token}"
  expect block "STRIPE=${stripe_key}"
  expect block "${gitlab_token}"
  expect block "${key_header}"
  expect block "${key_header_bare}"
  # ordinary content must be allowed
  expect allow 'export AWS_ACCESS_KEY_ID="{{ vault_aws_key }}"'
  # shellcheck disable=SC2016  # literal ${…} is the point: env refs are fine
  expect allow 'api_key: "${OPENAI_API_KEY}"'
  expect allow 'the ghp_ prefix marks a GitHub personal token'
  expect allow 'echo skiing is fun'
  expect allow "${ALLOWLIST} is the AWS docs placeholder"
  expect allow 'ssh-keygen writes a -----BEGIN PUBLIC KEY----- block'

  # full-contract round trips
  local rc=0 out
  jq -cn --arg c "$gh_token" '{tool_name: "Write", tool_input: {file_path: "/tmp/x", content: $c}}' | "$self" 2>/dev/null || rc=$?
  if [[ $rc -eq 2 ]]; then pass=$((pass + 1)); else
    fail=$((fail + 1))
    echo "FAIL: Claude contract expected exit 2, got $rc" >&2
  fi
  rc=0
  jq -cn --arg o "$gh_token" '{tool_name: "Edit", tool_input: {file_path: "/tmp/x", old_string: $o, new_string: "os.environ[\"GITHUB_TOKEN\"]"}}' | "$self" 2>/dev/null || rc=$?
  if [[ $rc -eq 0 ]]; then pass=$((pass + 1)); else
    fail=$((fail + 1))
    echo "FAIL: Claude contract must allow removing a secret, got exit $rc" >&2
  fi
  out=$(jq -cn --arg c "$slack_token" '{toolCall: {name: "write_to_file", args: {TargetFile: "/tmp/x", CodeContent: $c}}}' | "$self")
  if [[ $(jq -r '.decision' <<<"$out") == "deny" ]]; then pass=$((pass + 1)); else
    fail=$((fail + 1))
    echo "FAIL: AGY contract expected decision=deny, got: $out" >&2
  fi
  out=$(echo '{"toolCall":{"name":"write_to_file","args":{"TargetFile":"/tmp/x","CodeContent":"hello"}}}' | "$self")
  if [[ $(jq -r '.decision' <<<"$out") == "allow" ]]; then pass=$((pass + 1)); else
    fail=$((fail + 1))
    echo "FAIL: AGY contract expected decision=allow, got: $out" >&2
  fi

  echo "guard-write self-test: $pass passed, $fail failed"
  [[ $fail -eq 0 ]]
}

if [[ ${1:-} == "--test" ]]; then
  self_test
  exit $?
fi

input=$(cat)

if jq -e '.toolCall' <<<"$input" >/dev/null 2>&1; then
  # AGY contract: scan every string value in args (AGY edit tools carry new
  # content only); JSON verdict on stdout, always exit 0.
  content=$(jq -r '[.toolCall.args // {} | .. | strings] | join("\n")' <<<"$input" 2>/dev/null || true)
  if [[ -z $content ]] || check "$content"; then
    echo '{"decision":"allow"}'
  else
    jq -cn --arg reason "$REASON" '{decision: "deny", reason: $reason}'
  fi
  exit 0
fi

# Claude Code contract: new content only; exit 2 blocks, reason on stderr.
content=$(jq -r '[.tool_input.content // empty, .tool_input.new_string // empty, .tool_input.new_source // empty] | join("\n")' <<<"$input" 2>/dev/null || true)
[[ -z $content ]] && exit 0
if ! check "$content"; then
  echo "BLOCKED by guard-write hook: $REASON" >&2
  exit 2
fi
