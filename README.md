# agent-config

Personal AI agent configuration — plug-and-play with [ansible-ai-agents](https://github.com/jahrik/ansible-ai-agents).

## Structure

```
agent-config/
├── AGENTS.md          # Global rules loaded by all agents (AGY, Claude Code, Copilot, etc.)
├── skills/            # Modular skill packs (auto-discovered by AGY/Antigravity)
│   ├── ansible/       # Ansible role conventions and patterns
│   ├── docker/        # Docker/Swarm conventions
│   ├── homelab/       # Homelab-specific context
│   └── python/        # Python project conventions
├── rules/             # Additional rule files (referenced from AGENTS.md)
│   ├── global.md
│   ├── ansible.md
│   └── docker.md
└── .pre-commit-config.yaml   # Secret scanning on every commit
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
