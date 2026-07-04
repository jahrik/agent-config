---
name: go
description: Go project conventions — module layout, gofmt/vet/golangci-lint, table-driven tests, GoReleaser+ldflags versioning, and CI. Use when writing or updating a Go project, its dependencies, or its lint/CI setup.
---

# Go Skill

## Conventions

- **Formatting:** `gofmt` (CI fails on unformatted code) — `gofmt -w .`
- **Vetting:** `go vet ./...` in every build and CI run
- **Linting:** `golangci-lint` via checked-in `.golangci.yml` (errcheck, govet, ineffassign,
  staticcheck, unused at minimum)
- **Modules:** `go mod tidy` after any dependency change; pin a recent stable in `go.mod`
  (`go 1.23.0`) and match it in CI
- **Errors:** wrap with `fmt.Errorf("...: %w", err)`; never discard errors silently
- **Tests:** table-driven with subtests (`t.Run`); isolate with `t.TempDir`/`t.Setenv` — never let
  a test read real credentials or escape its sandbox (make external calls injectable)

## Common commands

```bash
go build ./... && go vet ./...
gofmt -l .                # empty = clean
golangci-lint run
go test -race -coverprofile=coverage.out ./...
go mod tidy
```

`-race` forces `CGO_ENABLED=1` (needs a C compiler). On minimal/immutable hosts don't skip race
tests: run them in a container/toolbox or rely on CI. Never paper over it with `CGO_ENABLED=0`.

## Versioning + CI

`--version` showing `dev (commit none, built unknown)` means the GoReleaser ldflags defaults
leaked — add the `runtime/debug.ReadBuildInfo()` fallback (guarding `"(devel)"`/empty) in a pure,
table-tested helper. Never use `git describe` as the version source of truth.

CI: test (`vet` + `-race`), lint (pinned golangci-lint action), build (`CGO_ENABLED=0`); releases
on `v*` tags via `release.yml` → GoReleaser.

Full layout, the versioning-trap rationale, and CI job details: `references/versioning-ci.md`.
