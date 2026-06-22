---
name: homelab-skill
description: Homelab infrastructure context — SteamOS/Arch workstation, Podman, Swarm, Ansible pipelines

---

# Homelab Skill

## Environment Overview

- **Workstation OS:** Arch Linux (SteamOS on Steam Deck)
- **Container runtime:** Podman (Docker shim at `~/.local/bin/docker`)
- **Orchestration:** Docker Swarm (running in `dind` container under Podman)
- **Config management:** Ansible (venv at `/home/deck/.venv/ansible`, core 2.16)
- **Shell:** zsh
- **Editor:** Neovim
- **All repos:** `~/github/<repo-name>`

## Key Wrappers

| Command | What it does |
|---------|-------------|
| `mtest` | Molecule wrapper with correct DOCKER_HOST and PATH |
| `dswarm` | Docker CLI against the dind Swarm (`tcp://127.0.0.1:2375`) |

## Podman Socket

```bash
systemctl --user enable --now podman.socket
# Socket path:
DOCKER_HOST=unix:///run/user/1000/podman/podman.sock
```

## dind Swarm Container

```bash
podman start dind          # after reboot
dswarm service ls          # verify swarm is up
```

Overlay networks pre-created: `monitor`, `elk`

Monitor stack harness: `~/.config/dind/monitor/monitor-stack.yml`

## Ansible Galaxy

Each ansible role has its own `GALAXY_API_KEY` GitHub secret.
Venv: `/home/deck/.venv/ansible`

If galaxy role install fails with "doesn't appear to contain a role":
```bash
rm -rf ~/.ansible/roles/jahrik.*
ansible-galaxy install -r requirements.yml
```

## Repo Categories

| Pattern | Type |
|---------|------|
| `ansible-*` | Ansible roles |
| `docker-*` | Docker images / compose stacks |
| `arm-*` | ARM architecture Docker images |
| `home_lab` | Main Ansible + Swarm deployment pipeline |
