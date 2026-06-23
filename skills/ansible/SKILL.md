---
name: ansible-skill
description: Ansible role conventions — structure, FQCN, Molecule testing, and CI patterns
---

# Ansible Skill

Portable conventions for Ansible role repos. The local test harness and any publishing
secrets live in `AGENTS.md`, not here.

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

- Each role ships a `molecule/default/` scenario (Docker driver).
- Run `molecule test` (converge → verify → destroy). `verify.yml` must make real assertions,
  not `assert that=true`.
- Tests must be idempotent — a second converge reports no changes.

## CI Pattern (GitHub Actions)

`.github/workflows/cicd.yml` with `lint` → `molecule` → `release` jobs. Run lint and tests
via `uv` (`astral-sh/setup-uv`, then `uv sync` and `uv run molecule test`). The `release` job
publishes to Galaxy on pushes to `main`, gated on `lint` + `molecule` passing. See the
`update-ansible-role` skill for the full template.
