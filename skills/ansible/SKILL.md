---
name: ansible-skill
description: Ansible role conventions for this ecosystem — multi-OS role anatomy, the install/uninstall + per-OS dispatch pattern, Molecule scenarios, meta/CI/lint shapes, and production-profile rules. Use when writing or updating an Ansible role.
---

# Ansible Skill

Conventions for the `ansible-<name>` role repos. Each is a **single-purpose role** that installs
one thing across Arch, Debian/Ubuntu, and macOS (optionally SteamOS), tested with Molecule and
published to Galaxy. Local test-harness specifics live in the project's `AGENTS.md`.

## Role anatomy

```
defaults/main.yml      # install: true toggle + user-facing vars (sane defaults)
vars/main.yml          # internal constants (optional)
tasks/
  main.yml             # entry: dispatch install vs uninstall
  install.yml          # OS dispatch + shared config steps
  uninstall.yml        # mirror of install, state: absent
  archlinux.yml        # community.general.pacman
  debian.yml           # apt / universe repo
  darwin.yml           # community.general.homebrew[_cask], become: false
  steamos.yml          # $HOME install, no become (optional target)
handlers/main.yml
meta/main.yml          # galaxy_info + dependencies
templates/ , files/
molecule/{default,localhost,steamdeck}/
.github/workflows/cicd.yml
pyproject.toml, uv.lock, requirements.yml, .ansible-lint, .yamllint
AGENTS.md, README.md
```

## Task flow

**`tasks/main.yml`** dispatches on an `install` toggle:

```yaml
- name: Install <thing>
  ansible.builtin.include_tasks: install.yml
  when: install | default(true) | bool
- name: Uninstall <thing>
  ansible.builtin.include_tasks: uninstall.yml
  when: not (install | default(true) | bool)
```

**`tasks/install.yml`** includes one guarded per-OS file, falls back to the generic `package:`
module for any other distro, then applies the shared user config that runs everywhere:

```yaml
- name: Include steamos # optional SteamOS target — installs under $HOME
  ansible.builtin.include_tasks: steamos.yml
  when: ansible_distribution_release == 'holo'
- name: Include archlinux
  ansible.builtin.include_tasks: archlinux.yml
  when: ansible_os_family == 'Archlinux' and ansible_distribution_release != 'holo'
- name: Include debian
  ansible.builtin.include_tasks: debian.yml
  when: ansible_os_family == 'Debian' and ansible_distribution_release != 'holo'
- name: Include darwin
  ansible.builtin.include_tasks: darwin.yml
  when: ansible_os_family == 'Darwin'
- name: Install <thing>
  become: true
  ansible.builtin.package:
    name: [<thing>]
    state: present
  when: ansible_os_family not in ['Archlinux', 'Darwin'] and ansible_distribution_release != 'holo'

- name: Deploy config # shared — runs on every OS
  become: false
  ansible.builtin.template:
    src: <thing>.toml.j2
    dest: ~/.config/<thing>/<thing>.toml
    mode: "0644"
```

Rules that fall out of this shape:

- **`become` discipline:** `become: true` only for system package installs; `become: false` for
  everything under `~/` and for macOS/SteamOS (no root there).
- Per-OS modules: Arch → `community.general.pacman` (`update_cache: true`); Debian → `apt`/universe;
  macOS → `community.general.homebrew` (formula) or `homebrew_cask` (GUI app), `become: false`.
- `uninstall.yml` mirrors `install.yml` with `state: absent` and the same OS guards.
- The `holo` guard (`ansible_distribution_release != 'holo'`) keeps the generic and Arch paths from
  firing on SteamOS, where the rootfs is read-only — see the role's `steamos.yml` / `AGENTS.md`.

## meta/main.yml

