# agent-config

[![Lint](https://github.com/jahrik/agent-config/actions/workflows/lint.yml/badge.svg)](https://github.com/jahrik/agent-config/actions/workflows/lint.yml)

A portable AI agent configuration base — rules, skills, and SDLC subagents — plug-and-play with [ansible-ai-agents](https://github.com/jahrik/ansible-ai-agents).

## Structure

```
agent-config/
├── AGENTS.md                  # Global rules loaded by all agents (Claude Code, AGY/Antigravity)
├── agents/                    # 8 SDLC subagent personas → ~/.claude/agents/
├── skills/                    # Modular skill packs, loaded on demand by description
│   ├── agent-config-authoring/ # How to author subagents and global rules
│   ├── skill-creator/         # How to author a skill
│   ├── github-workflow/       # Branch → commit → PR → review → merge flow
│   ├── systematic-debugging/  # Disciplined root-cause debugging
│   ├── ansible/               # Ansible role conventions and patterns
│   ├── docker/                # Docker image and Swarm conventions
│   ├── python/                # Python project conventions
│   ├── sync-repos/            # Sync all GitHub repos
│   ├── update-ansible-role/   # Update pattern for ansible-* repos
│   ├── update-arm-repo/       # Revive arm-* multi-arch image builds
│   ├── update-docker-repo/    # Modernize docker-* image repos
│   └── update-python-repo/    # Modernize Python project repos
├── SECURITY.md                # What may/may not be committed here
└── .pre-commit-config.yaml    # Secret scanning + formatting on every commit
```

## What's inside

**Agents** (`agents/`) — a simplified SDLC team, deployed to `~/.claude/agents/`:
`architect` (plan) · `devlead` / `infraeng` (implement) · `devrev` / `qa` / `secrev`
(review / test / secure) · `releng` (release) · `infoarch` (docs). Each is a portable persona
with no project-specific tooling baked in.

**Skills** (`skills/`) — loaded on demand when their `description` matches:

- **Reference:** `ansible`, `docker`, `python` — conventions per repo type
- **Practice:** `github-workflow`, `systematic-debugging` — how to work
- **Authoring:** `agent-config-authoring`, `skill-creator` — extend this config
- **Workflow:** `sync-repos`, `update-ansible-role`, `update-arm-repo`, `update-docker-repo`, `update-python-repo` — repo maintenance

**Rules** (`AGENTS.md`) — always-loaded global rules and conventions. It's a **portable base**:
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
