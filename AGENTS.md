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

- **Python:** `uv` for dependencies and virtualenvs (`uv run`, `uv sync`); per-project `.venv/`.
- **Packages:** `yay` (AUR helper) on Arch; Node via `npm` global installs under `~/.local/`.
- **Ansible/Molecule, Docker Swarm (dswarm), Podman, the local test harness, and all SteamOS specifics:** see the `steamdeck` skill.

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
- Ansible roles: `ansible-<name>` pattern, tested with Molecule + Docker driver
- Docker images: `docker-<name>` pattern, built for `amd64` and `arm64v8`
- ARM images: `arm-<name>` pattern
- CI: GitHub Actions (not Jenkins/Jenkinsfile — those are legacy)
- Use `AGENTS.md` not `CLAUDE.md` for agent guidance files

---

## Skills

Additional context is available in modular skill files. These are loaded on demand:

Reference skills (conventions and context):

- `skills/ansible/` — Ansible role conventions and patterns
- `skills/docker/` — Docker/Swarm conventions
- `skills/steamdeck/` — Steam Deck / SteamOS environment, wrappers, and on-device rules
- `skills/python/` — Python project conventions

Workflow skills (repo maintenance actions):

- `skills/sync-repos/` — sync all GitHub repos
- `skills/update-ansible-role/` — update pattern for `ansible-*` repos
- `skills/update-arm-repo/` — revive `arm-*` multi-arch image builds
- `skills/update-docker-repo/` — modernize `docker-*` image repos
- `skills/update-python-repo/` — modernize Python project repos

---

## Agents (Roles)

Subagent personas live in `agents/` and are deployed to `~/.claude/agents/` by the
`ansible-ai-agents` role. They follow a simplified SDLC: plan → implement → review →
test → secure → release. Environment-specific detail lives in the skills above (notably
`steamdeck`), not in the agent definitions.

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
- Anything longer than needed — keep it lean so agents don't ignore it
