# AGENTS.md — Global AI Agent Configuration

The portable source of truth for rules, conventions, and context shared across projects. Loaded
automatically by AGENTS.md-aware agents — Claude Code (as `~/.claude/CLAUDE.md`) and AGY/Antigravity
(as `~/.gemini/config/AGENTS.md`), wired up by the `ansible-ai-agents` role.

This is a **portable base**. Keep it free of machine- and account-specific detail: per-repo
specifics live in each repository's own `AGENTS.md` and `README.md` (read those first), and
environment details (account, OS, shell, local tooling) are inferred from the session and the repos
as needed.

---

## Hard Rules — Always Follow

1. **Never write secrets, API keys, tokens, passwords, or credentials into any file.** Use a secrets
   manager or environment variables instead.
2. **Never hardcode IP addresses or internal hostnames.** Use variables that config/templating fills
   in at deploy time.
3. **Never create a `CLAUDE.md` file.** Use `AGENTS.md` for all project-level guidance — including
   when a tool's `/init`-style command asks for `CLAUDE.md`. If `AGENTS.md` already exists, update it
   instead of adding a second guidance file.
4. **Run idempotent commands.** Prefer tools and patterns that can safely re-run.
5. **Ask before destructive operations** (delete, overwrite, drop, purge, reset).
6. **Never commit or push to `main`.** Always branch, open a PR, and let the maintainer merge — never
   `git push` to main and never auto-merge a PR.
7. **Attribute commits** with a `Co-Authored-By:` trailer for the AI model used.
8. **Never use the `gh` CLI.** GitHub operations go through the `mcp-github` MCP tools (`gh_*`); if
   a capability is missing, open an issue on the MCP server's repo and hand the action to the
   maintainer.

---

## Tool Preferences

- **Search / Inspect:** Prefer `rg`, `fd`, `jq`, `yq`, `bat`, `ast-grep`, `xsv`, and `htmlq` over basic POSIX tools when available.
- **Diff:** Use `delta` for readable diffs.
- **GitHub Ops:** Never use the `gh` CLI. All GitHub operations must go through `mcp-github` tools (`gh_*`).
- **Sync:** Use `repo-sync` for cross-repo cloning and status checking.

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
- `skills/go/` — Go project conventions
- `skills/python/` — Python project conventions

Practice skills (how to work):

- `skills/github-workflow/` — branch → commit → PR → review → merge flow
- `skills/load-sdlc-agents/` — load SDLC personas into Antigravity
- `skills/systematic-debugging/` — disciplined root-cause debugging

Authoring skills (extend this config):

- `skills/agent-config-authoring/` — how to author subagents and global rules
- `skills/skill-creator/` — how to author a skill

Workflow skills (repo maintenance actions):

- `skills/update-repo/` — maintain/modernize repos by type (`ansible-*`, `docker-*`, `arm-*`, Go,
  Python); per-type checklists in its `references/`

---

## Agents (Roles)

Subagent personas live in `agents/` and are deployed to `~/.claude/agents/` by the `ansible-ai-agents`
role. They follow a simplified SDLC: plan → implement → review → test → release. Project- and
environment-specific detail lives in each repo's `AGENTS.md`, not in the agent definitions.

| Agent       | Use for                                            |
| ----------- | -------------------------------------------------- |
| `architect` | Planning and design before implementation          |
| `devlead`   | Implementing features, fixes, and infrastructure   |
| `reviewer`  | Code + security review (correctness, supply-chain) |
| `qa`        | Testing, idempotency, dogfooding                   |
| `releng`    | Versioning, CI/CD, publishing, and documentation   |

These personas are natively discovered by Claude Code, but can also be loaded into AGY/Antigravity using the `load-sdlc-agents` skill. See `agents/README.md` for portability notes.

---

## What NOT to put in this file

- Secrets, tokens, API keys
- Internal IPs or hostnames (use variables)
- Machine- or account-specific detail — that belongs in each repo's own `AGENTS.md`, not this shared
  base. Keep it lean.
