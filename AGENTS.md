# AGENTS.md — Global AI Agent Configuration

The portable source of truth for rules, conventions, and context shared across projects. Loaded
automatically by AGENTS.md-aware agents — Claude Code (as `~/.claude/CLAUDE.md`) and AGY/Antigravity
(as `~/.gemini/config/AGENTS.md`), wired up by the `ansible-ai-agents` role.

This is a **portable base**. Keep it free of machine- and account-specific detail: per-repo
specifics live in each repository's own `AGENTS.md` and `README.md` (read those first), and the few
placeholders below are for you to fill in.

---

## Owner Context

Fill in for your setup, or leave as-is — agents infer most of it from the repos:

- **GitHub:** `<your-handle-or-org>`
- **Primary OS / Shell / Editor:** `<os>` / `<shell>` / `<editor>`
- **Local tooling:** note any non-obvious local wrappers or runtimes here (or keep them in a private
  file outside this shared base). Each repo's `AGENTS.md` documents how to test and run that repo.

---

## Hard Rules — Always Follow

1. **Never write secrets, API keys, tokens, passwords, or credentials into any file.** Use a secrets
   manager or environment variables instead.
2. **Never hardcode IP addresses or internal hostnames.** Use variables that config/templating fills
   in at deploy time.
3. **Use `AGENTS.md` instead of `CLAUDE.md`** for all project-level guidance files.
4. **Run idempotent commands.** Prefer tools and patterns that can safely re-run.
5. **Ask before destructive operations** (delete, overwrite, drop, purge, reset).
6. **Never commit or push to `main`.** Always branch, open a PR, and let the maintainer merge — never
   `git push` to main and never auto-merge a PR.
7. **Attribute commits** with a `Co-Authored-By:` trailer for the AI model used.

---

## Code Style Preferences

- **Python:** `ruff format` (Black-compatible) + `ruff` linting, type hints preferred
- **YAML:** 2-space indent, quoted strings for anything that could be misread
- **Shell:** `#!/usr/bin/env bash`, `set -euo pipefail`
- **Markdown:** ATX headings (`#`), fenced code blocks with language tags
- **Ansible:** FQCN (`ansible.builtin.copy` not `copy`), `become: true` only when needed

---

## Repository Conventions

- Repos follow a type prefix the workflow skills key off of:
  - `ansible-<name>` — Ansible roles, tested with Molecule (Docker driver), published to Galaxy
  - `docker-<name>` — Docker images, multi-arch via buildx, published to your registry (GHCR or Docker Hub)
  - `arm-<name>` — multi-arch images down to `arm/v7` (Raspberry Pi), published to your registry
- CI: GitHub Actions
- Each repo carries its own `AGENTS.md` + `README.md` for its specifics — read those first.

---

## Skills

Additional context is available in modular skill files, loaded on demand.

Reference skills (portable conventions):

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

Subagent personas live in `agents/` and are deployed to `~/.claude/agents/` by the `ansible-ai-agents`
role. They follow a simplified SDLC: plan → implement → review → test → secure → release. Project- and
environment-specific detail lives in each repo's `AGENTS.md`, not in the agent definitions.

| Agent       | Use for                                    |
| ----------- | ------------------------------------------ |
| `architect` | Planning and design before implementation  |
| `devlead`   | Implementing features and fixes            |
| `infraeng`  | Infrastructure-as-code, images, deployment |
| `devrev`    | Code review (correctness, simplification)  |
| `qa`        | Testing, idempotency, dogfooding           |
| `secrev`    | Security review                            |
| `releng`    | Versioning, CI/CD, publishing              |
| `infoarch`  | Documentation                              |

Agents are a Claude Code feature; see `agents/README.md` for portability notes.

---

## What NOT to put in this file

- Secrets, tokens, API keys
- Internal IPs or hostnames (use variables)
- Machine- or account-specific detail — that belongs in each repo's own `AGENTS.md`, not this shared
  base. Keep it lean.
