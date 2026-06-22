# agent-config

[![Lint](https://github.com/jahrik/agent-config/actions/workflows/lint.yml/badge.svg)](https://github.com/jahrik/agent-config/actions/workflows/lint.yml)

Personal AI agent configuration — plug-and-play with [ansible-ai-agents](https://github.com/jahrik/ansible-ai-agents).

## Structure

```
agent-config/
├── AGENTS.md                  # Global rules loaded by all agents (Claude Code, AGY/Antigravity)
├── agents/                    # Subagent personas → ~/.claude/agents/ (plan, review, qa, secrev, ...)
├── skills/                    # Modular skill packs (auto-discovered by AGY/Antigravity)
│   ├── agent-config-authoring/ # How to author skills, subagents, and rules here
│   ├── ansible/               # Ansible role conventions and patterns
│   ├── docker/                # Docker/Swarm conventions
│   ├── steamdeck/             # Steam Deck / SteamOS environment and on-device rules
│   ├── python/                # Python project conventions
│   ├── sync-repos/            # Sync all GitHub repos
│   ├── update-ansible-role/   # Update pattern for ansible-* repos
│   ├── update-arm-repo/       # Revive arm-* multi-arch image builds
│   ├── update-docker-repo/    # Modernize docker-* image repos
│   └── update-python-repo/    # Modernize Python project repos
├── SECURITY.md                # What may/may not be committed here
└── .pre-commit-config.yaml    # Secret scanning + formatting on every commit
```

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
ln -s ~/.config/agents/AGENTS.md ~/.agents/AGENTS.md
ln -s ~/.config/agents/skills ~/.agents/skills
```

## Security

- **Never commit secrets, tokens, API keys, or internal IPs** to this repo.
- Use Ansible Vault or environment variables for sensitive values.
- Pre-commit hooks (gitleaks + detect-secrets) enforce this on every commit.
- GitHub secret scanning is enabled on this public repo.

See [SECURITY.md](SECURITY.md) for the full policy.

## License

MIT
