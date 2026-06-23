---
name: sync-repos
description: Sync all GitHub repos — clone missing, pull main, clean up merged branches, report open PRs and unmerged work
---

Sync all GitHub repos using `~/go/bin/repo-sync`. Run from `~/github`:

```bash
repo-sync --pull --report-orphans
```

Do not interpret or summarize output beyond what `repo-sync` prints. If it fails, show the error.

**Flags:**

- `--fetch` — status snapshot, no writes
- `--pull` — fetch + fast-forward pull
- `--checkout` — switch SYNCED repos (merged branch, nothing ahead) to default branch and pull; implies `--pull`
- `--skip-forks`, `--skip-archived`, `--filter <regexp>`, `--format json`

## Extending the CLI

Source: `/home/deck/github/repo-sync`. Install after changes:

```bash
/home/deck/.local/go/bin/go install ./...
```

**Four-layer path for new features:**

1. `internal/git/git.go` — add to `Runner` interface + implement on `*runner`
2. `internal/config/config.go` — field in `Config` + pointer field in `FileConfig` (yaml support)
3. `internal/sync/sync.go` — consume in `syncOne` or `Run`
4. `cmd/root.go` — cobra flag + `applyFileBool`/`applyFileString` call

**Tests:** git.Runner methods → `internal/git/git_extra_test.go` (real temp repo). Sync logic → `internal/sync/sync_coverage_test.go` (uses `fakeGitRunner` from `sync_test.go`). Always `gofmt -w` before committing — golangci-lint enforces it.

**CI:** `Build`, `Lint`, `Test` must all pass. Never push to main — branch + PR always.

**Copilot review:** `gh pr comment <N> --body "@copilot review"`

**Resolve threads:**

```bash
# 1. Get PRRT_* thread IDs
gh api graphql -f query='{ repository(owner:"jahrik",name:"repo-sync") { pullRequest(number:N) { reviewThreads(last:20) { nodes { id isResolved } } } } }'
# 2. Resolve
gh api graphql -f query='mutation { resolveReviewThread(input:{threadId:"PRRT_..."}) { thread { isResolved } } }'
```

## Releases

Tag to release (GoReleaser handles the rest):

```bash
git tag v0.x.y && git push origin v0.x.y
```

Install the versioned binary locally (`go install` strips ldflags):

```bash
gh release download v0.x.y --repo jahrik/repo-sync --pattern "repo-sync_*_linux_amd64.tar.gz" --dir /tmp
tar -xzf /tmp/repo-sync_*_linux_amd64.tar.gz -C /tmp && mv /tmp/repo-sync ~/go/bin/repo-sync
```

Check release logs for deprecation warnings: `gh run view <id> --log | grep -iE "warn|deprecat"`

Current action versions (Node 24): `actions/checkout@v7`, `actions/setup-go@v6`, `goreleaser/goreleaser-action@v7`.
