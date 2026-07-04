# Ansible roles (`ansible-*`)

Shared machinery (driver, branch/PR, CI watch, hygiene policy): `common.md`. Conventions: the
`ansible` skill. Skip dirs without `tasks/main.yml` (playbook repos). Branch name: `update-role`;
PR title `Update role: <repo-name>`.

## Current Standard — single source of truth

Bump a new standard **here only**, then run the skill to propagate.

| Knob                         | Current value                                                                          |
| ---------------------------- | -------------------------------------------------------------------------------------- |
| `astral-sh/setup-uv`         | `@v8.2.0` (full version — no minor tags published)                                     |
| `actions/checkout`           | `@v7`                                                                                  |
| `robertdebock/galaxy-action` | `@1.2.1`                                                                               |
| CI Python                    | `'3.12'` (not `'3.x'` — resolves too new for the pin)                                  |
| `requires-python`            | `>=3.12,<3.14` (ansible-core 2.20+ needs Python ≥3.12)                                 |
| `ansible-core`               | `>=2.16,<2.22` (and `min_ansible_version: '2.16'`)                                     |
| `ansible-lint`               | `>=24.0.0`, profile `production`                                                       |
| `molecule`                   | `>=24.0.0`; `molecule-plugins[docker]>=23.0.0`                                         |
| `yamllint`                   | `>=1.38.0`                                                                             |
| Ubuntu molecule image        | current `geerlingguy/docker-ubuntuXXXX-ansible` (26.04)                                |
| Arch molecule image          | rolling Arch-ansible image with `pull: true`                                           |
| Fact access                  | `ansible_facts['<fact>']` (bracket); `ansible.cfg` sets `inject_facts_as_vars = False` |

## Triage checklist

Detect the molecule scenario name first (`ls molecule/`) — `default`, `localhost` (macOS), or
custom; never hardcode `molecule/default/`. A repo needs remediation if any hold:

- **CI** (`.github/workflows/cicd.yml`): outdated actions vs the table; legacy molecule action
  instead of `uv run molecule test`; `pip3 install` instead of setup-uv + `uv sync`; `release` job
  `needs:` omits `lint`; lint job doesn't run `ansible-lint`.
- **`pyproject.toml`**: missing, or pins off-table.
- **`.ansible-lint`**: missing or profile below `production`.
- **`.yamllint`**: missing the `ignore: | .venv/` block or off-standard (must
  `document-start: disable` — the no-`---` `.pre-commit-config.yaml` fails ansible-lint's yaml rule
  otherwise).
- **`.pre-commit-config.yaml`**: missing the standard hooks (gitleaks, detect-secrets,
  pre-commit-hooks, prettier, local yamllint + ansible-lint).
- **molecule.yml**: outdated base image; Arch platform lacks `pull: true`; a `localhost` scenario
  binding `ansible_connection: local` under `inventory.hosts.<name>` instead of
  `inventory.host_vars.<name>` (the `hosts:` form can be read as a group so the binding is lost).
- **facts**: any bare `ansible_<fact>` magic var anywhere, or missing `ansible.cfg` with
  `inject_facts_as_vars = False`.
- **`meta/main.yml`**: `Archlinux` vs `ArchLinux`; `min_ansible_version` ≠ pyproject pin;
  `galaxy_tags` with underscores/hyphens.
