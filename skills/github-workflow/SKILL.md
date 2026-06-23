---
name: github-workflow
description: The branch → commit → PR → review → merge flow on GitHub — conventional commits with attribution, one PR per unit of work, monitoring CI, and resolving review threads. Use when committing, opening a PR, or handling review feedback.
---

# GitHub Workflow

The standard change-delivery flow. **Never push to `main`; never auto-merge** — the maintainer merges.

## Branch

One branch, one PR per unit of work. Cut it from an up-to-date default branch:

```bash
git checkout main && git pull --ff-only
git checkout -b <type>-<short-topic>      # e.g. fix-login-retry, update-repo
```

## Commit

- **Conventional Commits**: `<type>(<scope>): <summary>` — `feat`, `fix`, `docs`, `refactor`,
  `test`, `chore`, `ci`. Imperative, lower-case summary.
- Body: what changed and _why_, wrapped ~72 cols.
- **Attribute the AI model** with a trailer (Hard Rule):

```
Co-Authored-By: <Model Name> <noreply@…>
```

Keep one logical change per commit (or a small, coherent series) — all on the one branch.

## Open the PR

```bash
git push -u origin <branch>
gh pr create --title "<type>: <summary>" --body "<what + why + test plan>"
```

- Title mirrors the commit convention.
- Body: bullet list of changes + a short **test plan** checklist (tick items as verified,
  including the CI run once it's green).
- Gather everything first — don't open a PR mid-fixes and a second one for the rest. Push
  follow-up fixes to the same branch; the open PR picks them up.

## Monitor CI

```bash
RUN=$(gh run list --branch <branch> --json databaseId --limit 1 --jq '.[0].databaseId')
gh run watch $RUN
gh run view $RUN --json jobs --jq '.jobs[] | "\(.name): \(.conclusion)"'
```

On failure: `gh run view --log-failed $RUN | tail -80`, fix locally, re-run checks, push.
Investigate failures — never dismiss one as "transient" without evidence.

## Handle review feedback

Request an automated review if the repo has one (e.g. `gh pr comment <N> --body "@copilot review"`).
For each comment: apply the fix, or reply with the rationale if you disagree. Then **reply and
resolve the thread** so the PR ends clean.

```bash
# Get unresolved review-thread IDs + the first comment of each
gh api graphql -f query='
{ repository(owner:"<owner>",name:"<repo>") { pullRequest(number:<N>) {
    reviewThreads(first:100) { nodes { id isResolved
      comments(first:1){ nodes { databaseId path body author { login } } } } } } } }'

# Reply to a thread's first comment, then resolve the thread
gh api -X POST repos/<owner>/<repo>/pulls/<N>/comments/<comment_id>/replies -f body="<reply>"
gh api graphql -f query='mutation($id:ID!){ resolveReviewThread(input:{threadId:$id}){ thread { isResolved } } }' -f id="<PRRT_…>"
```

## Merge

Confirm CI is green and threads are resolved, then **hand off to the maintainer to merge**.
Never run `gh pr merge` autonomously.
