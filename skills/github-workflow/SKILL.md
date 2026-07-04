---
name: github-workflow
description: The branch → commit → PR → review → merge flow on GitHub — conventional commits with attribution, one PR per unit of work, monitoring CI, and resolving review threads. Use when committing, opening a PR, or handling review feedback.
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
them to the same branch and the open PR picks them up.

## Monitor CI

`gh_pr_checks` / `gh_run_list` → `gh_run_get` until the run concludes; `gh_run_failed_logs` on
failure. Fix locally, re-run checks, push. Never dismiss a failure as "transient" without
evidence. (Workflow rerun has no tool yet — issue + maintainer.)

## Handle review feedback

Request an automated review if the repo has one (`gh_pr_comment` with `@copilot review`). Per
comment: apply the fix, or reply with rationale — then **reply and resolve the thread** so the PR
ends clean: `gh_review_threads_get` → `gh_review_comment_reply` → `gh_review_thread_resolve`.

## Merge

Confirm CI green and threads resolved, then **hand off to the maintainer**. Never call
`gh_pr_merge` autonomously.
