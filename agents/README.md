# Agent Catalog

Subagent definitions (Claude Code personas) for a simplified SDLC. Each is a single markdown
file with `name` / `description` / `model` frontmatter (plus `tools` where restricted —
omitting it, as `devlead` does, grants all tools) and a system-prompt body —
the native [Claude Code subagent](https://docs.claude.com/en/docs/claude-code/sub-agents)
format. The [`ansible-ai-agents`](https://github.com/jahrik/ansible-ai-agents) role symlinks
this directory into `~/.claude/agents/`, where Claude Code auto-discovers them.

The bodies are a **portable base** — persona, mindset, guardrails, and the escalation graph
with no project-specific tools, registries, or OS baked in. Environment specifics live in
`AGENTS.md` and the skills, so the same agents work in any project that forks this config.

They follow a simplified SDLC: **plan → implement → review → test → release**.

| Agent       | Stage     | Model  | Purpose                                                           |
| ----------- | --------- | ------ | ----------------------------------------------------------------- |
| `architect` | Plan      | opus   | Break work into smallest correct change; pick the pattern         |
| `devlead`   | Implement | sonnet | Code + infra: matching style, skills, branch + PR                 |
| `reviewer`  | Review    | opus   | Correctness + security review (read-only)                         |
| `qa`        | Test      | sonnet | Test suites, idempotency, lint, dogfooding (read-only)            |
| `releng`    | Release   | sonnet | Semver, CI/CD, publishing, and documentation (README / AGENTS.md) |

## Portability

Subagents are a Claude Code feature — other tools do not natively auto-discover
`~/.claude/agents/`. The _content_ (scope / mindset / guardrails) is highly portable. For
AGY/Antigravity, the `load-sdlc-agents` skill dynamically reads these files and injects them
into the runtime via `define_subagent`. The shared rules also live in the top-level
`AGENTS.md`, which other AGENTS.md-aware tools read via their own symlinks.

## Conventions

- `name` matches the filename slug.
- `description` says _when_ to use the agent (used for routing).
- Read-only agents (`reviewer`, `qa`) drop `Edit`/`Write` — they report findings, not change
  code. They keep `Bash` for inspection, so "read-only" means no file edits, not a sandbox.
