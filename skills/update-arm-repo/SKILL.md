---
name: update-arm-repo
description: Walk all arm-* repos alphabetically and revive each one as a working multi-arch image build (single Dockerfile, GitHub Actions buildx, README, AGENTS.md)
---

Scan your projects directory for all `arm-*` directories, sort them alphabetically, and work
through each one in order. Inspect each repo's current state live — do not rely on any saved
status list.

These are typically old Docker image builds from an early Raspberry Pi / ARM swarm cluster, built
back when upstream projects didn't publish ARM images: per-arch Dockerfiles (`Dockerfile_aarch64`,
`Dockerfile_armv7l`), a Makefile keyed off `uname -m`, a legacy CI file that ran on ARM-labeled
nodes, and compose/stack files for the swarm.

**The goal is revival, not archival**: each repo should end up building a working multi-arch image
via GitHub Actions buildx — the same end state as the `docker-*` repos. **Platform floor is a
Raspberry Pi 3**: build `linux/amd64,linux/arm64,linux/arm/v7`. Check the base supports arm/v7
first (`docker manifest inspect <base> | grep architecture`); if upstream doesn't publish arm/v7
(e.g. elasticsearch — modern ES is 64-bit only), drop it and call that out in the README and PR
body. Use a known-good repo of yours as the model for the workflow/Makefile/AGENTS.md shape.

**A repo needs updating** if any of the following are true (for freshly ported repos, all of them):

- Per-arch `Dockerfile_*` files instead of a single multi-arch `Dockerfile`
- No `.github/workflows/build.yml` (a legacy `Jenkinsfile` exists — delete it once Actions works)
- Base image is dead, unpinned, or EOL; or the Dockerfile builds upstream from a git clone of master because no binaries existed for ARM at the time
- `AGENTS.md` is missing; README missing, a stub, or describing the old CI/swarm flow as current

Work through all repos in a single run. After finishing each repo, move to the next without stopping.

---

## Steps (apply to each repo in turn)

### 1. Understand the repo

Read all `Dockerfile*`, `Makefile`, `docker-compose.yml`/stack files, the legacy CI file, and
`README.md`. Figure out: what the image does, what upstream it wraps, the current upstream version,
and a smoke-test command (version flag or HTTP health endpoint).

### 2. Consolidate to one multi-arch Dockerfile

- Merge `Dockerfile_aarch64`/`Dockerfile_armv7l` into a single `Dockerfile`; delete the per-arch files. Modern official bases are multi-arch manifests — `arm64v8/golang`-style arch-prefixed bases become plain `docker.io/golang:<tag>` etc.
- Pin the base to a current, supported tag. If the old Dockerfile compiled upstream from a git clone of master (the workaround for missing ARM binaries), prefer the modern route: pin an upstream release version via `ARG`/`ENV` and download the official multi-arch binary, or base directly on the official image and add the repo's config on top.
- Use `TARGETARCH` (`ARG TARGETARCH`) when a download URL needs the architecture — buildx sets it per platform.
- `MAINTAINER` → `LABEL org.opencontainers.image.authors="<your-email>"`; combine chained `RUN`s; clean caches in-layer.
- Lint: `docker run --rm -i hadolint/hadolint < Dockerfile` and fix findings (inline `# hadolint ignore=DL3008` for apt-pinning, as in the docker-\* walk).

### 3. Update the Makefile and compose file

Standard Makefile shape, but **keep the swarm `deploy` target** — the compose files stay swarm-deployable:

```makefile
.EXPORT_ALL_VARIABLES:
IMAGE = "<owner>/<repo-name>"
TAG = latest
STACK = "<stack-name-from-original>"

all: build

build:
	@docker build -t ${IMAGE}:$(TAG) .

push:
	@docker push ${IMAGE}:$(TAG)

deploy:
	@docker stack deploy -c docker-compose.yml ${STACK}

.PHONY: all build push deploy
```

**Compose files: preserve the stack wiring, modernize the rest.** These repos often form one stack
joined by a shared external overlay network — services find each other by name across it, so
removing it breaks the stack. Keep: the external overlay network, `deploy:` sections, and host-path
volumes (note them in the README). Drop/fix: `placement.constraints` on `node.labels.arch`
(obsolete with multi-arch images), per-arch image tags (`:aarch64` → `:latest`), and the deprecated
top-level `version:` key. Validate with `docker compose -f docker-compose.yml config -q`.

