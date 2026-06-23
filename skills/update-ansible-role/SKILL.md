---
name: update-ansible-role
description: Walk all ansible-* repos alphabetically and apply the standard update pattern to each one that needs it. If run from inside a single role's repo, update only that role.
---

**First, check the current working directory.** If it contains `tasks/main.yml` (it's an Ansible
role repo itself), skip the multi-repo walk and apply the update pattern below to just this role
in place. Otherwise, scan your projects directory for all `ansible-*` directories, sort them
alphabetically, and work through each in order. Inspect each repo's state live — do not rely on a
saved status list.

**Skip a repo** if it is not a standard Ansible role (no `tasks/main.yml` — e.g. playbook repos).

**A repo needs updating** if any of the following are true:

- CI (`.github/workflows/cicd.yml`) uses outdated actions, a legacy molecule action instead of
  `uv run molecule test`, `pip3 install` instead of `astral-sh/setup-uv` + `uv sync`, a `release`
  job whose `needs:` omits `lint`, or a lint job that doesn't run `ansible-lint`
- `pyproject.toml` is missing or doesn't pin `ansible-core` and `requires-python`
- `.ansible-lint` is missing or has a `profile:` below `production`
- `.yamllint` is missing the `ignore: | .venv/` block
- `molecule/default/molecule.yml` uses an outdated base image, or its Arch platform lacks `pull: true`
- `meta/main.yml` has the wrong platform capitalization (`Archlinux` vs `ArchLinux`), a
  `min_ansible_version` that doesn't match the pyproject pin, or `galaxy_tags` with underscores/hyphens
- `molecule/default/requirements.yml` or the root `requirements.yml` is missing
- `molecule/default/verify.yml` is boilerplate (`assert: that: true`)
- `AGENTS.md` is missing, or its testing section omits `uv sync && source .venv/bin/activate`
- `tasks/` contains non-FQCN modules or known bugs (see step 2)
- README is the boilerplate Galaxy template

Work through all repos in a single run; after each repo, move to the next without stopping.

---

## Delegating to subagents

This pattern is an orchestration. You stay the driver — own the per-repo branch, the sequencing,
the single PR, and the final go/no-go — but hand each self-contained step to the matching subagent.
Run the read-only review agents (`devrev`, `secrev`) and any independent work in parallel.

Subagents start cold: give each one the repo path, the branch, and a tight scope, and have it
**report back rather than open PRs or commit**. **Vet a subagent's findings against ground truth** —
a cold agent can be wrong (e.g. claim a current GitHub Action "doesn't exist", or misread an
idempotency guard); confirm load-bearing claims yourself before acting on them.

| Step                                | Agent               |
| ----------------------------------- | ------------------- |
| 1. Understand the role              | `architect`         |
| 2. Fix tasks                        | `infraeng`          |
| 3–5. Lint configs, CI, requirements | `releng`            |
| 6. Rewrite `verify.yml`             | `infraeng`          |
| 7–8. README + AGENTS.md             | `infoarch`          |
| 9b. Pre-PR review (parallel)        | `devrev` + `secrev` |
| 10. Run `molecule test`             | `qa`                |
| 12. Monitor CI, triage failures     | `releng`            |

Delegation is a judgement call, not a mandate: a small one-file fix is faster done inline — reach
for an agent when a step is sizeable or benefits from a dedicated lens. Don't spawn an agent to
re-run work the harness already tracks (e.g. a `molecule test` you launched in the background) —
wait for it instead.

---

## Steps (apply to each repo in turn)

**One branch, one PR per repo per run.** Cut a single branch first and accumulate every fix on it:

```bash
git checkout main && git pull --ff-only
git checkout -b update-role
```

Open exactly one PR when all fixes are done and local tests pass. If `update-role` already exists
from a merged PR, `git branch -D update-role` and cut a fresh one from the updated `main`.

### 1. Understand the role — `architect`

Read the key files in parallel — `defaults/main.yml`, everything under `tasks/`, `meta/main.yml`,
`molecule/default/molecule.yml`, `.github/workflows/cicd.yml`, `README.md`. Build a clear picture of
what the role does, which OS families it supports, and what variables it exposes before changing anything.

### 2. Fix tasks — `infraeng`

Scan all files under `tasks/` for these known bugs:

- **Copy-paste bugs** — wrong package/path/service names carried over from another role.
- **Missing OS-family guards** — every distro-specific task needs `when: ansible_os_family == '...'`.
- **Debian skipped after OS-specific setup** — if `debian.yml` only sets up a PPA and the generic
  `package:` task excludes Debian (`when: ansible_os_family not in ['Archlinux', 'Debian']`), Debian
  never installs the package. Fix the generic condition to `!= 'Archlinux'`.
- **`when: x | default('true') == true`** — a string compared to a boolean is always False. Fix:
  `when: x | default(true) | bool`.
- **Non-FQCN modules** — `ansible.builtin.package`, `community.general.pacman`, etc.
- **Arch installs** — `archlinux.yml` uses `community.general.pacman`, not generic `package:`.
- **Permission churn** — a `template` task with `mode: '0644'` followed by a `file` task setting
  `0755` on the same file always reports changed. Set the final mode in the `template` task; drop the `file` task.
