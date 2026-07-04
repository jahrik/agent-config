# ARM multi-arch images (`arm-*`)

Shared machinery: `common.md`. Everything in `docker.md` applies; this file is the arm-specific
delta. **The goal is revival, not archival** — each repo ends as a working multi-arch build, same
end state as `docker-*`.

These are old Raspberry Pi / ARM swarm builds from before upstreams published ARM images: per-arch
Dockerfiles (`Dockerfile_aarch64`, `Dockerfile_armv7l`), a `uname -m` Makefile, legacy CI on
ARM-labeled nodes, swarm stack files.

## Platform floor: Raspberry Pi 3

Build `linux/amd64,linux/arm64,linux/arm/v7`. Check the base supports arm/v7 first
(`docker manifest inspect <base> | grep architecture`); if upstream dropped it (e.g. modern
elasticsearch is 64-bit only), drop arm/v7 and call it out in README + PR body.

## Triage (beyond docker.md)

- Per-arch `Dockerfile_*` files instead of one multi-arch `Dockerfile`
- Dockerfile builds upstream from a git clone of master (the old no-ARM-binaries workaround)

## Arm-specific steps

- **Consolidate to one Dockerfile** — merge the per-arch files, delete them. Arch-prefixed bases
  (`arm64v8/golang`) become plain multi-arch manifests (`docker.io/golang:<tag>`). Where the old
  file compiled from source, prefer pinning an upstream release via `ARG`/`ENV` and downloading the
  official multi-arch binary — many upstreams ship them now. Use `ARG TARGETARCH` when a download
  URL needs the arch; buildx sets it per platform.
- **Makefile keeps the swarm `deploy` target** (`docker stack deploy -c docker-compose.yml
${STACK}`) — the compose files stay swarm-deployable.
- **Compose: preserve the stack wiring, modernize the rest.** Keep the shared external overlay
  network (services find each other by name across it — removing it breaks the stack), `deploy:`
  sections, and host-path volumes (note them in the README). Drop/fix: `placement.constraints` on
  `node.labels.arch` (obsolete with multi-arch), per-arch image tags (`:aarch64` → `:latest`), the
  deprecated top-level `version:` key. Validate: `docker compose -f docker-compose.yml config -q`.
- **`build.yml`** — the docker.md template, but `platforms` always includes arm (that's the point)
  and these repos publish to **Docker Hub**: `docker/login-action@v3` with
  `DOCKERHUB_USERNAME`/`DOCKERHUB_TOKEN` repo secrets (setting secrets is an admin write with no
  mcp-github tool — hand it to the maintainer), tags `${{ github.repository }}:latest`
  (no registry prefix → docker.io).
- Local builds are single-arch; arm is exercised by buildx in CI.

## Notes

- **Freshly ported repos won't run CI** — same Actions-permissions gap as docker.md (check with
  `gh_api_get`; the enable toggle goes to the maintainer).
- **`master` default branch** — the rename is a repo-admin write with no mcp-github tool (open an
  issue / hand to the maintainer); once renamed remotely, locally:
  `git branch -m master main && git fetch --prune && git branch -u origin/main main &&
git remote set-head origin -a`.
