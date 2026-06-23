---
name: update-docker-repo
description: Walk all docker-* repos alphabetically and modernize each one (GitHub Actions build, Dockerfile lint, README, AGENTS.md)
---

Scan your projects directory for all `docker-*` directories, sort them alphabetically, and
work through each one in order. For each repo, inspect its current state live to determine what
needs updating — do not rely on any saved status list.

**Skip a repo** if it is a fork of someone else's project (check `gh repo view <owner>/<repo> --json isFork`
or `git remote -v` for an `upstream` remote), or if it has no `Dockerfile` at the root or in
obvious subdirs (e.g. README-only repos, or compose stacks of third-party images — for those,
only do README/AGENTS.md, skip build CI).

**A repo needs updating** if any of the following are true:

- No `.github/workflows/build.yml` (legacy `Jenkinsfile` present — replace it, delete once Actions works)
- Workflow uses `actions/checkout` older than `@v5` or old docker action versions
- `AGENTS.md` is missing
- README is missing, a stub, or describes an old CI flow
- Dockerfile uses a dead/EOL base image or deprecated syntax (`MAINTAINER`, no pinned base tag)

Work through all repos in a single run. After finishing each repo, move to the next without
stopping. Use a known-good repo of yours as the model for the workflow, Makefile, and AGENTS.md.

---

## Steps (apply to each repo in turn)

### 1. Understand the repo

Read `Dockerfile`, `Makefile`, `docker-compose.yml`, `Jenkinsfile` (if present), and `README.md`.
Figure out: what image it produces, the published image name (GHCR by default —
`ghcr.io/<owner>/<repo-name>`), build args/flags it needs, and how to verify the image works (a
command to run inside the container). An image that other repos pull by a fixed name may need to
stay on its existing registry — keep that one as-is.

### 2. Fix the Dockerfile

- Replace deprecated `MAINTAINER` with `LABEL org.opencontainers.image.authors="<your-email>"`
- Pin the base image to a current, supported tag — check the upstream image still exists and isn't EOL
- Combine consecutive `RUN` lines that just chain package installs; clean package caches in the same layer
- Run hadolint and fix what it reports:

```bash
docker run --rm -i hadolint/hadolint < Dockerfile
```

### 3. Update the Makefile

Standard shape — use the GHCR image name to match the release workflow below:

```makefile
.EXPORT_ALL_VARIABLES:
IMAGE = "ghcr.io/<owner>/<repo-name>"
TAG = latest

all: build

build:
	@docker build -t ${IMAGE}:$(TAG) .

push:
	@docker push ${IMAGE}:$(TAG)

.PHONY: all build push
```

Keep any repo-specific flags that exist for a reason (e.g. `--ulimit nofile=1024:524288` for fakeroot).

### 4. Add `.github/workflows/build.yml`

Template (adapt the verify step to the image):

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

      - name: Login to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and push image.
        uses: docker/build-push-action@v6
        with:
          context: ./
          file: Dockerfile
          platforms: linux/amd64,linux/arm64
          push: true
          tags: ghcr.io/${{ github.repository }}:latest
```

- Add `permissions: contents: read` and `packages: write` at the job level (required for `GITHUB_TOKEN` to push to ghcr.io).
- Add `schedule: cron` only for base images other things depend on.
- Drop `platforms: linux/arm64` if the image can't build for arm.
- No secrets to configure — `GITHUB_TOKEN` is available in every Actions run. (An image kept on a
  different registry needs that registry's credentials as secrets instead.)
- Delete the `Jenkinsfile` in the same PR once the Actions workflow is in place.

### 5. Update `README.md`

Real content: what the image is, the pull command (`docker pull ghcr.io/<owner>/<repo-name>`), how
to build (`make build`), how to run it (compose or `docker run` example), and any required flags.
No legacy-CI references.

### 6. Add `AGENTS.md`

**Repo-facing content only** — never put machine-specific notes (host container runtime, local venv
paths) into committed docs; that context lives in the project's environment notes (`AGENTS.md` at
the config root). Keep it short and scannable: commands first, minimal prose.
Create `AGENTS.md` (not `CLAUDE.md`) with:

- Image purpose (one paragraph)
- Build & push commands
- CI pipeline description
- Image internals (base, key packages, users, entrypoint quirks)

### 7. Build and test locally

```bash
make build
docker run --rm -it ghcr.io/<owner>/<repo-name>:latest <verify-command>
```

Fix build failures before committing. Old repos often fail on dead package-repo URLs in the
Dockerfile — update them. (If your local `docker` is a Podman shim, fully qualify base images as
`docker.io/...` or short-name resolution fails.)

### 8. Commit, push, open PR

- Branch name: `update-repo`
- Commit message: summarise what changed and why
- PR title: `Modernize: <repo-name>`
- PR body: bullet list of changes made

### 9. Monitor CI and fix failures

```bash
RUN=$(gh run list --branch update-repo --json databaseId --limit 1 --jq '.[0].databaseId')
gh run watch $RUN
gh run view $RUN --json jobs --jq '.jobs[] | "\(.name): \(.conclusion)"'
```

If a job fails: `gh run view --log-failed $RUN | tail -60`, fix locally, rebuild with `make build`,
push, watch the next run. Repeat until Test ✅ Release ⏭ (skipped on PR, runs on merge to main).

---

## Notes

- **Dormant repos won't run CI**: old repos often have Actions disabled entirely
  (`gh api repos/<owner>/<repo>/actions/permissions` → `"enabled":false`; fix with
  `gh api -X PUT ... -F enabled=true`) or the individual workflow auto-disabled for inactivity
  (`gh workflow list --all` shows `disabled_inactivity`; fix with `gh workflow enable build.yml`).
  After fixing, close/reopen the PR to trigger the run.
- Compose-stack repos without their own Dockerfile get only README + AGENTS.md treatment.
- Multi-arch (`arm64`) builds need qemu in CI; a local single-arch daemon builds amd64 only.
