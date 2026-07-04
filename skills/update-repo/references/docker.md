# Docker images (`docker-*`)

Shared machinery: `common.md`. Conventions: the `docker` skill.

Skip forks (`gh_repo_get` `isFork` / an `upstream` remote). Repos with no Dockerfile
(README-only, compose stacks of third-party images) get only README + AGENTS.md — no build CI.

## Triage checklist

- No `.github/workflows/build.yml` (legacy `Jenkinsfile` — replace, delete once Actions works)
- `actions/checkout` older than `@v5` or old docker action versions
- `AGENTS.md` missing; README missing/stub/describing old CI
- Dead/EOL base image or deprecated syntax (`MAINTAINER`, unpinned base tag)

## Steps

1. **Understand** — read `Dockerfile`, `Makefile`, compose, `Jenkinsfile`, README. Establish: image
   purpose, published name (GHCR default — `ghcr.io/<owner>/<repo>`), build args, a verify command.
   An image other repos pull by fixed name stays on its existing registry.
2. **Dockerfile** — `MAINTAINER` → `LABEL org.opencontainers.image.authors=`; pin base to a
   current supported tag; combine chained `RUN`s, clean caches in-layer; lint:
   `docker run --rm -i hadolint/hadolint < Dockerfile` (inline `# hadolint ignore=DL3008` for
   apt-pinning).
3. **Makefile** — standard shape: `IMAGE = "ghcr.io/<owner>/<repo>"`, `TAG = latest`,
   `build`/`push` targets (`docker build -t ${IMAGE}:$(TAG) .`). Keep repo-specific flags that
   exist for a reason (e.g. `--ulimit nofile=` for fakeroot).
4. **`build.yml`** — `test` job (checkout → `docker build -t test-image .` → run detached →
   `docker exec` the verify command) + `release` job (`needs: test`,
   `if: github.ref == 'refs/heads/main'`, qemu + buildx + `docker/login-action@v3` to ghcr.io with
   `GITHUB_TOKEN` → `docker/build-push-action@v6`, `platforms: linux/amd64,linux/arm64`,
   `tags: ghcr.io/${{ github.repository }}:latest`). Job-level `permissions: contents: read,
packages: write` (required for GHCR push). Daemons may need sleep + `curl` health instead of
   `exec`. Drop arm64 if the image can't build for it. Delete the `Jenkinsfile` in the same PR.
   Copy the full template from a known-good `docker-*` repo of yours.
5. **README** — what the image is, pull/build/run commands, required flags. No legacy-CI prose.
6. **AGENTS.md** — purpose, build/push commands, CI description, image internals (base, packages,
   entrypoint quirks).
7. **Local build + test** — `make build`, run the verify command. Dead package-repo URLs are the
   usual failure. Podman shim: fully qualify bases as `docker.io/...`.

## Notes

- **Dormant repos won't run CI** — Actions disabled entirely
  (`gh_api_get` `repos/<owner>/<repo>/actions/permissions` → `enabled:false`) or the workflow
  auto-disabled for inactivity. Re-enabling is an admin write with no mcp-github tool yet — open
  an issue on the MCP server's repo and hand the toggle to the maintainer, then close/reopen the
  PR to trigger the first run.
- Multi-arch needs qemu in CI; local single-arch daemons build amd64 only.
- `schedule: cron` only for base images other things depend on.
