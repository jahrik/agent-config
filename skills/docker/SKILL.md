---
name: docker-skill
description: Docker image conventions, Swarm deployment, and dswarm patterns for this homelab
---

# Docker Skill

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
make deploy   # dswarm stack deploy
make local    # docker-compose up (dev)
```

## Build Conventions

- Build and test images as `local/<name>:test` — never use stale `jahrik/*` Hub tags
- Support `amd64` and `arm64v8` where relevant (use buildx)
- Lint Dockerfiles with `hadolint`

## Swarm Deployment (dswarm)

```bash
dswarm stack deploy --resolve-image never -c docker-compose.yml <stack-name>
dswarm service ls
dswarm service logs <service>
```

**Always use `--resolve-image never`** — Docker Hub tags may be stale.

If published ports don't respond, load `br_netfilter`:

```bash
sudo modprobe br_netfilter
```

Test via internal overlay if ingress is unavailable:

```bash
dswarm exec <container> wget -qO- http://localhost:<port>
```

## ARM Images (`arm-*` repos)

- Single `Dockerfile` with `--platform` arg
- GitHub Actions buildx for multi-arch
- No Jenkinsfiles (legacy — replace with GHA)
