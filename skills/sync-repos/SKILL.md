---
name: sync-repos
description: Sync all your GitHub repos — clone missing, pull the default branch, clean up merged branches, report open PRs and unmerged work
---

# Sync Repos

Bring every repo under your GitHub account/org into sync locally: clone the missing ones,
fast-forward each default branch, and report repos that still have open PRs or unmerged
local work.

## With a sync tool

If the project provides a multi-repo sync CLI, prefer it (the maintainer's tool and its path
are noted in `AGENTS.md`). Typical modes: a read-only status snapshot, a fetch + fast-forward
pull, and a checkout that switches fully-merged repos back to the default branch. Don't
interpret or summarize the tool's output beyond what it prints; if it fails, show the error.

## With `gh` + git

```bash
# Clone everything missing, then fast-forward each repo's default branch
gh repo list <owner> --limit 200 --json name,defaultBranchRef \
  --jq '.[] | "\(.name) \(.defaultBranchRef.name)"' |
while read -r name branch; do
  [ -d "$name" ] || gh repo clone "<owner>/$name"
  git -C "$name" fetch --prune
  git -C "$name" merge --ff-only "origin/$branch" 2>/dev/null || echo "$name: not fast-forwardable"
done

# Report open PRs that still need attention
gh search prs --owner <owner> --state open --json repository,number,title
```

Never push to main — branch + PR always.