```yaml
galaxy_info:
  role_name: <name>
  namespace: <namespace>
  min_ansible_version: "2.16" # match the pyproject ansible-core lower bound
  platforms:
    - name: ArchLinux # capital L — Galaxy schema requires it
      versions: [all]
    - name: Debian
      versions: [all]
    - name: Ubuntu
      versions: [noble, jammy, focal]
    - name: macOS
      versions: [all]
    - name: GenericLinux
      versions: [all]
  galaxy_tags: [<lowercase-letters-and-digits-only>]
dependencies:
  - role: <namespace>.<dep> # shared dep (e.g. a fonts role); runs before this role
```

Never add a meta dependency that runs platform-specific tasks — meta deps run unconditionally on
every host. Use `include_role` inside a distro-guarded task file instead.

## Molecule (three scenarios)

- **`default`** — Docker driver, an Ubuntu image + a rolling Arch image (`pull: true`). `converge.yml`
  includes the role by its Galaxy name (`<namespace>.<name>`); `prepare.yml` upgrades Arch packages
  first (so an idempotency re-run doesn't find newer versions); `requirements.yml` lists `community.general`.
- **`localhost`** — real local-connection run (`-c local`) for verifying on actual hardware / macOS,
  where Docker can't help.
- **`steamdeck`** (optional) — Docker Arch image whose `prepare.yml` simulates SteamOS so the `holo`
  branch is exercised.

`verify.yml` makes **real assertions** — never `assert: that: true`:

```yaml
- name: Check <thing> binary
  ansible.builtin.stat: { path: /usr/bin/<thing> }
  register: bin
- name: Assert installed
  ansible.builtin.assert: { that: bin.stat.exists }
- name: Run --version
  ansible.builtin.command: <thing> --version
  register: ver
  changed_when: false
  failed_when: false # GPU apps (alacritty, ghostty) exit nonzero without a display
- name: Assert version output
  ansible.builtin.assert:
    that: ver.rc == 0 and '<thing>' in ver.stdout | lower
```

## CI (`.github/workflows/cicd.yml`)

Jobs: **lint** → **molecule** (+ a `steamdeck` job and a `macos` job where applicable) → **release**.

- `astral-sh/setup-uv@v8.1.0`, `python-version: "3.12"`, `uv sync`, `uv run molecule test`.
- `lint` runs `uv run yamllint .` and `uv run ansible-lint`, after
  `uv run ansible-galaxy role install -r requirements.yml`.
- The `macos` job (on `macos-latest`) installs Galaxy **roles and collections in separate steps**
  (`role install -p` does not install collections), then runs converge/verify against `localhost`.
- **release** is gated `needs: [lint, molecule, …]` + `if: github.ref == 'refs/heads/main'`, and
  publishes via `robertdebock/galaxy-action` using `GALAXY_API_KEY`.

## Tooling & lint

- `pyproject.toml` pins `ansible-core>=2.16,<2.18` and `requires-python = ">=3.11,<3.14"`; commit
  `uv.lock`. Manage deps with `uv` (`uv sync`, `uv lock`).
- `.ansible-lint`: `profile: production` (the strictest), excluding `molecule/`, `.ansible/`, `tests/`.
- `.yamllint`: `extends: default` with `ignore: | .venv/`, and `truthy` / `line-length` / `indentation` relaxed.
- `requirements.yml`: role deps under `roles:`, plus `collections: - name: community.general`.

## Production-profile gotchas

`profile: production` is strict — the recurring failures:

- **FQCN required** — `ansible.builtin.copy`, `community.general.pacman`, never bare `copy`/`pacman`.
- **`no-changed-when`** — every `command`/`shell` task and command handler needs `changed_when:`.
- **`latest[git]`** — every `ansible.builtin.git` task needs a pinned `version:`.
- **`meta-no-tags`** — `galaxy_tags` lowercase letters/digits only (no `-` or `_`).
- **schema[meta]** — `ArchLinux` (capital L) and valid platform names.
- **Idempotency** — no task may always report `changed`; split the Arch cache-update from the install.

For the full repo-by-repo modernization procedure, see the `update-ansible-role` skill.
