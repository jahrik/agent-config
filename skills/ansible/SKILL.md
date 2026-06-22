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

All roles use `gofrolist/molecule-action@v2` in `.github/workflows/molecule.yml`.

## Galaxy Publishing

Each role has its own `GALAXY_API_KEY` secret. Publish on release tag via GHA.
