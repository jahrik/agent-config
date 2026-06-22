---
description: Walk all ansible-* repos alphabetically and apply the standard update pattern to each one that needs it. If run from inside a single role's repo, update only that role.
---

**First, check the current working directory.** If it contains `tasks/main.yml` (i.e. it's an Ansible role repo itself, not `/home/deck/github`), skip the multi-repo walk entirely and apply the standard update pattern (steps below) to just this one role in place. Treat it the same as a single repo found during the walk — same checks, same steps, same PR flow — just without iterating to a next repo afterward.

Otherwise, scan `/home/deck/github` for all `ansible-*` directories, sort them alphabetically, and work through each one in order. For each repo, inspect its current state to determine what needs updating — do not rely on any saved status list. The check is always live against the repo itself.

**Skip a repo** if it is not a standard Ansible role (no `tasks/main.yml` — e.g. playbook repos like `ansible-glastopf`, `ansible-awx`).

**A repo needs updating** if any of the following are true:

- `.github/workflows/cicd.yml` uses `actions/checkout` older than `@v5` or `astral-sh/setup-uv` older than `@v8.1.0`
- `.github/workflows/cicd.yml` still uses `gofrolist/molecule-action` (replaced by direct `uv run molecule test`)
- `.github/workflows/cicd.yml` still uses `pip3 install yamllint ansible-lint` or `pip3 install uv` (replaced by `astral-sh/setup-uv` + `uv sync`)
- `.github/workflows/cicd.yml` `release` job `needs:` does not include `lint`
- `.github/workflows/cicd.yml` macOS job uses `pip3 install ansible` instead of `uv sync`
- `.github/workflows/cicd.yml` macOS job uses a single `ansible-galaxy install` for both roles and collections (must be split into `role install` + `collection install`)
- `.github/workflows/cicd.yml` is missing `if: github.ref == 'refs/heads/main'` on the release job, or `galaxy-action@1.2.1`
- `.github/workflows/cicd.yml` lint job does not run `ansible-lint`
- `pyproject.toml` is missing or does not pin `ansible-core>=2.16,<2.18` and `requires-python = ">=3.11,<3.14"`
- `.ansible-lint` is missing or has `profile:` below `production`
- `.yamllint` is missing `ignore: | .venv/` block
- `molecule/default/molecule.yml` uses an outdated Ubuntu image (older than `geerlingguy/docker-ubuntu2404-ansible`, including `ubuntu2204`)
- `molecule/default/molecule.yml` Arch platform is missing `pull: true`
- `meta/main.yml` has `Archlinux` (lowercase l) instead of `ArchLinux` — Galaxy schema requires capital L
- `meta/main.yml` `min_ansible_version` does not match pyproject.toml pin (should be `'2.16'`)
- `meta/main.yml` `galaxy_tags` contains tags with underscores or hyphens — only lowercase letters and digits allowed (`meta-no-tags` rule)
- `molecule/default/requirements.yml` is missing
- `molecule/default/verify.yml` contains only `assert: that: true` (boilerplate)
- root `requirements.yml` is missing — all repos must have one (add `collections: - name: community.general` for repos with no role deps)
- `AGENTS.md` is missing or testing section does not include `uv sync && source .venv/bin/activate` before test commands
- `tasks/` contains non-FQCN modules or known bugs (see step 2)
- README is boilerplate Galaxy template
- the role installs a GUI app or CLI tool that would plausibly run on a Steam Deck and has no SteamOS/Steam Deck support (no `ansible_distribution_release == 'holo'` detection anywhere in `tasks/`) — add it per step 2b
- `tasks/` uses `ansible_distribution == 'SteamOS'` for SteamOS detection — broken on the real device (see step 2b); replace with `ansible_distribution_release == 'holo'`
- the role installs something with a Homebrew formula/cask and has no `tasks/darwin.yml` / `ansible_os_family == 'Darwin'` branch — add it per step 2c
- `meta/main.yml` `issue_tracker_url` points at a different repo (copy-paste bug — compare the URL's repo name against the actual repo)
- `tasks/` installs nerd fonts directly (font download/unarchive tasks) instead of depending on `jahrik.nerd_fonts` — roles that install fonts should declare `role: jahrik.nerd_fonts` in `meta/main.yml` dependencies and remove duplicate font tasks

Work through all repos in a single run. After finishing each repo, move to the next without stopping.

---

## Steps (apply to each repo in turn)

**One branch, one PR per repo per run** — the very first action on any repo is to cut (or re-use) a single branch:

```bash
git checkout main && git pull --ff-only
git checkout -b update-role
```

Every fix from steps 1-10 accumulates on that branch. Open exactly one PR when all fixes are done and local tests pass. Do not open a PR partway through and then open a second one for remaining fixes — gather everything first, then open one PR.

If `update-role` already exists and its PR was previously merged, delete the stale local branch and cut a fresh one from the updated `main`:

```bash
git checkout main && git pull --ff-only
git branch -D update-role
git checkout -b update-role
```

### 1. Understand the role

Read all key files in parallel — `defaults/main.yml`, `tasks/main.yml`, every file under `tasks/`, `meta/main.yml`, `molecule/default/molecule.yml`, `.github/workflows/cicd.yml`, and `README.md`. Issue all Read calls in a single message so they execute concurrently. Build a clear picture of what the role does, what OS families it supports, and what variables it exposes before writing any changes.

### 2. Fix tasks

Scan all files under `tasks/` for these known bugs:

**Copy-paste bugs** — wrong package names, wrong paths, wrong service names carried over from another role.

**Missing OS-family guards** — every distro-specific task must be guarded with `when: ansible_os_family == '...'`.

**Debian package not installed after OS-specific setup** — if `debian.yml` only sets up a PPA/cache and the generic `package:` task has `when: ansible_os_family not in ['Archlinux', 'Debian']`, Debian never gets the package. Fix: change the generic task condition to `when: ansible_os_family != 'Archlinux'` so Debian still gets installed.

**`when: x | default('true') == true` bug** — comparing a string default to a boolean is always False. Fix: `when: x | default(true) | bool`.

**Non-FQCN modules** — use `ansible.builtin.package`, `ansible.builtin.template`, `ansible.builtin.file`, `ansible.builtin.include_tasks`, `community.general.pacman`, etc.

**Arch-specific installs** — `archlinux.yml` should use `community.general.pacman`, not the generic `package:` module.

**`aur_packages` bare string** — when a role passes `aur_packages` to `jahrik.yay` via `vars:`, it must be a list, not a bare string. `aur_packages: polybar` causes "Invalid data passed to 'loop'". Fix: `aur_packages:\n  - polybar`.

**Template + follow-up file task for permissions** — if a `template` task sets `mode: '0644'` and a separate `file` task then sets `mode: '0755'` on the same file, every run reports changed. Fix: set the correct mode directly in the `template` task, drop the `file` task.

**`update_cache: true` in Arch pacman tasks** — CI containers run a cached Arch image whose pacman DB may be stale. Without `update_cache: true`, installs fail with 404 for packages that have been bumped since the image was built. For main role install tasks, split into two tasks: a dedicated cache-update task with `changed_when: false`, then a separate package install task without `update_cache`. This correctly reports changed only when packages are actually installed, and still protects against stale-DB 404s:

```yaml
- name: Update pacman cache (Arch Linux)
  become: true
  community.general.pacman:
    update_cache: true
  changed_when: false

- name: Install dependencies (Arch Linux)
  become: true
  community.general.pacman:
    name:
      - mypkg
    state: present
```

**`update_cache: true` idempotency in dependency roles** — For _prerequisite_ install tasks in dependency roles (e.g. `jahrik.nerd_fonts : Install fontconfig and unzip`), where the packages are very common and 404 is not a realistic risk, remove `update_cache: true` entirely — prepare.yml already synced the DB.

**Verify binary paths for source-built packages** — on Debian, packages built from source (e.g. polybar's `build.sh`) install to `/usr/local/bin/`, not `/usr/bin/`. Arch AUR packages go to `/usr/bin/`. Use `ansible.builtin.command: which <pkg>` with `changed_when: false` / `failed_when: false` and assert `rc == 0` instead of hardcoding the path.

**Idempotency** — no tasks that always report `changed`.

**`no-changed-when` on command handlers** — any handler using `ansible.builtin.command` or `ansible.builtin.shell` must have `changed_when: false`. The `production` ansible-lint profile enforces this.

**`latest[git]` — pin git clone versions** — any `ansible.builtin.git` task without a `version:` key fails the `production` profile's `latest[git]` rule. Always pin to a specific tag (e.g. `version: v1.9.1`). Look up the latest release tag with `git ls-remote --tags <repo> | grep -v '{}' | tail -5`.

**`meta/main.yml` platform name capitalization** — the Ansible Galaxy JSON schema requires `ArchLinux` (capital L). `Archlinux` (lowercase l) fails `ansible-lint schema[meta]`. Check and fix if wrong.

**`meta/main.yml` `min_ansible_version`** — must match pyproject.toml's `ansible-core` lower bound. Current standard: `'2.16'`.

**`meta/main.yml` `galaxy_tags`** — tags must be lowercase letters and digits only. No underscores (`i3_gaps` → `i3gaps`), no hyphens (`urxvt-pearls` → `urxvtpearls`). Violations fail the `meta-no-tags` rule in the `production` profile.

**`meta/main.yml` role dependencies** — never add a role dependency that runs platform-specific tasks (e.g. `jahrik.yay` which calls `pacman`). Meta dependencies run unconditionally on ALL hosts — they will break Ubuntu CI. Use `include_role` inside a distro-guarded task file instead.

### 2b. Add Steam Deck / SteamOS support (if applicable)

Applies if the role installs something that plausibly runs on a Steam Deck in desktop mode (terminal emulators, editors, CLI tools, GUI apps). Skip this step's detail entirely for roles where it obviously doesn't apply (services, server-only tools).

When it applies, don't re-derive the pattern from scratch — read the working code directly and adapt it:

- `ansible-nvim`: `tasks/install.yml`, `tasks/steamdeck.yml`, `tasks/uninstall.yml`, `molecule/steamdeck/`, `molecule/localhost/` — canonical structure; downloads static binaries from the project's own GitHub releases.
- `ansible-alacritty`: `tasks/steamos.yml` — the fallback pattern when no static binary or Flathub listing exists: extract the binary straight out of an archived Arch `.pkg.tar.zst` (plain zstd tarball, no pacman/root/build needed) via `ansible.builtin.unarchive` with `remote_src: true`; also has the desktop-entry + icon + `kbuildsycoca6` pattern for making a GUI app show up in KDE's launcher, and a `meta/main.yml`/README/AGENTS.md fully brought up to this standard as a second template to diff against.

Checklist when adapting:

- **Hard constraint, never violate:** never run `steamos-readonly disable` or otherwise touch SteamOS's read-only protection, even temporarily. Everything installs under `$HOME`, no `become`. If there's no way around it, leave the package unsupported on SteamOS.
- **Never use `exec zsh` (or any shell) in `.bashrc` on SteamOS** — the display manager sources bash startup files during session init. `exec` replaces bash with the new shell mid-session; PAM rejects shells not in `/etc/shells` (read-only on SteamOS), and a SteamOS update can invalidate user-local binaries with no bash fallback, causing a login lockout. To give users zsh as their default terminal, configure the terminal emulator (e.g. Konsole profile `Command=~/.local/bin/zsh`) — do not touch the login shell.
- **SteamOS detection** — use `ansible_distribution_release == 'holo'` throughout tasks. Do NOT use `ansible_distribution == 'SteamOS'` — on the real Steam Deck, Ansible reads `/etc/arch-release` first and reports `Archlinux`, so `ansible_distribution` is always wrong on the device. `ansible_distribution_release` reads `VERSION_CODENAME` from `/etc/os-release`, which is `holo` on all SteamOS versions and is unaffected by `/etc/arch-release`.
- Gate `include_tasks: steamdeck.yml` on `when: ansible_distribution_release == 'holo'`. Add `and ansible_distribution_release != 'holo'` to generic Arch/package install conditions.
- Install preference order: project's own GH release binary → Flathub (verify via `flathub.org/api/v2/search`, don't assume) → archived Arch package extraction → rule out source builds fast (no `cc`/`pkg-config`/headers on SteamOS).
- If the extracted binary needs a newer glibc than SteamOS ships (`ldd` shows `GLIBC_2.XX not found`), pin to the newest working version from `archive.archlinux.org/packages/<letter>/<pkg>/`.
- `tasks/uninstall.yml` needs the same `ansible_distribution_release == 'holo'` branch to remove the home-dir artifacts instead of calling `package: state: absent`.
- Test both ways: `molecule/steamdeck` (Docker, Arch image, `prepare.yml` fakes SteamOS detection — add a matching CI job, see step 4) and `molecule/localhost` (real local-connection run against actual Deck hardware).
- **SteamOS detection in `prepare.yml`**: to make `ansible_distribution_release == 'holo'` work in the Arch Docker container, the simulated `/etc/os-release` must include `VERSION_CODENAME=holo`, AND `/etc/arch-release` must be removed (Ansible prioritises it over `/etc/os-release` on Arch-based images). Template:

```yaml
- name: Remove /etc/arch-release to allow SteamOS detection
  become: true
  ansible.builtin.file:
    path: /etc/arch-release
    state: absent

- name: Simulate SteamOS /etc/os-release
  become: true
  ansible.builtin.copy:
    content: |
      ID=steamos
      ID_LIKE=arch
      NAME="SteamOS"
      PRETTY_NAME="SteamOS"
      VERSION_ID="3.6"
      VERSION_CODENAME=holo
    dest: /etc/os-release
    mode: "0644"
```

- Document the OS support matrix in README.md/AGENTS.md (ansible-nvim's "OS Support"/"Steam Deck Notes" format).

### 2c. Add macOS support (if applicable)

Applies whenever the package has a Homebrew formula or cask. Read `ansible-alacritty`'s `tasks/darwin.yml`/`tasks/install.yml`/`tasks/uninstall.yml` (one-line cask install, `become: false`) and `ansible-nvim`'s `tasks/darwin.yml` (multi-package formula install) directly — pick the shape that matches the role at hand rather than reinventing it.

Checklist:

- `tasks/darwin.yml`: `community.general.homebrew` (formula) or `community.general.homebrew_cask` (GUI app), `become: false` throughout.
- `tasks/install.yml`: add `include_tasks: darwin.yml` gated on `ansible_os_family == 'Darwin'`, and exclude Darwin from the generic `package:` install condition (`ansible_os_family not in ['Archlinux', 'Darwin']`, extending whatever exclusion list already exists).
- `tasks/uninstall.yml`: mirror with `state: absent` on the same homebrew module, gated the same way, and exclude Darwin from the generic `package: state: absent` condition.
- `molecule/localhost/verify.yml`: prefer `ansible.builtin.command: which <pkg>` over a hardcoded `/usr/bin/<pkg>` stat so the same scenario verifies Linux, Steam Deck, and macOS without branching per-OS.
- CI: add a `macos` job on `runs-on: macos-latest` — see the full template in step 4.
- `molecule/localhost/requirements.yml` must have both `roles:` (all Galaxy role deps) AND `collections: - name: community.general`.
- Add `macos` to `release`'s `needs:`.
- Update the OS support matrix in README.md/AGENTS.md.
- No local way to test the macOS path (no Mac, no macOS CI image for Podman) — the GitHub Actions `macos` job on the PR is the only verification; watch it instead of trying to fake it locally.

### 3. Add / update `.yamllint`

If missing or different, create/replace with this content (note the `ignore: | .venv/` block — required to prevent yamllint from scanning the virtualenv):

```yaml
---
extends: default

ignore: |
  .venv/

rules:
  braces:
    max-spaces-inside: 1
    level: error
  brackets:
    max-spaces-inside: 1
    level: error
  colons:
    max-spaces-after: -1
    level: error
  commas:
    max-spaces-after: -1
    level: error
  comments:
    min-spaces-from-content: 1
  comments-indentation: disable
  document-start: disable
  empty-lines:
    max: 3
    level: error
  hyphens:
    level: error
  indentation: disable
  key-duplicates: enable
  line-length: disable
  new-line-at-end-of-file: disable
  new-lines:
    type: unix
  octal-values:
    forbid-implicit-octal: true
    forbid-explicit-octal: true
  trailing-spaces: disable
  truthy: disable
```

### 3b. Add / update `.ansible-lint`

If missing or different, create/replace with:

```yaml
---
profile: production
exclude_paths:
  - .cache/
  - molecule/
  - .ansible/
  - tests/
```

`profile: production` is the highest ansible-lint profile. All roles in this repo already pass at this level. `molecule/` and `.ansible/` are excluded — the latter prevents Galaxy-installed roles from being scanned. `tests/` is excluded because old test scaffolding triggers `syntax-check[specific]`.

### 3c. Add / update `pyproject.toml`

All repos use `uv` for dependency management. If `pyproject.toml` is missing or non-standard, create/replace with:

```toml
[project]
name = "ansible-ROLENAME"
version = "0.1.0"
requires-python = ">=3.11,<3.14"
dependencies = [
    "ansible-core>=2.16,<2.18",
    "ansible-lint>=24.0.0",
    "molecule>=24.0.0",
    "molecule-plugins[docker]>=23.0.0",
    "yamllint>=1.38.0",
]
```

The `<3.14` upper bound is required — Python 3.14 requires ansible-core >= 2.20, incompatible with our `<2.18` pin. After writing `pyproject.toml`, run `uv lock` to generate/update `uv.lock`.

### 4. Update CI workflow (`.github/workflows/cicd.yml`)

Replace the entire workflow with the standard template. Key points:

- Use `astral-sh/setup-uv@v8.1.0` (not `actions/setup-python` + `pip3 install uv` — setup-uv handles install and caching; it no longer publishes minor tags so use the full version)
- Pin `python-version: '3.12'` (not `'3.x'` — that now resolves to 3.14 which is incompatible)
- Replace `gofrolist/molecule-action@v2` with direct `uv run molecule test` — uses pinned deps from `uv.lock`
- Add `lint` to `release` job's `needs` — lint failure must block Galaxy publish
- All repos must have a root `requirements.yml` (see step 5c) so the Galaxy install step is uniform

**Standard template (basic — lint + molecule + release):**

```yaml
---
name: CICD
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  workflow_dispatch:

jobs:
  lint:
    name: Lint
    runs-on: ubuntu-latest
    steps:
      - name: Check out the codebase
        uses: actions/checkout@v5
      - name: Set up Python 3
        uses: astral-sh/setup-uv@v8.1.0
        with:
          python-version: "3.12"
      - name: Install test dependencies
        run: uv sync
      - name: Install Galaxy requirements
        run: uv run ansible-galaxy role install -r requirements.yml
      - name: Lint code
        run: uv run yamllint .
      - name: Ansible lint
        run: uv run ansible-lint

  molecule:
    name: Molecule
    runs-on: ubuntu-latest
    steps:
      - name: Check out the codebase
        uses: actions/checkout@v5
      - name: Set up Python 3
        uses: astral-sh/setup-uv@v8.1.0
        with:
          python-version: "3.12"
      - name: Install test dependencies
        run: uv sync
      - name: Run Molecule
        run: uv run molecule test
        env:
          PY_COLORS: "1"
          ANSIBLE_FORCE_COLOR: "1"

  release:
    name: Release
    needs: [lint, molecule]
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - name: checkout
        uses: actions/checkout@v5
      - name: galaxy
        uses: robertdebock/galaxy-action@1.2.1
        with:
          galaxy_api_key: ${{ secrets.GALAXY_API_KEY }}
          git_branch: main
```

**If the role has a `molecule/steamdeck` scenario**, add a `steamdeck` job (identical to `molecule` but `run: uv run molecule test -s steamdeck`) and add `steamdeck` to `release`'s `needs:`.

**If the role has a `molecule/localhost` scenario (macOS)**, add a `macos` job and add `macos` to `release`'s `needs:`. The macOS job must split Galaxy install into role + collection steps — a single `ansible-galaxy install` with `-p` does not reliably install collections on the macOS runner:

```yaml
macos:
  name: macOS
  runs-on: macos-latest
  steps:
    - name: Check out the codebase
      uses: actions/checkout@v5
      with:
        path: jahrik.ROLE
    - name: Set up Python 3
      uses: astral-sh/setup-uv@v8.1.0
      with:
        python-version: "3.12"
    - name: Install test dependencies
      working-directory: jahrik.ROLE
      run: uv sync
    - name: Install Galaxy role requirements
      working-directory: jahrik.ROLE
      run: uv run ansible-galaxy role install -r molecule/localhost/requirements.yml -p ${{ github.workspace }}
    - name: Install Galaxy collection requirements
      working-directory: jahrik.ROLE
      run: uv run ansible-galaxy collection install -r molecule/localhost/requirements.yml
    - name: Run converge
      working-directory: jahrik.ROLE
      env:
        ANSIBLE_ROLES_PATH: ${{ github.workspace }}
      run: uv run ansible-playbook molecule/localhost/converge.yml -i "localhost," -c local
    - name: Run verify
      working-directory: jahrik.ROLE
      env:
        ANSIBLE_ROLES_PATH: ${{ github.workspace }}
      run: uv run ansible-playbook molecule/localhost/verify.yml -i "localhost," -c local
```

Key: `-p ${{ github.workspace }}` installs role deps alongside the checkout. `ANSIBLE_ROLES_PATH: ${{ github.workspace }}` finds both the role and its dependencies. `molecule/localhost/requirements.yml` must list both `roles:` and `collections:` (including `community.general`).

### 4b. Update molecule platform images to current OS versions

Check `molecule/default/molecule.yml` for outdated platform images and bump to the latest:

- Ubuntu: `geerlingguy/docker-ubuntu2404-ansible`. Old images (`ubuntu1804`, `ubuntu2004`, `ubuntu2204`) ship EOL or stale package sources — dead PPAs and expired third-party repos fail converge. Fall back to `ubuntu2204` only if the role genuinely breaks on 24.04.
- Arch: keep `jahrik/docker-archlinux-ansible` (rolling, no version bump) but ensure `pull: true` is set so the latest image is fetched.
- Also update version-pinned third-party repos in `tasks/` that the old image hid (e.g. NodeSource `node_17.x` is dead — use `deb https://deb.nodesource.com/node_20.x nodistro main` with key `https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key`).

**Ubuntu 24.04 compatibility — common breakage patterns:**

- **PPAs and `apt_key` fail in containers** — Ubuntu 24.04 containers don't have `gpg-agent`, so `ansible.builtin.apt_repository: repo: 'ppa:...'` and `ansible.builtin.apt_key` both fail with rc=2. Fix: check if the package is now in Ubuntu universe (most are) and install directly with `apt`. If a third-party repo is truly required, download the key with `ansible.builtin.get_url` to `/etc/apt/keyrings/` and use `signed-by=` in the repo string instead of `apt_key`.

- **Package renames on Ubuntu 24.04** — known renames discovered during role updates:
  - `ttf-dejavu` → `fonts-dejavu`
  - `conky` → `conky-all` (conky is now a virtual package)
  - `i3-gaps` → `i3` (gaps merged into mainline i3 at v4.20; `i3-gaps` no longer exists)
  - `python3-neovim` → `python3-pynvim`
  - NodeSource `node_17.x`/`node_20.x` repos → prefer `nodejs` from Ubuntu universe (ships Node 18 on 24.04)

- **Source builds often no longer needed** — packages like polybar that previously required building from source are now in Ubuntu universe. Check `apt show <pkg>` output in the container before keeping a complex source-build task.

### 5. Add `molecule/default/requirements.yml`

Always add this — it ensures `community.general` is available on the CI controller (needed for `pacman` and other modules):

```yaml
---
collections:
  - name: community.general
```

### 5b. Add `molecule/default/prepare.yml` for Arch scenarios

If the `molecule/default` scenario tests on Arch (`jahrik/docker-archlinux-ansible`), add a `prepare.yml` that upgrades all packages before converge. This prevents `update_cache: true` in role install tasks from finding newly-released package versions on the idempotency run:

```yaml
---
- name: Prepare
  hosts: all
  tasks:
    - name: Upgrade all packages to current
      become: true
      community.general.pacman:
        upgrade: true
        update_cache: true
      changed_when: false
      when: ansible_os_family == 'Archlinux'
```

Note: Do NOT add a `DisableSandbox` lineinfile task — it is now baked into the `jahrik/docker-archlinux-ansible` image itself. If an existing `prepare.yml` has a `DisableSandbox` task, remove it.

For `molecule/steamdeck` scenarios, add the `pacman -Syu` upgrade task BEFORE the SteamOS OS-simulation steps (remove `/etc/arch-release`, write `/etc/os-release` with `VERSION_CODENAME=holo` — see step 2b for the full template).

### 5c. Add / update root `requirements.yml`

All repos must have a root `requirements.yml` so the lint job Galaxy install step is uniform. Repos with no Galaxy role dependencies get a minimal file:

```yaml
---
collections:
  - name: community.general
```

Repos with Galaxy role dependencies list them under `roles:`:

```yaml
---
roles:
  - name: jahrik.nerd_fonts
collections:
  - name: community.general
```

Use the `roles:` key format — not the old flat list format (`- name: jahrik.foo` at the top level). The `ansible-arch-workstation` old format (`- name: ...` without `roles:`) is incorrect.

### 6. Update `molecule/default/verify.yml`

Replace the boilerplate (`assert: that: true`) with real assertions. For each binary the role installs: stat-check it exists, then run `--version` and assert on the output. Also check deployed config files. Follow this standard:

```yaml
---
- name: Verify
  hosts: all
  gather_facts: false
  tasks:
    - name: Check <pkg> binary
      ansible.builtin.stat:
        path: /usr/bin/<pkg>
      register: pkg_bin

    - name: Assert <pkg> is installed
      ansible.builtin.assert:
        that: pkg_bin.stat.exists
        fail_msg: "<pkg> binary not found at /usr/bin/<pkg>"

    - name: Run <pkg> --version
      ansible.builtin.command: <pkg> --version
      register: pkg_version
      changed_when: false

    - name: Assert <pkg> version output
      ansible.builtin.assert:
        that: "'<pkg>' in pkg_version.stdout | lower"
        fail_msg: "<pkg> --version did not produce expected output"

    - name: Check config file
      ansible.builtin.stat:
        path: ~/.config/<pkg>/<cfg>
      register: pkg_cfg

    - name: Assert config exists
      ansible.builtin.assert:
        that: pkg_cfg.stat.exists
        fail_msg: "config not found"
```

**Exceptions to `--version` checks:**

- **GPU-dependent terminals** (alacritty, ghostty): add `failed_when: false` on the command and assert `rc == 0` — they fail without a display but should still be present.
- **Wayland compositors** (sway, hyprland): skip `--version` entirely — they require kernel capabilities (`setuid`/`setcap`) that are absent in unprivileged Docker containers. A stat check on the binary is sufficient; running it at all will fail with `Operation not permitted`.
- **Tools installed to non-standard paths** (e.g. SteamOS `~/.local/bin/`): check the correct path, not `/usr/bin/`.

### 7. Update `README.md`

If the README is still the boilerplate Ansible Galaxy template (contains phrases like "A brief description of the role goes here" or "Any pre-requisites that may not be covered by Ansible itself"), rewrite it with actual content: what the role does, supported OS, key variables, example playbook, and testing instructions.

Use standard `molecule` commands in the README — **not `mtest`**. `mtest` is a local dev wrapper unknown to anyone else reading the repo. Testing section should show:

```bash
uv sync
source .venv/bin/activate
yamllint .
ansible-lint
molecule test
```

### 8. Add `AGENTS.md`

Create `AGENTS.md` (not `CLAUDE.md`) with:

- Role purpose (one paragraph)
- Key variables table (name, default, description) from `defaults/main.yml`
- Task flow (how `tasks/main.yml` branches)
- Testing commands — must include `uv sync` + activate before lint/molecule:

```bash
uv sync
source .venv/bin/activate
yamllint .
ansible-lint
molecule test
```

**Repo-facing content only** — committed docs (AGENTS.md and README alike) must never contain machine-specific details: no `mtest`, no `~/.venv/...` PATH prefixes, no Podman-shim or local Steam Deck notes. That context lives in the global `~/.claude/CLAUDE.md`. If an existing AGENTS.md contains `mtest` or venv PATH lines, fix them here.

### 9. Lint locally

```bash
PATH="$HOME/.local/bin:$HOME/.venv/ansible/bin:$PATH" yamllint . && \
PATH="$HOME/.local/bin:$HOME/.venv/ansible/bin:$PATH" ansible-lint
```

Fix all errors before proceeding. ansible-lint catches non-FQCN modules, risky commands, schema issues, `meta-no-tags`, `no-changed-when`, `latest[git]`, and other violations that yamllint misses.

### 10. Spawn background test agent, then continue to next repo

After lint passes, spawn a **background subagent** to run molecule tests while you immediately move on to steps 1-9 of the next repo:

```
Agent(
  description: "molecule test: ansible-REPONAME",
  run_in_background: true,
  prompt: "Run molecule tests for /home/deck/github/ansible-REPONAME.
  cd /home/deck/github/ansible-REPONAME
  Run: mtest test
  If it fails with 'doesn't appear to contain a role': rm -rf ~/.ansible/roles/jahrik.* && mtest test
  If it fails with 'already installed': rm -rf ~/.ansible/roles/jahrik.* ~/.ansible/tmp/molecule.* && mtest test
  If there is a molecule/steamdeck scenario, also run: mtest test -s steamdeck
  Report: PASS or FAIL with the full failure output if any job failed."
)
```

Do NOT wait for the subagent. Continue immediately to steps 1-9 for the next repo.

**Before opening any PR (step 11):** confirm the background test agent for that repo reported PASS. If it reported FAIL, fix the failures, re-run lint locally, then run a new `mtest test` directly (no subagent) and confirm it passes before committing.

> Note on parallelism: Podman/molecule can have resource contention if multiple `mtest test` runs overlap. If you see transient Docker-create errors, let the first test finish before launching the next.

`mtest` sets `DOCKER_HOST` and `PATH` correctly — never spell out the full env by hand.

### 11. Commit, push, open PR

This step happens once per repo, after all fixes from steps 1-10 are complete and local tests pass. The branch was already cut at the start of this repo's work (see the "one branch, one PR" rule above).

- Commit all changes in a single commit (or a small series of logical commits, all on the same `update-role` branch)
- Commit message: summarise what changed and why (not just "add AGENTS.md")
- PR title: `Update role: <repo-name>`
- PR body: bullet list of all changes made, plus a Test plan checklist (check items off as they're verified, including the CI run itself once it's green)
- **Never open a PR mid-fixes and then open another for remaining work in the same run.** If a fix is discovered while CI is running (e.g. a lint failure revealed by GitHub Actions), push the fix to the same branch — it goes into the open PR, not a new one.

### 12. Monitor CI and fix failures

Spawn a background subagent to watch the run while you continue working on other repos:

```
Agent(
  description: "watch CI: ansible-REPONAME",
  run_in_background: true,
  prompt: "Watch the GitHub Actions run for PR on branch update-role in /home/deck/github/ansible-REPONAME.
  Run: cd /home/deck/github/ansible-REPONAME
  RUN=$(gh run list --branch update-role --json databaseId --limit 1 --jq '.[0].databaseId')
  gh run watch $RUN
  gh run view $RUN --json jobs --jq '.jobs[] | \"\(.name): \(.conclusion)\"'
  If any job failed: gh run view --log-failed $RUN 2>&1 | grep -v RETRYING | tail -80
  Report: all job names and their conclusions, plus full failure log if any failed."
)
```

If CI fails: fix locally → lint → `mtest test` → commit → push. The open PR picks up the new commit automatically. Repeat until Lint ✅ Molecule ✅ Release ⏭ (release is skipped on PRs; it runs after merge to main).

---

## Notes

- `mtest` (`~/.local/bin/mtest`): sets `DOCKER_HOST` + `PATH` for Podman+molecule-docker, clears stale role-cache symlinks before running. Always prefer it over raw `molecule` for local runs.
- `ansible-core` is pinned to `2.16.*` in `~/.venv/ansible` — 2.17+ breaks molecule-docker boolean conditionals.
- Arch test image `jahrik/docker-archlinux-ansible`: has `DisableSandbox` baked into `/etc/pacman.conf` and `community.general` pre-installed. Do NOT add DisableSandbox to `prepare.yml`. Rebuilds daily — always set `pull: true` in `molecule.yml`.
- `GALAXY_API_KEY` must be set per-repo. Token at `galaxy.ansible.com/ui/token/`. Bulk update: `~/github/scripts/update-galaxy-token.sh`. New repos must be added to that script's list.
- **Never disable SteamOS read-only protection** (no `steamos-readonly disable`, ever). Everything installs under `$HOME`, no `become` for SteamOS paths.
- **SteamOS detection** — always use `ansible_distribution_release == 'holo'`, never `ansible_distribution == 'SteamOS'`. On the real Steam Deck, `/etc/arch-release` causes Ansible to report `Archlinux` for `ansible_distribution`, making every SteamOS guard silently broken. The `holo` codename (from `VERSION_CODENAME` in `/etc/os-release`) has been stable across all SteamOS 3.x releases.
- **Transient CI failure — GitHub API rate limit** — roles that call `uri: url: https://api.github.com/repos/.../releases/latest` unauthenticated may hit the 60 req/hr rate limit on shared GitHub Actions runners. This is transient; re-run the failed job with `gh run rerun <run-id> --repo jahrik/<repo> --failed`. Not a code bug.
- **PR branch hygiene** — before opening a PR, always verify `git log --oneline origin/main..<branch>` shows only the intended commits. If a fix branch was cut from a non-main branch (e.g. `update-role`), it will carry all of that branch's unmerged commits into the PR. Fix by cherry-picking the target commit onto a fresh branch from `origin/main`.
- **Nerd fonts** — `jahrik.nerd_fonts` handles all font installation. Roles that need fonts declare `dependencies: - role: jahrik.nerd_fonts` in `meta/main.yml` and do not implement font tasks themselves.
- **`astral-sh/setup-uv` versioning** — the action no longer publishes minor tags (`@v8` won't work). Always use the full version like `@v8.1.0`. Check https://github.com/astral-sh/setup-uv/releases for the latest.
- **`actions/setup-python` is no longer needed** when using `astral-sh/setup-uv` — pass `python-version:` directly to the setup-uv step instead.
- **macOS Galaxy collection install** — `ansible-galaxy role install -r requirements.yml -p $path` only installs roles (the `-p` flag applies to roles only). Collections from the same requirements.yml are silently skipped. Always add a separate `ansible-galaxy collection install -r requirements.yml` step after the role install step on macOS.
- **Python 3.14 incompatibility** — `python-version: '3.x'` in GitHub Actions now resolves to 3.14, which requires ansible-core >= 2.20. Always pin to `python-version: '3.12'` and cap `requires-python` at `<3.14` in pyproject.toml.
