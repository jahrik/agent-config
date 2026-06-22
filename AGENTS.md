# AGENTS.md — Global AI Agent Configuration

This file is loaded automatically by AI coding agents (AGY/Antigravity, Claude Code,
GitHub Copilot, Cursor, Windsurf, etc.) as the global source of truth for rules,
conventions, and context.

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

---

## Tooling & Environment

### Ansible / Molecule
- Use `mtest` wrapper (`~/.local/bin/mtest`) for molecule commands.
- Required environment:
  ```bash
  DOCKER_HOST=unix:///run/user/1000/podman/podman.sock
  PATH="$HOME/.local/bin:$HOME/.venv/ansible/bin:$PATH"
  ```
- Venv: `/home/deck/.venv/ansible` (ansible-core 2.16)
- Docker shim: `~/.local/bin/docker` → `podman`

### Docker Swarm (dswarm)
- Use `dswarm` wrapper (`~/.local/bin/dswarm`)
- Always deploy with `--resolve-image never`
- Build/test images as `local/<name>:test`
- Check/load `br_netfilter` if ingress ports don't respond:
  ```bash
  sudo modprobe br_netfilter
  ```

### Package Management
- Primary: `yay` (AUR helper) on Arch
- Python: Use `uv` for dependency and virtualenv management (`uv run`, `uv sync`); local venvs at `.venv/` in each project
- Node: `npm` global installs via `~/.local/`

---

## Code Style Preferences

- **Python:** Black formatting, ruff linting, type hints preferred
- **YAML:** 2-space indent, quoted strings for anything that could be misread
- **Shell:** `#!/usr/bin/env bash`, `set -euo pipefail`
- **Markdown:** ATX headings (`#`), fenced code blocks with language tags
- **Ansible:** Use FQCN (`ansible.builtin.copy` not `copy`), `become: true` only when needed

---

## Repository Conventions

- All repos live in `~/github/`
- Ansible roles: `ansible-<name>` pattern, tested with Molecule + Docker driver
- Docker images: `docker-<name>` pattern, built for `amd64` and `arm64v8`
- ARM images: `arm-<name>` pattern
- CI: GitHub Actions (not Jenkins/Jenkinsfile — those are legacy)
- Use `AGENTS.md` not `CLAUDE.md` for agent guidance files

---

## Skills

Additional context is available in modular skill files. These are loaded on demand:

- `skills/ansible/` — Ansible role conventions and patterns
- `skills/docker/` — Docker/Swarm conventions
- `skills/homelab/` — Homelab infrastructure context
- `skills/python/` — Python project conventions

---

## What NOT to put in this file

- Secrets, tokens, API keys
- Internal IPs or hostnames (use `{{ variables }}`)
- Anything longer than needed — keep it lean so agents don't ignore it
