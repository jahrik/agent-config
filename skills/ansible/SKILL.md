---
name: ansible-skill
description: Ansible role conventions, molecule testing, and patterns for this homelab
---

# Ansible Skill

## Role Structure

Standard layout for all `ansible-*` repos:

```
defaults/main.yml     # role variables — always provide sensible defaults
tasks/main.yml        # entry point, use include_tasks for sub-files
handlers/main.yml     # service restart handlers
meta/main.yml         # Galaxy metadata
molecule/default/     # molecule test scenario
playbook.yml          # example playbook
requirements.yml      # Galaxy dependencies
ansible.cfg
inventory.ini
AGENTS.md
README.md
```

## Conventions

- Use **FQCN** for all modules: `ansible.builtin.copy`, not `copy`
- Use `become: true` only at the task level when needed, not globally
- Quote YAML strings that could be misread (ports, versions, booleans as strings)
- Use `ansible.builtin.template` for files with variables, `ansible.builtin.copy` for static files
- Register results and check `changed_when` / `failed_when` for commands

## Testing with Molecule

Run locally with the `mtest` wrapper:

```bash
mtest converge    # apply the role
mtest verify      # run assertions
mtest destroy     # tear down containers
mtest test        # full cycle
```

Environment required:

```bash
DOCKER_HOST=unix:///run/user/1000/podman/podman.sock
PATH="$HOME/.local/bin:$HOME/.venv/ansible/bin:$PATH"
```

## CI Pattern (GitHub Actions)

All roles use `.github/workflows/cicd.yml` with `lint` → `molecule` → `release` jobs.
Lint and test run via `uv` (`astral-sh/setup-uv`, then `uv sync` and `uv run molecule test`) —
not the legacy `gofrolist/molecule-action`. See the `update-ansible-role` skill for the full
template.

## Galaxy Publishing

Each role has its own `GALAXY_API_KEY` secret. The `release` job publishes to Galaxy via
`robertdebock/galaxy-action` on pushes to `main` (gated on `lint` + `molecule` passing).
