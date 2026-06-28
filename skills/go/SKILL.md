---
name: go
description: Go project conventions — module layout, gofmt/vet/golangci-lint, table-driven tests, GoReleaser+ldflags versioning, and CI. Use when writing or updating a Go project, its dependencies, or its lint/CI setup.
---

# Go Skill

## Conventions

- **Formatting:** `gofmt` (enforced; CI fails on unformatted code) — run `gofmt -w .`
- **Vetting:** `go vet ./...` is part of every build and CI run
- **Linting:** `golangci-lint` driven by a checked-in `.golangci.yml` (errcheck, govet,
  ineffassign, staticcheck, unused at minimum)
- **Modules:** `go.mod` + `go.sum`, `go mod tidy` after any dependency change
- **Go version:** pin a recent stable in `go.mod` (`go 1.23.0`) and match it in CI
- **Errors:** wrap with `fmt.Errorf("...: %w", err)`; never discard errors silently
- **Tests:** table-driven with subtests (`t.Run`); use `t.TempDir`/`t.Setenv` for isolation —
  never let a test read real credentials or escape its sandbox (make external calls injectable)

## Project Structure

```
main.go               # thin entry point; wires build-time vars into the command
cmd/                  # CLI command definitions (e.g. cobra) + their tests
internal/             # private packages, not importable by other modules
  <pkg>/<pkg>.go
  <pkg>/<pkg>_test.go
go.mod
go.sum
.golangci.yml         # linter config
.goreleaser.yml       # release build + ldflags version injection
.github/workflows/    # ci.yml (test/lint/build) + release.yml (tag → GoReleaser)
README.md
AGENTS.md
```

## Common Commands

```bash
go build ./...            # compile everything
go vet ./...              # static checks
gofmt -l .                # list unformatted files (empty = clean)
gofmt -w .                # format in place
golangci-lint run         # lint per .golangci.yml
go test ./...             # run tests
go test -race -coverprofile=coverage.out ./...   # race detector + coverage
go mod tidy               # sync go.mod/go.sum with imports
```

## Versioning (the `dev` / `none` / `unknown` trap)

Build metadata is injected by GoReleaser via ldflags, but `go install` and local `go build`
pass no ldflags — so the defaults leak into `--version`:

```go
// main.go — set at build time by GoReleaser
var (
    version = "dev"
    commit  = "none"
    date    = "unknown"
)
```

```yaml
# .goreleaser.yml
ldflags:
  - -s -w -X main.version={{.Version}} -X main.commit={{.Commit}} -X main.date={{.Date}}
```

Fall back to `runtime/debug.ReadBuildInfo()` when the values are still defaults: `info.Main.Version`
matches the git tag for `go install ...@vX`, and the `vcs.revision`/`vcs.time` build settings give
the real commit and timestamp for local builds. Keep the fallback in a pure helper that takes a
`*debug.BuildInfo` so the merge logic is unit-testable without a real build. Guard against
`info.Main.Version == "(devel)"` (and `""`) — `go run` and builds from a tree with no `.git` report
that, and printing the literal `(devel)` as a version is worse than keeping `dev`. (On Go ≥ ~1.24 a
plain in-repo `go build` stamps a VCS _pseudo-version_ like `v0.1.10-0.2026…-abc` rather than
`(devel)`, so the guard mainly bites `go run` / no-VCS builds.)

**Why this and not `git describe`:** ldflags-for-releases + `ReadBuildInfo`-fallback is the
recommended hybrid. `git describe` needs the `.git` dir _at build time_, which the module cache
(`go install ...@latest`) doesn't have — so it can't fill the `go install` gap that motivates this
fallback at all. At runtime it's wrong (the installed binary isn't in any checkout). For releases
it's redundant — GoReleaser's `{{.Version}}` already _is_ `git describe`. A repo shelling out to git
at runtime does **not** imply git-at-build-time. A `git describe` Makefile target is fine _only_ as
local-dev polish for prettier dirty-build strings — never as the version source of truth.

## CI Pattern

GitHub Actions on PR (and push to the default branch), using `actions/setup-go` with `cache: true`,
pinning `go-version` to match `go.mod`. Three jobs:

- **test** — `go vet ./...` then `go test -race -coverprofile=coverage.out ./...`
- **lint** — `golangci/golangci-lint-action` with a pinned `version:`
- **build** — `CGO_ENABLED=0 go build` for the target platform(s)

Releases run on `v*` tags via a separate `release.yml` that calls GoReleaser (which re-injects the
ldflags above).
