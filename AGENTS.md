# AGENTS.md — Global AI Agent Configuration

The global source of truth for rules, conventions, and context. Loaded automatically by
AGENTS.md-aware agents — Claude Code (as `~/.claude/CLAUDE.md`) and AGY/Antigravity
(as `~/.gemini/config/AGENTS.md`), wired up by the `ansible-ai-agents` role.

---

## Owner Context

- **GitHub:** jahrik
- **Primary OS:** Arch Linux (SteamOS on Steam Deck)
- **Shell:** zsh
- **Editor:** Neovim
- **Container runtime:** Podman (with Docker shim)
- **Homelab:** Docker Swarm (via `dswarm` wrapper), Ansible-managed

---

## Hard Rules — Always Follow

1. **Never write secrets, API keys, tokens, passwords, or credentials into any file.**
   Use Ansible Vault variables or environment variables instead.
2. **Never hardcode IP addresses or internal hostnames.**
   Use variables (`{{ variable_name }}`) that Ansible fills in at deploy time.
3. **Use `AGENTS.md` instead of `CLAUDE.md`** for all project-level guidance files.
4. **Run idempotent commands.** Prefer tools and patterns that can safely re-run.
5. **Ask before destructive operations** (delete, overwrite, drop, purge, reset).
6. **Never commit or push to `main`.** Always branch, open a PR, and let the maintainer
   merge — never `git push` to main and never auto-merge a PR.
7. **Attribute commits** with a `Co-Authored-By:` trailer for the AI model used.
8. **On SteamOS (Steam Deck):** detect with `ansible_distribution_release == 'holo'` (not
   `== 'SteamOS'`); never run `steamos-readonly disable` or touch read-only protection
   (install under `$HOME`, no `become`); never `exec` a shell from `.bashrc`.

---

## Local Environment & Tooling

The maintainer's workstation. **A fork should replace this whole section** — the skills and
agents stay portable; this is the only place machine-specific detail belongs.

- **OS:** Arch Linux / SteamOS (Steam Deck). Detect SteamOS via `ansible_distribution_release == 'holo'`.
- **Python:** `uv` for deps and virtualenvs (`uv run`, `uv sync`); per-project `.venv/`.
- **Packages:** `yay` (AUR helper) on Arch; Node via `npm` global installs under `~/.local/`.
- **Containers:** Podman with a Docker shim at `~/.local/bin/docker` (no Docker daemon).
  Socket: `DOCKER_HOST=unix:///run/user/1000/podman/podman.sock`.
- **Wrappers:** `mtest` (Molecule with the right `DOCKER_HOST`/PATH) and `dswarm` (docker CLI
  against the dind Swarm). Local-only — keep them out of committed repo docs; READMEs use plain
  `molecule` / `docker`.

### Local Molecule testing

`ansible-core` is pinned to `2.16.*` (venv `~/.venv/ansible`) for `molecule-docker`
compatibility — 2.17+ breaks its boolean conditionals. Run `mtest test` (`converge` /
`verify` / `destroy` also work). If galaxy role install fails with "doesn't appear to contain
a role": `rm -rf ~/.ansible/roles/jahrik.*` and reinstall.

### Local Docker Swarm (dind)

Podman can't do Swarm, so a real Swarm runs in a `docker:dind` container named `dind`
(fuse-overlayfs, `DOCKER_IGNORE_BR_NETFILTER_ERROR=1`, daemon.json at `~/.config/dind/daemon.json`).
`dswarm` → a static docker CLI at `tcp://127.0.0.1:2375`. Build/test images as `local/<name>:test`
and deploy with `--resolve-image never` so stale Hub tags don't shadow local builds. Ingress
needs `sudo modprobe br_netfilter`; without it, test via `dswarm exec <c> wget ...`. Overlay nets
pre-created: `monitor`, `elk`. Run `podman start dind` after reboot.

### Ansible Galaxy key

Each role has its own `GALAXY_API_KEY` secret (token at `galaxy.ansible.com/ui/token/`).
Bulk-update across roles:

```bash
NEW_KEY="your_token_here"
for repo in ansible-alacritty ansible-arch-workstation ansible-conky ansible-hyprland \
            ansible-nvim ansible-vim ansible-zsh ansilbe-yay; do
  gh secret set GALAXY_API_KEY --repo jahrik/$repo --body "$NEW_KEY"
done
```

---

## Code Style Preferences

- **Python:** `ruff format` (Black-compatible) + `ruff` linting, type hints preferred
- **YAML:** 2-space indent, quoted strings for anything that could be misread
- **Shell:** `#!/usr/bin/env bash`, `set -euo pipefail`
- **Markdown:** ATX headings (`#`), fenced code blocks with language tags
- **Ansible:** Use FQCN (`ansible.builtin.copy` not `copy`), `become: true` only when needed

---

## Repository Conventions

- All repos live in `~/github/`
- Ansible roles: `ansible-<name>`, tested with Molecule (Docker driver); published to Ansible Galaxy
- Docker images: `docker-<name>`, multi-arch (`amd64`/`arm64`) via buildx; published to GHCR (`ghcr.io/jahrik/<name>`) — `docker-archlinux-ansible` stays on Docker Hub
- ARM images: `arm-<name>`, multi-arch down to Raspberry Pi 3 (`arm/v7`); published to Docker Hub (`jahrik/<name>`)
- CI: GitHub Actions (not Jenkins/Jenkinsfile — those are legacy)
- Use `AGENTS.md` not `CLAUDE.md` for project-level guidance files

---

## Skills

Additional context is available in modular skill files. These are loaded on demand:

Reference skills (portable conventions, no machine specifics):

- `skills/ansible/` — Ansible role conventions and patterns
- `skills/docker/` — Docker image and Swarm conventions
- `skills/python/` — Python project conventions

Workflow skills (repo maintenance actions):

- `skills/agent-config-authoring/` — how to author skills, subagents, and rules in this repo
- `skills/sync-repos/` — sync all GitHub repos
- `skills/update-ansible-role/` — update pattern for `ansible-*` repos
- `skills/update-arm-repo/` — revive `arm-*` multi-arch image builds
- `skills/update-docker-repo/` — modernize `docker-*` image repos
- `skills/update-python-repo/` — modernize Python project repos

---

## Agents (Roles)

Subagent personas live in `agents/` and are deployed to `~/.claude/agents/` by the
`ansible-ai-agents` role. They follow a simplified SDLC: plan → implement → review →
test → secure → release. Environment-specific detail lives in the Local Environment section
above, not in the agent definitions or the portable skills.

| Agent       | Use for                                    |
| ----------- | ------------------------------------------ |
| `architect` | Planning and design before implementation  |
| `devlead`   | Implementing features and fixes            |
| `infraeng`  | Ansible / Docker / ARM / Swarm domain work |
| `devrev`    | Code review (correctness, simplification)  |
| `qa`        | Testing, idempotency, dogfooding           |
| `secrev`    | Security review                            |
| `releng`    | Versioning, CI/CD, publishing              |
| `infoarch`  | Documentation                              |

Agents are a Claude Code feature; see `agents/README.md` for portability notes.

---

## What NOT to put in this file

- Secrets, tokens, API keys
- Internal IPs or hostnames (use `{{ variables }}`)
- Keep the portable sections lean; machine-specific detail belongs only in the Local
  Environment section, and never leaks into the skills or committed per-repo docs
