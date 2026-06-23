# Agent Catalog

Subagent definitions (Claude Code personas) for a simplified-enterprise SDLC. Each is a
single markdown file with `name` / `description` / `tools` / `model` frontmatter and a
system-prompt body — the native
[Claude Code subagent](https://docs.claude.com/en/docs/claude-code/sub-agents) format. The
[`ansible-ai-agents`](https://github.com/jahrik/ansible-ai-agents) role symlinks this
directory into `~/.claude/agents/`, where Claude Code auto-discovers them.

The bodies are a **portable base** — persona, mindset, guardrails, and the escalation graph
with no project-specific tools, registries, or OS baked in. Environment specifics live in
`AGENTS.md` and the skills, so the same agents work in any project that forks this config.

They follow a simplified-enterprise SDLC: **plan → implement → review → test → secure →
release**, plus a domain expert and a docs role.

| Agent       | Stage     | Model  | Purpose                                                       |
| ----------- | --------- | ------ | ------------------------------------------------------------- |
| `architect` | Plan      | opus   | Break work into the smallest correct change; pick the pattern |
| `devlead`   | Implement | sonnet | Write code matching conventions; branch + PR                  |
| `infraeng`  | Implement | sonnet | Domain expert: infrastructure-as-code, images, deployment     |
| `devrev`    | Review    | sonnet | Correctness, simplification, efficiency (read-only)           |
| `qa`        | Test      | sonnet | Test suites, idempotency, lint, dogfooding (read-only)        |
| `secrev`    | Secure    | opus   | Secrets, supply-chain, platform-security protection           |
| `releng`    | Release   | sonnet | Semver, changelog, CI/CD, publishing                          |
| `infoarch`  | Docs      | sonnet | README / AGENTS.md, concise and command-first                 |

## Portability

Subagents are a Claude Code feature — other tools do not read `~/.claude/agents/`. The
_content_ (scope / mindset / guardrails) is portable, and the shared rules also live in
the top-level `AGENTS.md`, which other AGENTS.md-aware tools read via their own symlinks.
To use a role with a different tool, reference the same guidance through that tool's
instruction file.

## Conventions

- `name` matches the filename slug.
- `description` says _when_ to use the agent (used for routing).
- Reviewer-type agents (`devrev`, `qa`, `secrev`) are scoped to read-only tools.
