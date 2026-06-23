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
- Ansible roles: `ansible-<name>`, tested with Molecule (Docker driver); published to Ansible Galaxy
- Docker images: `docker-<name>`, multi-arch (`amd64`/`arm64`) via buildx; published to GHCR (`ghcr.io/jahrik/<name>`) — `docker-archlinux-ansible` stays on Docker Hub
- ARM images: `arm-<name>`, multi-arch down to Raspberry Pi 3 (`arm/v7`); published to Docker Hub (`jahrik/<name>`)
- CI: GitHub Actions (not Jenkins/Jenkinsfile — those are legacy)
- Use `AGENTS.md` not `CLAUDE.md` for project-level guidance files

---

## Skills

Additional context is available in modular skill files. These are loaded on demand:

Reference skills (conventions and context):

- `skills/ansible/` — Ansible role conventions and patterns
- `skills/docker/` — Docker/Swarm conventions
- `skills/steamdeck/` — Steam Deck / SteamOS environment, wrappers, and on-device rules
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
