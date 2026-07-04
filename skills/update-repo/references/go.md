# Go projects (`go.mod`)

Shared machinery: `common.md`. Conventions (layout, tooling, versioning): the `go` skill — this is
the procedure that applies them.

## Current Standard

| Knob                            | Current value                                             |
| ------------------------------- | --------------------------------------------------------- |
| `go.mod` Go version             | recent stable (e.g. `1.23.0`); CI `go-version` matches    |
| `actions/checkout`              | `@v7`                                                     |
| `actions/setup-go`              | `@v6` with `cache: true`                                  |
| `actions/upload-artifact`       | `@v7`                                                     |
| `golangci/golangci-lint-action` | `@v7` with a pinned full-tag `version:` (e.g. `v2.12.2`)  |
| `golangci-lint` linters         | errcheck, govet, ineffassign, staticcheck, unused + gofmt |
| GoReleaser config               | `version: 2`; ldflags inject `main.version/commit/date`   |

## Triage checklist

Needs remediation if any hold:

- `go vet ./...` or `gofmt -l .` non-empty; no `.golangci.yml` or `golangci-lint run` reports issues
- No CI workflow, or pins drift from the table
- `--version` reports `dev (commit none, built unknown)` with no `ReadBuildInfo` fallback (see `go` skill)
- `.goreleaser.yml` missing on a binary-shipping repo, or ldflags don't inject version/commit/date
- Stale or vulnerable deps (`govulncheck ./...` if available)
- Tests absent for non-trivial logic, not table-driven, or reading real credentials / escaping the sandbox
- `AGENTS.md` missing; README missing/stub

## Fix code (`devlead`)

- `go vet`, `gofmt`, and every `golangci-lint run` finding clean. Wrap errors with `%w`; never
  discard an error.
- **Version trap** — `dev`/`none`/`unknown` from `--version`: add the
  `runtime/debug.ReadBuildInfo()` fallback (see `go` skill) in a pure helper with a table test.
- **Test hygiene** — table-driven subtests; isolate with `t.TempDir`/`t.Setenv`. A test reaching an
  external command (e.g. a system keyring) must go through an **overridable package var** stubbed
  in tests — never pick up or log real credentials.

## Config (`releng`)

`.golangci.yml` (`version: "2"`, standard linters, gofmt formatter); `ci.yml` test/lint/build jobs
per the `go` skill; `.goreleaser.yml` on binary repos (`version: 2`, builds matrix, version
ldflags) + `release.yml` on `v*` tags.

## Test

`go test -race ./...`; `qa` confirms green from actual output, not the exit code.

## Release — tag after merge (explicit go-ahead required)

`release.yml` on `v*` tags only fires on a pushed tag — merging isn't enough. Pick the bump from
commits since `git describe --tags --abbrev=0` (`fix:` → patch, `feat:` → minor, breaking → major).
Tag `main` after merge, never a feature branch; push an **annotated** tag; confirm the release run
started (`gh_run_list`, workflow-filtered). Never tag pre-merge or auto-release.

## Notes

- **`go-version` vs `go.mod`** — keep aligned; `go get -u` can silently raise the `go` directive to
  a dep's minimum — re-check and realign every workflow after dep bumps.
- **Major-version dep bumps are a code migration** — import path _and_ API change; skim the
  changelog, let `go build ./...` drive; take dep-drop simplifications the new major enables.
- **`golangci-lint` pinning** — the v2 config schema and the pinned tool version must move together.
- **`-race` needs CGO** — don't set `CGO_ENABLED=0` on the test job, only the static build job.
