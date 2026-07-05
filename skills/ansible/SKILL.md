---
name: ansible
description: Ansible role conventions for this ecosystem — multi-OS role anatomy, the install/uninstall + per-OS dispatch pattern, Molecule scenarios, meta/CI/lint shapes, and production-profile rules. Use when writing or updating an Ansible role.
---

# Ansible Skill

Conventions for the `ansible-<name>` role repos: each is a **single-purpose role** installing one
thing across Arch, Debian/Ubuntu, macOS (optionally SteamOS), tested with Molecule, published to
Galaxy. Local test-harness specifics live in the project's `AGENTS.md`.

## Role anatomy

```
defaults/main.yml      # install: true toggle + user-facing vars
tasks/main.yml         # dispatch install vs uninstall
tasks/install.yml      # OS dispatch + shared config; uninstall.yml mirrors it
tasks/{archlinux,debian,darwin,steamos}.yml
handlers/ meta/ templates/ files/
molecule/{default,localhost,steamdeck}/
.github/workflows/cicd.yml
pyproject.toml, uv.lock, requirements.yml, .ansible-lint, .yamllint
```

## Core rules

- `tasks/main.yml` dispatches on `install | default(true) | bool`; `install.yml` includes one
  guarded per-OS file, falls back to generic `package:`, then shared `~/.config` templating.
- **`become: true` only for system package installs**; never for `~/` work or macOS/SteamOS.
- The `holo` guard (`ansible_distribution_release != 'holo'`) keeps Arch/generic paths off
  SteamOS's read-only rootfs.
- Facts via `ansible_facts['<fact>']`; `ansible.cfg` sets `inject_facts_as_vars = False`.
- Never a meta dependency that runs platform-specific tasks (meta deps run unconditionally) — use
  distro-guarded `include_role`.
- `verify.yml` makes real assertions — never `assert: that: true`.
- Lint: `.ansible-lint` `profile: production`; FQCN everywhere; `changed_when:` on every
  command/shell; pinned `version:` on every git task.
- YAML style: 2-space indent; quote any string that could be misread (`"true"`, versions, modes).

Run molecule via `scripts/mtest.sh` — it wires podman up as the Docker backend when needed,
clears the stale role cache, and prefers the repo's pinned toolchain (`uv run`).

Full YAML shapes (task flow, meta, molecule scenarios, verify, CI jobs, lint configs, gotchas):
`references/role-patterns.md`. Repo-by-repo modernization procedure + current pins: the
`update-repo` skill.
