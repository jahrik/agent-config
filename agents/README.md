# Agent Catalog

Subagent definitions (Claude Code personas) tuned to this homelab workflow. Each is a
single markdown file with `name` / `description` frontmatter and a system-prompt body —
the native [Claude Code subagent](https://docs.claude.com/en/docs/claude-code/sub-agents)
format. The [`ansible-ai-agents`](https://github.com/jahrik/ansible-ai-agents) role
symlinks this directory into `~/.claude/agents/`, where Claude Code auto-discovers them.

They follow a simplified-enterprise SDLC: **plan → implement → review → test → secure →
release**, plus a domain expert and a docs role.

| Agent       | Stage     | Purpose                                                       |
| ----------- | --------- | ------------------------------------------------------------- |
| `architect` | Plan      | Break work into the smallest correct change; pick the pattern |
| `devlead`   | Implement | Write code matching conventions; branch + PR                  |
| `infraeng`  | Implement | Domain expert: Ansible / Docker / ARM / Swarm / Steam Deck    |
| `devrev`    | Review    | Correctness, simplification, efficiency (read-only)           |
| `qa`        | Test      | Molecule, idempotency, lint, dogfooding (read-only)           |
| `secrev`    | Secure    | Secrets, supply-chain, SteamOS read-only protection           |
| `releng`    | Release   | Semver, changelog, CI/CD, Galaxy + Docker Hub publish         |
| `infoarch`  | Docs      | README / AGENTS.md, concise and command-first                 |

## Portability

These are a Claude Code feature — other tools do not read `~/.claude/agents/`. The
_content_ (scope / mindset / guardrails) is portable, and the shared rules also live in
the top-level `AGENTS.md`, which Copilot and others read via their own symlinks. To use a
role with a different tool, reference the same guidance through that tool's instruction
file.

## Conventions

- `name` matches the filename slug.
- `description` says _when_ to use the agent (used for routing).
- Reviewer-type agents (`devrev`, `qa`, `secrev`) are scoped to read-only tools.
