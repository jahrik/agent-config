# Role patterns — full shapes

## tasks/main.yml — install toggle dispatch

```yaml
- name: Install <thing>
  ansible.builtin.include_tasks: install.yml
  when: install | default(true) | bool
- name: Uninstall <thing>
  ansible.builtin.include_tasks: uninstall.yml
  when: not (install | default(true) | bool)
```

## tasks/install.yml — per-OS dispatch + shared config

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

- **`become` discipline** — `become: true` only for system package installs; `become: false` for
  everything under `~/` and for macOS/SteamOS (no root there).
- Per-OS modules: Arch → `community.general.pacman` (`update_cache: true`); Debian →
  `apt`/universe; macOS → `community.general.homebrew` (formula) or `homebrew_cask` (GUI app),
  `become: false`.
- `uninstall.yml` mirrors `install.yml` with `state: absent` and the same OS guards.
- The `holo` guard keeps the generic and Arch paths from firing on SteamOS, where the rootfs is
  read-only.

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

## Molecule scenarios

- **`default`** — Docker driver, an Ubuntu image + a rolling Arch image (`pull: true`).
  `converge.yml` includes the role by Galaxy name (`<namespace>.<name>`); `prepare.yml` upgrades
  Arch packages first (so the idempotency re-run doesn't find newer versions); `requirements.yml`
  lists `community.general`.
- **`localhost`** — real local-connection run (`-c local`) for actual hardware / macOS.
- **`steamdeck`** (optional) — Docker Arch image whose `prepare.yml` simulates SteamOS so the
  `holo` branch is exercised.

### verify.yml — real assertions, never `assert: that: true`

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

Jobs: **lint** → **molecule** (+ `steamdeck` / `macos` jobs where applicable) → **release**.

- `astral-sh/setup-uv` (full-version pin), `python-version: "3.12"`, `uv sync`,
  `uv run molecule test`.
- `lint` runs `uv run yamllint .` and `uv run ansible-lint`, after
  `uv run ansible-galaxy role install -r requirements.yml`.
- The `macos` job (on `macos-latest`) installs Galaxy **roles and collections in separate steps**
  (`role install -p` does not install collections), then converge/verify against `localhost`.
- **release** is gated `needs: [lint, molecule, …]` + `if: github.ref == 'refs/heads/main'`,
  publishing via `robertdebock/galaxy-action` with `GALAXY_API_KEY`.

## Tooling & lint

- `pyproject.toml` pins `ansible-core` and `requires-python` (current values: the `update-repo`
  skill's Current Standard table); commit `uv.lock`; manage deps with `uv`.
- `.ansible-lint`: `profile: production`, excluding `molecule/`, `.ansible/`, `tests/`.
- `.yamllint`: `extends: default` with `ignore: | .venv/`; `truthy`/`line-length`/`indentation`
  relaxed.
- `requirements.yml`: role deps under `roles:`, plus `collections: [community.general]`.

## Production-profile gotchas

- **FQCN required** — `ansible.builtin.copy`, `community.general.pacman`, never bare names.
- **`no-changed-when`** — every `command`/`shell` task and command handler needs `changed_when:`.
- **`latest[git]`** — every `ansible.builtin.git` task needs a pinned `version:`.
- **`meta-no-tags`** — `galaxy_tags` lowercase letters/digits only.
- **schema[meta]** — `ArchLinux` (capital L) and valid platform names.
- **Idempotency** — no task may always report `changed`; split the Arch cache-update from the
  install.
