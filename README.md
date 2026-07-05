# agent-config

[![Lint](https://github.com/jahrik/agent-config/actions/workflows/lint.yml/badge.svg)](https://github.com/jahrik/agent-config/actions/workflows/lint.yml)

A portable AI agent configuration base — rules, skills, and SDLC subagents — plug-and-play with [ansible-ai-agents](https://github.com/jahrik/ansible-ai-agents).

## Structure

```
agent-config/
├── AGENTS.md                  # Global rules loaded by all agents (Claude Code, AGY/Antigravity)
├── agents/                    # 5 SDLC subagent personas → ~/.claude/agents/
├── hooks/
│   └── guard-bash.sh          # PreToolUse guard: blocks gh CLI + pushes to main (self-test: --test)
├── skills/                    # Modular skill packs, loaded on demand by description
│   ├── agent-config-authoring/ # How to author subagents and global rules
│   ├── skill-creator/         # How to author a skill
│   ├── github-workflow/       # Branch → commit → PR → review → merge flow
│   ├── load-sdlc-agents/      # Load SDLC personas into Antigravity
│   ├── systematic-debugging/  # Disciplined root-cause debugging
│   ├── ansible/               # Ansible role conventions and patterns
│   ├── docker/                # Docker image and Swarm conventions
│   ├── go/                    # Go project conventions
│   ├── python/                # Python project conventions
│   └── update-repo/           # Maintain/modernize repos by type (references/ per type)
├── scripts/
│   └── lint-config.py         # Consistency checks (name↔dir, catalogs, size budget, links)
├── SECURITY.md                # What may/may not be committed here
└── .pre-commit-config.yaml    # Secret scanning + formatting + config lint on every commit
```

## What's inside

**Agents** (`agents/`) — a simplified SDLC team, deployed to `~/.claude/agents/` (and loadable into AGY/Antigravity via the `load-sdlc-agents` skill):
`architect` (plan) · `devlead` (implement + infra) · `reviewer` (correctness + security,
read-only) · `qa` (test) · `releng` (release + docs). Each is a portable persona with no
project-specific tooling baked in.

**Skills** (`skills/`) — loaded on demand when their `description` matches:

- **Reference:** `ansible`, `docker`, `go`, `python` — conventions per repo type
- **Practice:** `github-workflow`, `load-sdlc-agents`, `systematic-debugging` — how to work
- **Authoring:** `agent-config-authoring`, `skill-creator` — extend this config
- **Workflow:** `update-repo` — repo maintenance for `ansible-*`, `docker-*`, `arm-*`, Go, and
  Python repos (per-type checklists in `references/`)

**Rules** (`AGENTS.md`) — always-loaded global rules and conventions (including Tool Preferences). It's a **portable base**:
machine- and account-specific detail belongs in each repo's own `AGENTS.md`, not here.

## Using with ansible-ai-agents

The [ansible-ai-agents](https://github.com/jahrik/ansible-ai-agents) role clones this repo
and symlinks it into the locations each agent tool expects. Override the repo in your playbook:

```yaml
- hosts: all
  roles:
    - role: ansible-ai-agents
      vars:
        ai_agents_config_repo: "https://github.com/YOUR_USERNAME/agent-config"
```

## Using standalone (without Ansible)

```bash
git clone https://github.com/jahrik/agent-config ~/.config/agents
# Claude Code
ln -s ~/.config/agents/AGENTS.md ~/.claude/CLAUDE.md
ln -s ~/.config/agents/skills    ~/.claude/skills
ln -s ~/.config/agents/agents    ~/.claude/agents
# AGY/Antigravity
ln -s ~/.config/agents/AGENTS.md ~/.gemini/config/AGENTS.md
ln -s ~/.config/agents/skills    ~/.gemini/config/skills
```

## Security

- **Never commit secrets, tokens, API keys, or internal IPs** to this repo.
- Use a secrets manager or environment variables for sensitive values.
- Pre-commit hooks (gitleaks + detect-secrets) enforce this on every commit.
- GitHub secret scanning is enabled on this public repo.

See [SECURITY.md](SECURITY.md) for the full policy.

## License

MIT
