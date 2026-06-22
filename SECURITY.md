# Security Policy

## What belongs in this repo

✅ **Safe to commit:**

- Markdown rules and instructions (AGENTS.md, skills)
- Template placeholders like `{{ variable_name }}`
- Tool preferences, coding standards, workflow descriptions
- Public usernames and GitHub handles

❌ **Never commit:**

- API keys, tokens, or credentials of any kind
- Internal IP addresses or hostnames
- SSH keys or certificates
- Personal access tokens (GitHub, Anthropic, Google, etc.)
- Passwords or secrets of any form
- Internal service URLs or private network topology

## Enforcement

This repo uses two layers of automated secret detection:

### 1. Pre-commit hooks (local)

[gitleaks](https://github.com/gitleaks/gitleaks) and [detect-secrets](https://github.com/Yelp/detect-secrets)
scan every commit before it lands. Install with:

```bash
pip install pre-commit
pre-commit install
```

### 2. GitHub Secret Scanning (remote)

GitHub automatically scans all pushes to this public repo for known secret patterns
(API keys, tokens, credentials) and alerts the repo owner immediately.

## Sensitive values in agent config

If your skills or rules need to reference environment-specific values
(hostnames, usernames, service URLs), use Ansible variables instead:

```markdown
# In a skill file — use placeholders, not real values

The homelab is managed at `{{ ai_agents_homelab_host }}`.
```

The `ansible-ai-agents` role fills these in from your inventory/vault at deploy time.

## Reporting

If you find sensitive data accidentally committed, open an issue immediately
and rotate any exposed credentials before anything else.
