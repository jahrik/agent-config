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
uvx pre-commit install            # install the git hook
uvx pre-commit run --all-files    # scan everything now
```

### 2. GitHub Secret Scanning (remote)

GitHub automatically scans all pushes to this public repo for known secret patterns
(API keys, tokens, credentials) and alerts the repo owner immediately.

## Environment-specific values

This repo is a **portable base** of plain-markdown rules and skills. The `ansible-ai-agents`
role _symlinks_ these files into place — it does not template values into them. So keep
environment-specific detail (hostnames, usernames, service URLs, local paths) **out of the
committed skills and the global `AGENTS.md`**.

That detail belongs in each repository's own `AGENTS.md` (or a private file outside this shared
config), where it's read in context rather than baked into the shared base.

## Reporting

If you find sensitive data accidentally committed, open an issue immediately
and rotate any exposed credentials before anything else.
