---
name: update-go-repo
description: Maintain Go project repos — triage drift, bump pins, fix vet/lint/test/CI/docs, and drive the work through the SDLC subagents. Walk all Go repos alphabetically, or just the one in the current dir.
---

# Update Go Repo

Keep Go project repos current, clean, and releasable. This is **drift-maintenance** orchestration,
not a one-time conversion — detect what drifted, bump what's stale, fix what's broken, and propose
deeper cleanups. For the underlying conventions (layout, tooling, versioning), load the **`go`**
skill; this skill is the _procedure_ that applies them across repos.

**Mode detection.** Check the current working directory first:

- **Single-repo mode** — cwd contains `go.mod`. Skip the walk; run the phases against this repo.
- **Walk mode** — otherwise, scan the projects directory for repos containing `go.mod`, sort
  alphabetically, and work each in turn. **Skip** archived forks of someone else's project.

Inspect each repo's state **live** — never rely on a saved status list. Work through every repo in a
single run; after each, move to the next without stopping. A clean repo is a legitimate no-op — say
so plainly and don't manufacture churn.

---

## You are the driver

You own per-repo branch, sequencing, the single PR, and the final go/no-go. Subagents do the
self-contained work and **report back — they never commit, push, or open PRs.** Subagents start
cold: give each the repo path, branch, and a tight scope. **Vet load-bearing claims against ground
truth** — a cold agent can misread a build tag or claim a function "doesn't exist."

Run read-only agents (`architect`, `devrev`, `secrev`) and independent per-repo work in parallel;
background-launch remediation on independent repos while you drive the next. Delegation is a
judgement call — a one-file fix is faster inline; reach for an agent when a step is sizeable or
benefits from a dedicated lens. Don't spawn an agent to re-run work the harness already tracks (e.g.
a backgrounded `go test`) — wait for it.

| Work                                           | Agent               |
| ---------------------------------------------- | ------------------- |
| Understand the module; find DRY/hygiene gaps   | `architect`         |
| Probe upstream for newer deps/action/tool pins | `releng`            |
| Fix code, vet/lint findings, refactor          | `devlead`           |
| Lint/CI config, `.golangci.yml`, `.goreleaser` | `releng`            |
| README + AGENTS.md; keep docs in sync          | `infoarch`          |
| Pre-PR review (parallel, read-only)            | `devrev` + `secrev` |
| Run `go test -race`; confirm from output       | `qa`                |
| Monitor CI, triage failures                    | `releng`            |

---

## Current Standard — single source of truth

Templates below reference these. **To roll out a new standard, bump it here only**, then run the
skill — Phase 2 propagates it.

| Knob                            | Current value                                             |
| ------------------------------- | --------------------------------------------------------- |
| `go.mod` Go version             | recent stable (e.g. `1.23.0`); CI `go-version` matches    |
| `actions/checkout`              | `@v7`                                                     |
| `actions/setup-go`              | `@v6` with `cache: true`                                  |
| `actions/upload-artifact`       | `@v7`                                                     |
| `golangci/golangci-lint-action` | `@v7` with a pinned `version:` (full tag, e.g. `v2.12.2`) |
| `golangci-lint` linters         | errcheck, govet, ineffassign, staticcheck, unused + gofmt |
| GoReleaser config               | `version: 2`; ldflags inject `main.version/commit/date`   |

Bump deliberately: `go get -u ./... && go mod tidy` widens module deps; check each action/tool's
latest release. When a bump is broad (Go minor, a major action), pilot it on one repo end-to-end
(`go test -race` + a clean `golangci-lint run`) before propagating — surface breakage once, not N×.

---

## Phase 1 — Triage scan (decide who needs work)

Cheaply classify each repo before the heavy pipeline. For each, emit `conforms` or
`needs: [vet, lint, tests, ci, release, docs, deps, hygiene]`.

A repo **needs remediation** if any hold:

- `go vet ./...` or `gofmt -l .` is non-empty
- No `.golangci.yml`, or `golangci-lint run` reports issues
- No CI workflow, or actions/tool versions drift from the Current Standard table
- `--version` reports `dev (commit none, built unknown)` with no `ReadBuildInfo` fallback (see `go` skill)
- `.goreleaser.yml` missing on a repo that ships binaries, or ldflags don't inject version/commit/date
- `go.mod` deps are stale or the module has known-vulnerable versions (`govulncheck ./...` if available)
- Tests are absent for non-trivial logic, or not table-driven, or a test reads real credentials / escapes its sandbox
- `AGENTS.md` missing, or README missing/stub

Verdicts are heuristic — markers prove _shape_, not correctness. Only a repo clean on **all** phases
is a true no-op; report it skipped and move on **without** cutting a branch.

---

## Phase 2 — Latest check (bump pins)

Pins stay pinned for reproducibility; "latest" means deliberately bumping when a newer stable exists.
Have `releng` probe upstream: newest releases of `setup-go`, `checkout`, `golangci-lint-action` (and
the `golangci-lint` `version:` it pins), GoReleaser, and direct module deps. For Go itself, respect
the project's floor unless raising it deliberately. **Check live docs** rather than memory for
deprecations across Go releases and for a dep's current API. Apply accepted bumps to the Current
Standard table first, then to the repo's files; run `go mod tidy` and a fresh `go test -race` after
any dep bump.

---

## Phase 3 — Remediation pipeline (per repo that failed triage)

**One branch, one PR per repo per run.**

```bash
git checkout main && git pull --ff-only
git checkout -b update-repo
```

If `update-repo` exists from a merged PR, `git branch -D update-repo` and cut fresh. Before opening
the PR, verify `git log --oneline origin/main..update-repo` shows only intended commits.

### A. Understand the module — `architect`