- **Stale pacman DB in CI** — split Arch installs into a cache-update task (`update_cache: true`,
  `changed_when: false`) and a separate install task, so it reports changed only when packages change
  while still avoiding stale-DB 404s.
- **`no-changed-when`** — any `command`/`shell` task or handler needs `changed_when: false` (enforced by `production`).
- **`latest[git]`** — every `ansible.builtin.git` task needs a pinned `version:` (look up the tag with `git ls-remote --tags <repo>`).
- **`meta/main.yml`** — `ArchLinux` (capital L); `min_ansible_version` matches the pyproject pin;
  `galaxy_tags` lowercase letters/digits only; never add a role dependency that runs platform-specific
  tasks unconditionally (use `include_role` inside a distro-guarded task file instead).
- **Verify source-build paths** — Debian source builds land in `/usr/local/bin`, Arch in `/usr/bin`;
  assert with `command: which <pkg>` (`changed_when: false`, `failed_when: false`) rather than hardcoding.
- **Idempotency** — no task should always report `changed`.

> Niche/immutable target platforms (e.g. an immutable-rootfs OS, or macOS via Homebrew): gate their
> tasks on the correct detection fact, install under `$HOME` without `become` where the platform is
> read-only, and never disable a platform's security protections. Capture any such target's specifics
> in the project's environment notes (`AGENTS.md`), not in this skill.

### 3. Add / update `.yamllint`, `.ansible-lint`, `pyproject.toml` — `releng`

`.yamllint` (the `ignore: | .venv/` block is required so yamllint skips the virtualenv):

```yaml
---
extends: default
ignore: |
  .venv/
rules:
  comments-indentation: disable
  document-start: disable
  indentation: disable
  line-length: disable
  truthy: disable
  octal-values:
    forbid-implicit-octal: true
    forbid-explicit-octal: true
```

`.ansible-lint` (highest profile; exclude installed-role and test scaffolding paths):

```yaml
---
profile: production
exclude_paths:
  - .cache/
  - molecule/
  - .ansible/
  - tests/
```

`pyproject.toml` (uv-managed; pin ansible-core and cap Python so the pins stay compatible — newer
Python may require a newer ansible-core than the pin allows). Run `uv lock` after writing it:

```toml
[project]
name = "ansible-<rolename>"
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

### 4. Update CI workflow (`.github/workflows/cicd.yml`) — `releng`

Replace with the standard template. Use `astral-sh/setup-uv` (pin the full version — it no longer
publishes minor tags), pin `python-version: '3.12'` (not `'3.x'`, which resolves to a version
incompatible with the ansible-core pin), run `uv run molecule test` directly, and put `lint` in the
`release` job's `needs:` so lint failures block publishing.

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
      - uses: actions/checkout@v5
      - uses: astral-sh/setup-uv@v8.1.0
        with:
          python-version: "3.12"
      - run: uv sync
      - run: uv run ansible-galaxy role install -r requirements.yml
      - run: uv run yamllint .
      - run: uv run ansible-lint

  molecule:
    name: Molecule
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - uses: astral-sh/setup-uv@v8.1.0
        with:
          python-version: "3.12"
      - run: uv sync
      - run: uv run molecule test
        env:
          PY_COLORS: "1"
          ANSIBLE_FORCE_COLOR: "1"

  release:
    name: Release
    needs: [lint, molecule]
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v5
      - uses: robertdebock/galaxy-action@1.2.1
        with:
          galaxy_api_key: ${{ secrets.GALAXY_API_KEY }}
          git_branch: main
```

For extra Molecule scenarios, add a job mirroring `molecule` with `-s <scenario>` and add it to
`release`'s `needs:`. For a macOS path (Homebrew), add a `macos` job on `runs-on: macos-latest` that
installs Galaxy **roles and collections in separate steps** — `ansible-galaxy role install -p <path>`
does not install collections.

### 4b. Bump molecule platform images

- Ubuntu: use a current image (e.g. `geerlingguy/docker-ubuntu2404-ansible`). Old images ship EOL
  package sources — dead PPAs and expired repos fail converge.
- Arch: keep a rolling Arch-ansible image with `pull: true` so the latest is fetched.

**Ubuntu 24.04 breakage patterns:**

- **PPAs / `apt_key` fail in containers** (no `gpg-agent`). Prefer the package from Ubuntu universe;
  if a third-party repo is truly needed, `get_url` the key into `/etc/apt/keyrings/` and use `signed-by=`.
- **Package renames** — e.g. `ttf-dejavu` → `fonts-dejavu`, `conky` → `conky-all`, `i3-gaps` → `i3`,
  `python3-neovim` → `python3-pynvim`.
- **Source builds often unnecessary now** — packages that once needed building (e.g. polybar) are now
  in universe. Check `apt show <pkg>` before keeping a complex source-build task.

### 5. requirements.yml + Arch prepare

`molecule/default/requirements.yml` and the root `requirements.yml` both need at least
`collections: - name: community.general`. Repos with role deps add them under a `roles:` key:

