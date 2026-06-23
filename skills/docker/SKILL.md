---
name: docker-skill
description: Docker image conventions — structure, multi-arch builds, linting, and Swarm deploy
---

# Docker Skill

Portable conventions for Docker image repos. Local runtime specifics (container shims, Swarm
wrappers) live in the project's `AGENTS.md`, not here.

## Repo Structure

Standard layout for all `docker-*` repos:

```
Dockerfile
docker-compose.yml    # local dev
Makefile              # build / push / deploy / local targets
.github/workflows/    # build + push GHA
README.md
AGENTS.md
```

## Makefile Targets

```bash
make build    # docker build
make push     # docker push
make deploy   # docker stack deploy
make local    # docker-compose up (dev)
```

## Build Conventions

- Build and test images with a local tag (e.g. `local/<name>:test`); don't rely on
  previously-pushed registry tags.
- Support `amd64` and `arm64` where relevant (use buildx).
- Lint Dockerfiles with `hadolint`.

## Swarm Deployment

```bash
docker stack deploy --resolve-image never -c docker-compose.yml <stack-name>
```

Use `--resolve-image never` so stale registry tags don't shadow locally-built images.

## ARM Images (`arm-*` repos)

- Single `Dockerfile` with `--platform` arg
- GitHub Actions buildx for multi-arch
- No Jenkinsfiles (legacy — replace with GHA)