Read `main.go`, `cmd/`, `internal/`, `go.mod`, the CI workflows, and `README.md`. Establish what the
binary does, its packages, and whether logic is covered by tests before changing anything.

### Fix code — `devlead`

- Make `go vet ./...` and `gofmt -l .` clean; resolve every `golangci-lint run` finding.
- Wrap errors with `%w`; never silently discard an error (errcheck will flag it).
- **Version trap** — if `--version` shows `dev`/`none`/`unknown`, add the `runtime/debug.ReadBuildInfo()`
  fallback from the `go` skill, in a pure helper with a table-driven test.
- **Test hygiene** — convert ad-hoc tests to table-driven subtests; isolate with `t.TempDir`/`t.Setenv`.
  If a test reaches an external command (e.g. a CLI that reads the system keyring), make that call an
  **overridable package var** and stub it in the test — a test must never pick up or log real
  credentials. (This is a real bug, not just a style nit.)

### Lint/CI/release config — `releng`

- `.golangci.yml` — `version: "2"`, the standard linter set, `gofmt` formatter enabled.
- `.github/workflows/ci.yml` — test / lint / build jobs per the `go` skill, pins per the Standard table.
- `.goreleaser.yml` (binary repos) — `version: 2`, builds matrix, ldflags injecting
  `main.version/commit/date`; a `release.yml` triggered on `v*` tags.

### Docs — `infoarch`

Rewrite stubs with real content: what it does, install (`go install ...@latest`), usage/flags,
build/test commands. `AGENTS.md` (never `CLAUDE.md`): purpose, package map, lint/test/release
commands, anything quirky. **Repo-facing content only** — no machine-specific paths or host tooling
in committed docs; that lives in the project's environment `AGENTS.md`.

### Lint locally, then review

```bash
gofmt -l . ; go vet ./... && golangci-lint run && go test -race ./...
```

Fix everything before proceeding, then dispatch the read-only reviewers **in parallel** on the diff:

- **`devrev`** — correctness: error handling, edge cases, goroutine/race issues, tests that false-pass.
- **`secrev`** — committed secrets/tokens, hardcoded IPs/hosts, command injection, download-and-exec
  installers, tests that leak real credentials, unpinned supply-chain risk.

Triage findings: fix the real ones; discard verified cold-start mistakes.

### Test — `qa`

Run `go test -race ./...`; `qa` confirms green from the **actual output**, not just the exit code.
Background it and start the next repo's phases while it runs, but **confirm PASS before opening the PR**.

---

## Phase 4 — Deep hygiene (DRY + readiness)

A quality lens beyond lint markers. `architect` analyses (read-only), `devrev` vets, `devlead`
applies. Look for: dead code and unused exports (`unused`/`staticcheck`); duplicated logic that a
helper or generic collapses; over-broad interfaces (accept interfaces, return structs); error strings
that should wrap; missing `context.Context` plumbing on blocking calls; and tests that assert on
literals tied to a moving value (e.g. the real release version) instead of a synthetic fixture.

**Policy: propose, don't auto-apply.** Apply only low-risk, behavior-preserving cleanups on the
branch; list anything that could change behavior as a **"Proposed follow-ups"** section in the PR
body for the maintainer. Don't bundle risky refactors into the modernization PR. When a cleanup
changes the public surface, have `infoarch` update the docs in the same PR.

---

## Commit, PR, and watch CI

One PR per repo, after all fixes land and `go test -race` passes locally:

- Conventional-commit message(s) on `update-repo`; attribute with the `Co-Authored-By:` trailer.
- Title: `Modernize: <repo-name>` (or a precise `fix:`/`feat:` if scoped to one change).
- Body: bullet list of changes + a test-plan checklist + any Phase 4 "Proposed follow-ups".
- **Never push to main; never auto-merge.** Open the PR and let the maintainer merge.

```bash
RUN=$(gh run list --branch update-repo --json databaseId --limit 1 --jq '.[0].databaseId')
gh run watch $RUN
gh run view $RUN --json jobs --jq '.jobs[] | "\(.name): \(.conclusion)"'
```

On failure: `gh run view --log-failed $RUN | tail -80`, fix locally → re-lint/test → push (the open
PR picks it up). Repeat until Test ✅ Lint ✅ Build ✅.

---

## Wrap-up — fold learnings back

Once the run is wrapped up, invoke **`/skill-creator`** to update this skill (or the `go` skill) with
anything **durable and general** the session surfaced — a new bug pattern, a shifted pin, a CI
breakage and its fix, a sharper triage check. Skip one-off repo specifics (those belong in the repo's
`AGENTS.md`). Keep it lean: prefer a tightened line over a new template, and trim at least as much as
you add.

---

## Notes

- **`go-version` vs `go.mod`** — keep the CI `go-version` aligned with the `go.mod` directive; a CI
  Go newer than the floor can pass while `go install` on the floor fails, and vice versa.
- **`golangci-lint` pinning** — pin the action's `version:` to a full tag; the v2 config schema
  (`version: "2"`) is required by recent releases and rejected by old ones, so the pin and the config
  schema must move together.
- **`-race` needs CGO** — the race detector requires `CGO_ENABLED=1` (the default); don't set
  `CGO_ENABLED=0` on the test job, only on the static build job.
- **Transient CI failures — re-run, don't debug** — Go module proxy hiccups (`proxy.golang.org`
  timeouts) and toolchain download flakes are environmental; `gh run rerun` before investigating.
- **PR branch hygiene** — before opening a PR, confirm `git log --oneline origin/main..update-repo`
  shows only intended commits; a reused `update-repo` from a prior merged PR needs
  `git push --force-with-lease` to overwrite the stale remote branch.