### 4. Add `.github/workflows/build.yml`

Same template as the docker-\* walk, except `platforms` always includes arm (that's the point of
these repos):

```yaml
---
name: Build

on:
  pull_request:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  test:
    name: Test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5

      - name: Test building image.
        run: docker build -t test-image .

      - name: Run the built image.
        run: docker run --name test-container -d test-image tail -f /dev/null

      - name: Verify the image works.
        run: docker exec --tty test-container env TERM=xterm <verify-command>

  release:
    name: Release
    runs-on: ubuntu-latest
    needs: test
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v5
      - uses: docker/setup-qemu-action@v3
      - uses: docker/setup-buildx-action@v3

      - name: Login to DockerHub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

      - name: Build and push image.
        uses: docker/build-push-action@v6
        with:
          context: ./
          file: Dockerfile
          platforms: linux/amd64,linux/arm64,linux/arm/v7
          push: true
          tags: ${{ github.repository }}:latest
```

- This template publishes to **Docker Hub** — `${{ github.repository }}` with no registry prefix resolves to `docker.io/<owner>/<repo-name>`. (Use `ghcr.io/...` + `GITHUB_TOKEN` instead if you prefer GHCR.)
- Configure `DOCKERHUB_USERNAME`/`DOCKERHUB_TOKEN` repo secrets (`gh secret set`); required for the push to authenticate.
- Adapt the verify step per image (daemons may need a sleep + `curl` health check instead of `exec`).
- Delete the `Jenkinsfile` in the same PR.

### 5. Update `README.md`

**Short and scannable.** One-line purpose, badge, then code blocks: pull/run, swarm deploy, build.
At most one sentence of history. Name the upstream image once. No prose paragraphs, no legacy-CI
references.

### 6. Add `AGENTS.md`

Create `AGENTS.md` (not `CLAUDE.md`), equally terse: one-line purpose, commands block, one-line CI
description, then only genuinely non-obvious quirks as bullets. Don't repeat the README or restate
what the Dockerfile shows. **Repo-facing content only** — never put machine-specific notes (host
container runtime, local venv paths) into committed docs; that context lives in the project's
environment notes (`AGENTS.md` at the config root).

### 7. Build and test locally

Local builds are single-arch (arm is exercised by buildx in CI):

```bash
docker build -t <owner>/<repo-name>:latest .
docker run --rm <owner>/<repo-name>:latest <verify-command>
```

Fix build failures before committing — dead package URLs and removed upstream tags are the usual
culprits. (If your local `docker` is a Podman shim, fully qualify images as `docker.io/...`.)

### 8. Commit, push, open PR

- Branch name: `update-repo`
- Commit message: summarise what changed and why
- PR title: `Modernize: <repo-name>`
- PR body: bullet list of changes (consolidation, base bump, version pinned, CI added, Jenkinsfile removed)

### 9. Monitor CI and fix failures

```bash
RUN=$(gh run list --branch update-repo --json databaseId --limit 1 --jq '.[0].databaseId')
gh run watch $RUN
gh run view $RUN --json jobs --jq '.jobs[] | "\(.name): \(.conclusion)"'
```

If a job fails: `gh run view --log-failed $RUN | tail -60`, fix locally, rebuild, push, watch the
next run. Repeat until Test ✅ Release ⏭ (skipped on PR, runs on merge to main).

---

## Notes

- **Freshly ported repos won't run CI**: check `gh api repos/<owner>/<repo>/actions/permissions` → if `"enabled":false`, fix with `gh api -X PUT repos/<owner>/<repo>/actions/permissions -F enabled=true` (only `-F enabled=true` — do not set `allowed_actions`). Close/reopen the PR to trigger the first run.
- If a repo still uses `master` as its default branch, rename it: `gh api -X POST repos/<owner>/<repo>/branches/master/rename -f new_name=main`, then locally `git branch -m master main && git fetch --prune && git branch -u origin/main main && git remote set-head origin -a`.
- Helper-binary repos exist because the binaries lacked ARM builds at the time; many now ship official multi-arch releases — pin the current release version and pull the right arch via `TARGETARCH`.
- Compose/stack-only content keeps working compose files updated to modern image tags; validate with `docker compose config -q`.
- **Do not strip the swarm wiring from compose files** — the shared external overlay network is how the stack's services find each other; the goal is a stack that can be redeployed on a future swarm (see step 3).
