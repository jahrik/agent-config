---
name: github-workflow
description: The branch → commit → PR → review → merge flow on GitHub via mcp-github. Use when committing, opening a PR, monitoring CI, or handling review feedback.
---

# GitHub Workflow

The standard change-delivery flow. **Never push to `main`; never auto-merge** — the maintainer
merges. **Never use the `gh` CLI** — GitHub operations go through the `mcp-github` tools
(`gh_*`); a missing capability means an issue on the MCP server's repo (`gh_issue_create`) and a
handoff to the maintainer.

## Branch

One branch, one PR per unit of work, cut from an up-to-date default branch:

```bash
git checkout main && git pull --ff-only
git checkout -b <type>-<short-topic>      # e.g. fix-login-retry
```

## Commit

- **Conventional Commits**: `<type>(<scope>): <summary>` — feat, fix, docs, refactor, test,
  chore, ci. Imperative, lower-case; body says what and _why_, wrapped ~72 cols.
- **Attribute the AI model** (Hard Rule): `Co-Authored-By: <Model Name> <noreply@…>`
- One logical change per commit (or a small coherent series), all on the one branch.

## Open the PR

`git push -u origin <branch>`, then `gh_pr_create` — title mirrors the commit convention; body is
a bullet list of changes + a **test plan** checklist. Never a second PR for follow-up fixes; push
them to the same branch and the open PR picks them up. After opening the PR, use
`gh_pr_request_reviewers` to request Copilot and the maintainer, then set an adjustable timer to
wait for the review. Copilot's login is `Copilot` — the `[bot]` app slug is silently dropped by
GitHub, and the tool warns if a reviewer didn't take.

## Monitor CI

`gh_pr_checks` / `gh_run_list` → `gh_run_get` until the run concludes; `gh_run_failed_logs` on
failure. Fix locally, re-run checks, push. Never dismiss a failure as "transient" without
evidence. Re-run a flaky run with `gh_run_rerun` (`failed_only` to retry just the failed jobs).

## Handle review feedback

Wait for the review timer to finish or for a notification. Read review comments using
`gh_review_comments_list` and `gh_review_threads_get`. Per comment: apply the fix, push
the changes to the PR branch, and reply to the thread (`gh_review_comment_reply`) with your
rationale. Repeat this cycle of fixing, pushing, and replying until a clean review is
reached. Finally, resolve the thread: `gh_review_thread_resolve` so the PR ends clean.

## Merge

Confirm CI green and threads resolved, then **hand off to the maintainer**. Never call
`gh_pr_merge` autonomously.
