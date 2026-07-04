# Shared machinery — all repo types

## You are the driver

You own per-repo branch, sequencing, the single PR, and the final go/no-go. Subagents do the
self-contained work and **report back — they never commit, push, or open PRs.** Subagents start
cold: give each the repo path, branch, and a tight scope. **Vet load-bearing claims against ground
truth** — a cold agent can misread a guard or claim something "doesn't exist".

Run read-only agents (`architect`, `devrev`, `secrev`) and independent per-repo work in parallel;
background-launch remediation on independent repos while you drive the next. Delegation is a
judgement call — a one-file fix is faster inline; reach for an agent when a step is sizeable or
benefits from a dedicated lens. Don't spawn an agent to re-run work the harness already tracks
(e.g. a backgrounded test run) — wait for it.

| Work                                       | Agent                |
| ------------------------------------------ | -------------------- |
| Understand the repo; find DRY/hygiene gaps | `architect`          |
| Probe upstream for newer pins              | `releng`             |
| Fix code/tasks; refactor                   | `devlead`/`infraeng` |
| Lint/CI/release config                     | `releng`             |
| README + AGENTS.md; keep docs in sync      | `infoarch`           |
| Pre-PR review (parallel, read-only)        | `devrev` + `secrev`  |
| Run tests; confirm from actual output      | `qa`                 |
| Monitor CI, triage failures                | `releng`             |

## Branch and PR conventions

```bash
git checkout main && git pull --ff-only
git checkout -b update-repo
```

- If `update-repo` exists from a merged PR, `git branch -D update-repo` and cut fresh from updated
  `main`; the remote needs `git push --force-with-lease` to overwrite the stale branch.
- Before opening the PR, confirm `git log --oneline origin/main..update-repo` shows only intended
  commits — a branch cut from a non-main base drags unmerged commits in.
- One PR per repo per run; push follow-ups to the same branch, never a second PR.
- Commit message: summarize what changed and why; attribute with the `Co-Authored-By:` trailer.
- PR title: `Modernize: <repo-name>` (ansible roles: `Update role: <repo-name>`). Body: bullet list
  of changes + test-plan checklist + any "Proposed follow-ups" from the hygiene pass.
- **Never push to main; never auto-merge.** The maintainer merges.

## GitHub operations — mcp-github only

The `gh` CLI is **banned**. Use the `mcp-github` tools: `gh_pr_create`/`gh_pr_edit` for PRs,
`gh_run_list`/`gh_run_get` to watch CI, `gh_run_failed_logs` to triage failures, `gh_repo_get`
for fork checks. If an operation has no mcp-github tool (workflow rerun, repo admin settings,
secrets), **open an issue on the MCP server's repo** describing the gap and hand the action to
the maintainer — never fall back to `gh`.

## Watch CI

Poll `gh_run_list` (branch-filtered) → `gh_run_get` until the run concludes; on failure read
`gh_run_failed_logs`, fix locally, re-lint/test, push — the open PR picks it up.

## Deep hygiene pass (propose, don't auto-apply)

`architect` analyses (read-only), `devrev` vets, `devlead`/`infraeng` applies. Minimalism — fewest
lines that still read clearly; every task/parameter/variable earns its place; collapse copy-paste
into loops/helpers; delete dead code, unused vars, commented-out cruft. Apply only **low-risk,
behavior-preserving** cleanups on the branch; list anything that could change behavior as
**"Proposed follow-ups"** in the PR body. When cleanup changes the public surface, `infoarch`
updates README + AGENTS.md in the same PR.

## Transient CI failures — re-run, don't debug

Environmental flakes: GitHub API rate limits (unauthenticated `releases/latest`, 60 req/hr), distro
mirror drops, module-proxy timeouts, AUR clone SSL resets. Tell: one platform fails on a download
while another passes. Re-run the workflow before investigating (a rerun tool gap in mcp-github →
open an issue / ask the maintainer to re-run).

## Docs ground rules

`AGENTS.md`, never `CLAUDE.md`. Short, scannable, command-first; at most one sentence of history.
**Repo-facing content only** — machine-specific detail (local wrappers, venv paths, host runtime)
lives in the environment's `AGENTS.md`, not committed docs. READMEs use plain `molecule`/`make`/
`go` commands, not local wrappers.

## Wrap-up

Invoke `/skill-creator` to fold durable, general learnings into this skill or the type's language
skill — a new bug pattern, a shifted pin, a CI breakage + fix, a sharper triage check. Keep it
lean: prefer a tightened line over a new template; trim at least as much as you add.