- **requirements**: scenario or root `requirements.yml` missing.
- **verify.yml**: boilerplate (`assert: that: true`).
- **AGENTS.md**: missing, or testing section omits `uv sync && source .venv/bin/activate`.
- **tasks/**: non-FQCN modules or known bugs (below).

Verdicts are heuristic — shape, not correctness. A shape-conforming repo still gets a pins check
and quick hygiene scan; only clean-on-all-phases is a true no-op.

## Latest check (pins)

`releng` probes upstream: newest `setup-uv`/`checkout`/`galaxy-action` releases; newest
`geerlingguy/docker-ubuntuXXXX-ansible`; newest stable `ansible-core`/`ansible-lint`/`molecule`/
`yamllint`; `git`-pinned upstreams via `git ls-remote --tags`. **Search the live Ansible docs**
(best practices, porting guides, module pages) before asserting a standard — prefer docs over
memory, cite when non-obvious.

Bumping the `ansible-core` ceiling requires `uv lock --upgrade` then a fresh `molecule test` —
plain `uv lock` keeps an existing in-range pin. Coupling: ansible-core 2.20+ forces
`requires-python >=3.12`. The Ubuntu 26.04 image's Python 3.14 is target-side only; the `<3.14`
cap constrains the controller venv.

## Remediation steps

### T. Fix tasks (`devlead`)

Known bugs to scan for in all `tasks/` files:

- **Copy-paste bugs** — wrong package/path/service names carried from another role.
- **Missing OS-family guards** on distro-specific tasks.
- **Debian skipped after OS-specific setup** — if `debian.yml` only adds a PPA and the generic
  `package:` excludes Debian, Debian never installs; fix the condition to `!= 'Archlinux'`.
- **`when: x | default('true') == true`** — string vs boolean, always False. Fix:
  `when: x | default(true) | bool`.
- **Fact magic vars** — migrate every bare `ansible_<fact>` to `ansible_facts['<fact>']` across
  tasks/molecule/templates/defaults/verify; add `ansible.cfg` with `inject_facts_as_vars = False`.
  Derive the real fact set live (`ansible -m setup localhost`) — never from a hardcoded list (lags
  upstream; can't tell facts from user vars like `ansible_force_color`). Never touch connection
  vars (`ansible_connection`, `ansible_user`, `ansible_python_interpreter`). Quote collision: a
  bracket subscript inside a single-quoted scalar breaks YAML — use `ansible_facts["x"]` there.
- **Non-FQCN modules**; Arch installs use `community.general.pacman`, not generic `package:`.
- **Permission churn** — `template` then `file` re-moding the same path always reports changed;
  set the final mode in the `template`.
- **Stale pacman DB in CI** — split cache-update (`update_cache: true`, `changed_when: false`)
  from install.
- **`no-changed-when`** — `command`/`shell` tasks and handlers need `changed_when: false`.
- **`latest[git]`** — every `ansible.builtin.git` needs a pinned `version:`.
- **`meta/main.yml`** — `ArchLinux`; `min_ansible_version` matches the pin; `galaxy_tags`
  lowercase letters/digits; never a role dependency that runs platform-specific tasks
  unconditionally (use distro-guarded `include_role`).
- **Verify source-build paths** — Debian source builds land in `/usr/local/bin`, Arch in
  `/usr/bin`; assert with `command: which <pkg>` (`changed_when: false`, `failed_when: false`).
- **Idempotency** — no task always reports `changed`.

Niche/immutable targets (immutable-rootfs OS, macOS/Homebrew): gate on the correct detection fact,
install under `$HOME` without `become`, never disable platform security. Target specifics go in
the repo's `AGENTS.md`.

### L. Lint configs + pyproject (`releng`)

Copy from a conforming role. Non-obvious bits: `.yamllint` `extends: default` +
`ignore: | .venv/` + octal-values rules; `.ansible-lint` `profile: production` +
`exclude_paths: [.cache/, molecule/, .ansible/, tests/]`; `.pre-commit-config.yaml` with prettier
scoped to `markdown, json` (YAML stays with yamllint); `pyproject.toml` uv-managed, pins per the
table, `uv lock` after writing.

### C. CI workflow (`releng`)

`.github/workflows/cicd.yml`, three jobs: **lint** (checkout → setup-uv `python-version: '3.12'` →
`uv sync` → `ansible-galaxy role install -r requirements.yml` → yamllint → ansible-lint),
**molecule** (same setup → `uv run molecule test`), **release** (`needs: [lint, molecule]`,
`if: github.ref == 'refs/heads/main'`, galaxy-action — `lint` **must** be in `needs:`). Extra
scenarios: mirror the molecule job with `-s <scenario>` and add to release `needs:`. macOS job:
install Galaxy **roles and collections in separate steps** (`role install -p` skips collections).

Ubuntu 24.04+ image breakage: PPAs/`apt_key` fail in containers (no gpg-agent) — prefer the
universe package, else `get_url` key into `/etc/apt/keyrings/` + `signed-by=`. Renames:
`ttf-dejavu`→`fonts-dejavu`, `conky`→`conky-all`, `i3-gaps`→`i3`, `python3-neovim`→`python3-pynvim`.
Check `apt show <pkg>` before keeping a source-build task.

### R. Requirements + Arch prepare (`releng`)

Scenario and root `requirements.yml` both need at least `collections: [community.general]`; role
deps add a `roles:` key. Arch scenarios add `prepare.yml` running `community.general.pacman` with
`upgrade: true, update_cache: true` (become, `changed_when: false`, Arch-guarded) so the install
task's cache update doesn't break the idempotency run.

### V. verify.yml (`devlead`)

Replace `assert: that: true` with real assertions: `stat` each binary and assert; run
`<pkg> --version` (`changed_when: false`) and assert the name in `stdout | lower`; `stat` deployed
configs. Exceptions: GPU-dependent terminals (alacritty, ghostty) need `failed_when: false` +
assert `rc == 0`; Wayland compositors can't run in unprivileged containers — stat the binary only.

### D. Docs (`releng`)

README: what the role does, supported OS, key variables, example playbook, testing section with
plain commands (`uv sync`, `source .venv/bin/activate`, `yamllint .`, `ansible-lint`,
`molecule test`). AGENTS.md: purpose, key-variables table, task flow, same commands.

### Lint + test

`uv run yamllint . && uv run ansible-lint` clean before review. Only `molecule test` proves an
installer works: `qa` confirms converge + idempotence + verify green on **every** platform from
the **actual play recaps** — never trust an exit code (a wrapping pipe can mask it). Background
the test and drive the next repo, but confirm PASS before that repo's PR.

## Ansible-specific hygiene

Omit parameters equal to the module default (`state: present`, `become: false`, …) — confirm on
the module's docs page first. Don't restate `defaults/main.yml` values inline; move hardcoded
paths/versions into namespaced defaults. Factor near-identical per-OS task files into `block:`/
`include_tasks` with guards or `vars/<os>.yml`. Handlers for restarts; `block/rescue` where a
failure path matters.

## Notes

- **Meta-role ↔ Galaxy publish ordering** — `inject_facts_as_vars = False` is play-global, so a
  meta-role imposes it on its **published Galaxy** deps. Until dep migrations are merged **and
  released**, the meta-role's CI pulls old magic-var deps and fails (or passes by luck on a
  lenient controller). Keep the setting uniform; open all PRs together, **merge + release leaf
  roles first**, then re-run the meta-roles' CI. Pure ordering — no code change fixes it.
- **Sequential molecule sweeps exhaust local resources** (Podman): later repos die with `rc=137`/
  `rc=125`, "no such container", spurious `unreachable=1` — environmental, not a code bug. `podman
container prune` between repos; `podman system prune -f` and re-run failures one at a time.
- `actions/setup-python` is unnecessary alongside setup-uv — pass `python-version:` to setup-uv.
- `'3.x'` resolves to the newest Python, which may demand a newer ansible-core than the pin — pin
  `'3.12'` and cap `requires-python`.