```yaml
---
roles:
  - name: <owner>.<dependency>
collections:
  - name: community.general
```

If the default scenario tests on Arch, add `molecule/default/prepare.yml` to upgrade packages before
converge (prevents the install-task `update_cache` from finding newer versions on the idempotency run):

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

### 6. Update `molecule/default/verify.yml` — `infraeng`

Replace boilerplate with real assertions. For each binary: stat it exists, run `--version`, assert on
the output; also stat deployed config files.

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
    - name: Run <pkg> --version
      ansible.builtin.command: <pkg> --version
      register: pkg_version
      changed_when: false
    - name: Assert <pkg> version output
      ansible.builtin.assert:
        that: "'<pkg>' in pkg_version.stdout | lower"
```

Exceptions: GPU-dependent terminals (alacritty, ghostty) need `failed_when: false` + assert `rc == 0`;
Wayland compositors (sway, hyprland) can't run in unprivileged containers — stat the binary only.

### 7. README and 8. AGENTS.md — `infoarch`

Rewrite a boilerplate README with real content: what the role does, supported OS, key variables,
example playbook, and a testing section using **plain `molecule`** (not any local wrapper):

```bash
uv sync
source .venv/bin/activate
yamllint .
ansible-lint
molecule test
```

`AGENTS.md` (not `CLAUDE.md`): role purpose, key-variables table, task flow, and the same testing
commands. **Repo-facing content only** — committed docs must never contain machine-specific detail
(local wrappers, venv PATH prefixes, host-runtime notes); that lives in the project's environment
notes (`AGENTS.md` at the config root).

### 9. Lint locally

```bash
uv run yamllint . && uv run ansible-lint
```

Fix all errors before proceeding — ansible-lint catches non-FQCN modules, risky commands, schema
issues, `meta-no-tags`, `no-changed-when`, and `latest[git]`.

### 9b. Pre-PR review — `devrev` + `secrev` (parallel)

Once the role lints clean and before opening the PR, dispatch both review agents in parallel against
the branch diff; they are read-only so they cannot collide:

- **`devrev`** — correctness and idempotency: tasks that always report `changed`, missing OS-family
  guards, copy-paste bugs across near-identical task files, FQCN, verify assertions that can
  false-pass/false-fail.
- **`secrev`** — anything that downloads-and-executes (`get_url` + `command` of an install script),
  unpinned/unverified sources, predictable `/tmp` paths, committed secrets or hardcoded IPs, and
  weakened platform security.

Triage their findings: fix the real ones on the branch, and discard cold-start mistakes you've
verified are wrong. Lint passing is necessary but not sufficient — a clean lint says nothing about
whether an installer actually works on every platform; only `molecule test` (step 10) proves that.

### 10. Test, then continue — `qa`

Run `molecule test` (the project's local harness, per `AGENTS.md`) and have `qa` confirm the result:
converge + idempotence + verify all green on every platform. To keep moving through the walk, let
that test run in the background while you start the next repo's steps 1–9, but **confirm PASS before
opening that repo's PR**. Read the actual play recaps — don't trust an exit code alone (a wrapping
pipe or trailing command can mask a non-zero `molecule` exit).

### 11. Commit, push, open PR

One PR per repo, after all fixes are done and local tests pass:

- Single commit (or a small logical series) on the `update-role` branch
- PR title: `Update role: <repo-name>`
- PR body: bullet list of changes + a test-plan checklist
- Never open a PR mid-fixes and a second one for remaining work — push follow-up fixes to the same branch.

### 12. Monitor CI and fix failures — `releng`

```bash
RUN=$(gh run list --branch update-role --json databaseId --limit 1 --jq '.[0].databaseId')
gh run watch $RUN
gh run view $RUN --json jobs --jq '.jobs[] | "\(.name): \(.conclusion)"'
```

On failure: `gh run view --log-failed $RUN | tail -80`, fix locally → lint → `molecule test` →
commit → push. The open PR picks up the new commit. Repeat until Lint ✅ Molecule ✅ Release ⏭
(release runs only after merge to main).

---

## Notes

- **`astral-sh/setup-uv` versioning** — the action no longer publishes minor tags (`@v8` won't work);
  use the full version (e.g. `@v8.1.0`). `actions/setup-python` is unnecessary alongside it — pass
  `python-version:` to the setup-uv step.
- **Newer-Python incompatibility** — `python-version: '3.x'` resolves to the newest Python, which may
  require a newer ansible-core than the pin allows. Pin `'3.12'` and cap `requires-python` accordingly.
- **macOS Galaxy collections** — `ansible-galaxy role install -p <path>` installs roles only;
  collections are silently skipped. Add a separate `ansible-galaxy collection install` step.
- **Transient CI failure (GitHub API rate limit)** — roles that hit `api.github.com/.../releases/latest`
  unauthenticated can trip the 60 req/hr limit on shared runners; re-run the failed job rather than
  treating it as a code bug.
- **PR branch hygiene** — before opening a PR, verify `git log --oneline origin/main..<branch>` shows
  only the intended commits; a branch cut from a non-main base carries its unmerged commits into the PR.
