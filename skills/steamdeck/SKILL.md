---
name: steamdeck-skill
description: Steam Deck workstation context — SteamOS/Arch, Podman, dind Swarm, Ansible pipelines
---

# Steam Deck Skill

## Environment Overview

- **Workstation OS:** Arch Linux (SteamOS on Steam Deck)
- **Container runtime:** Podman (Docker shim at `~/.local/bin/docker`)
- **Orchestration:** Docker Swarm (running in `dind` container under Podman)
- **Config management:** Ansible (venv at `/home/deck/.venv/ansible`, core 2.16)
- **Shell:** zsh
- **Editor:** Neovim
- **All repos:** `~/github/<repo-name>`

## SteamOS Constraints (hard rules)

These apply to anything that runs on the Steam Deck itself:

- **Detect SteamOS with `ansible_distribution_release == 'holo'`** — never
  `ansible_distribution == 'SteamOS'`. On-device, `/etc/arch-release` makes Ansible
  report `Archlinux`, so the distribution check is always wrong.
- **Never run `steamos-readonly disable`** or otherwise touch the read-only protection,
  even temporarily. Install everything under `$HOME` with no `become`. If there is no
  way around root, leave the package unsupported on SteamOS.
- **Never `exec` a shell from `.bashrc`** (e.g. `exec zsh`). The display manager sources
  bash startup files during login; replacing the shell mid-session can lock you out. Set
  the terminal emulator's profile command instead (e.g. Konsole `Command=~/.local/bin/zsh`).
- Local testing uses Podman, not Docker — go through the wrappers below.

## Key Wrappers

| Command  | What it does                                               |
| -------- | ---------------------------------------------------------- |
| `mtest`  | Molecule wrapper with correct DOCKER_HOST and PATH         |
| `dswarm` | Docker CLI against the dind Swarm (`tcp://127.0.0.1:2375`) |

Use `mtest` (not raw `molecule`) for local Ansible role tests, and `dswarm` for Swarm
stacks. Build/test images as `local/<name>:test` and deploy with `--resolve-image never`
so stale Docker Hub tags don't shadow local builds. `mtest`/`dswarm`/venv PATHs are
local-only — keep them out of committed repo docs.

## Podman Socket

```bash
systemctl --user enable --now podman.socket
# Socket path:
DOCKER_HOST=unix:///run/user/1000/podman/podman.sock
```

## dind Swarm Container

Podman can't do Swarm mode, so a real Swarm runs inside a `docker:dind` container named
`dind` (fuse-overlayfs, `DOCKER_IGNORE_BR_NETFILTER_ERROR=1`, `daemon.json` at
`~/.config/dind/daemon.json`, stack ports published on localhost). `dswarm` is a wrapper
at `~/.local/bin/dswarm` → a static docker CLI at `~/.local/bin/docker-cli` pointed at
`DOCKER_HOST=tcp://127.0.0.1:2375`.

```bash
podman start dind                  # after reboot
dswarm service ls                  # swarm is pre-initialized; overlay nets: monitor, elk
dswarm stack deploy --resolve-image never -c docker-compose.yml monitor
```

- Always deploy with `--resolve-image never` and build/test images as `local/<name>:test` —
  stale 2018 `jahrik/*` Docker Hub tags otherwise shadow local builds.
- Ingress (published ports) needs `br_netfilter` on the host: `sudo modprobe br_netfilter`
  (not loaded by default on SteamOS). Without it, test via `dswarm exec <container> wget ...` —
  overlay-internal traffic works fine.
- Overlay networks pre-created: `monitor`, `elk`.
- Monitor stack harness: `~/.config/dind/monitor/monitor-stack.yml`.

## Ansible Galaxy

Each ansible role has its own `GALAXY_API_KEY` GitHub secret (not org-wide). The token
lives at `galaxy.ansible.com/ui/token/` (log in → Load Token). Venv: `/home/deck/.venv/ansible`
(`ansible-core` pinned to `2.16.*` for `molecule-docker` compatibility — 2.17+ breaks its
boolean conditionals).

Update the key across all role repos at once:

```bash
NEW_KEY="your_token_here"
for repo in ansible-alacritty ansible-arch-workstation ansible-conky ansible-hyprland \
            ansible-nvim ansible-vim ansible-zsh ansilbe-yay; do
  gh secret set GALAXY_API_KEY --repo jahrik/$repo --body "$NEW_KEY"
  echo "Updated $repo"
done
```

If galaxy role install fails with "doesn't appear to contain a role":

```bash
rm -rf ~/.ansible/roles/jahrik.*
ansible-galaxy install -r requirements.yml
```

## Repo Categories

| Pattern     | Type                                     |
| ----------- | ---------------------------------------- |
| `ansible-*` | Ansible roles                            |
| `docker-*`  | Docker images / compose stacks           |
| `arm-*`     | ARM architecture Docker images           |
| `home_lab`  | Main Ansible + Swarm deployment pipeline |
