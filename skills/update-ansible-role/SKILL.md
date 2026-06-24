---
name: update-ansible-role
description: Maintain ansible-* role repos — triage drift, auto-bump pins to latest, fix tasks/CI/lint/docs, and deep-clean roles for DRY production readiness. Walk all repos alphabetically, or just the role in the current dir.
---

# Update Ansible Role

Keep `ansible-*` role repos current, clean, and production-ready. This is a **drift-maintenance**
orchestration, not a one-time conversion — most repos already conform, so the job is to detect what
drifted, bump what's stale, remediate what's broken, and propose deeper cleanups.

**Mode detection.** Check the current working directory first:

- **Single-role mode** — cwd contains `tasks/main.yml`. Skip the walk; run the phases against this
  role in place.
- **Walk mode** — otherwise, scan the projects directory for all `ansible-*` dirs, sort
  alphabetically, and work each in turn. **Skip** any without `tasks/main.yml` (playbook repos).

Inspect each repo's state **live** — never rely on a saved status list. Work through every repo in a
single run; after each, move to the next without stopping.

---

## You are the driver

You own per-repo branch, sequencing, the single PR, and the final go/no-go. Subagents do the
self-contained work and **report back — they never commit, push, or open PRs.** Subagents start
cold: give each the repo path, branch, and a tight scope. **Vet load-bearing claims against ground
truth** — a cold agent can misread an idempotency guard or claim a current action "doesn't exist".

Run read-only agents (`architect`, `devrev`, `secrev`) and independent per-repo work in parallel;
background-launch remediation on independent repos while you drive the next. Delegation is a
judgement call — a one-file fix is faster inline; reach for an agent when a step is sizeable or
benefits from a dedicated lens. Don't spawn an agent to re-run work the harness already tracks (e.g.
a backgrounded `molecule test`) — wait for it.

| Work                                       | Agent               |
| ------------------------------------------ | ------------------- |
| Understand the role; find DRY/hygiene gaps | `architect`         |
| Probe upstream for newer pins              | `releng`            |
| Fix tasks; rewrite `verify.yml`; refactor  | `infraeng`          |
| Lint configs, CI, requirements, pins       | `releng`            |
| README + AGENTS.md                         | `infoarch`          |
| Pre-PR review (parallel, read-only)        | `devrev` + `secrev` |
| Run `molecule test`; confirm from recaps   | `qa`                |
| Monitor CI, triage failures                | `releng`            |

---

## Current Standard — single source of truth

Every template below references these. **To roll out a new standard, bump it here only**, then run
the skill — Phase 2 propagates it to the repos.

| Knob                         | Current value                                           |
| ---------------------------- | ------------------------------------------------------- |
| `astral-sh/setup-uv`         | `@v8.2.0` (full version — no minor tags published)      |
| `actions/checkout`           | `@v7`                                                   |
| `robertdebock/galaxy-action` | `@1.2.1`                                                |
| CI Python                    | `'3.12'` (not `'3.x'` — resolves too new for the pin)   |
| `requires-python`            | `>=3.11,<3.14`                                          |
| `ansible-core`               | `>=2.16,<2.18` (and `min_ansible_version: '2.16'`)      |
| `ansible-lint`               | `>=24.0.0`, profile `production`                        |
| `molecule`                   | `>=24.0.0`; `molecule-plugins[docker]>=23.0.0`          |
| `yamllint`                   | `>=1.38.0`                                              |
| Ubuntu molecule image        | current `geerlingguy/docker-ubuntuXXXX-ansible` (24.04) |
| Arch molecule image          | rolling Arch-ansible image with `pull: true`            |

---

## Phase 1 — Triage scan (decide who needs work)

Cheaply classify every repo before entering the heavy pipeline. **Detect the molecule scenario name
first** (`ls molecule/`) — it may be `default`, `localhost` (macOS), or custom; never hardcode
`molecule/default/`. For each repo emit a verdict: `conforms` or `needs: [tasks, ci, lint,
requirements, verify, docs, pins, hygiene]`.

A repo **needs remediation** if any hold:

- **CI** (`.github/workflows/cicd.yml`): outdated actions vs the Current Standard table; a legacy
  molecule action instead of `uv run molecule test`; `pip3 install` instead of setup-uv + `uv sync`;
  a `release` job whose `needs:` omits `lint`; a lint job that doesn't run `ansible-lint`.
- **`pyproject.toml`**: missing, or doesn't pin `ansible-core` and `requires-python` per the table.
- **`.ansible-lint`**: missing or `profile:` below `production`.
- **`.yamllint`**: missing the `ignore: | .venv/` block.
- **molecule.yml** (any scenario): outdated base image; Arch platform lacks `pull: true`.
- **`meta/main.yml`**: wrong platform capitalization (`Archlinux` vs `ArchLinux`);
  `min_ansible_version` ≠ the pyproject pin; `galaxy_tags` with underscores/hyphens.
- **requirements**: scenario `requirements.yml` or root `requirements.yml` missing.
- **verify.yml** (detected scenario): boilerplate (`assert: that: true`).
- **AGENTS.md**: missing, or its testing section omits `uv sync && source .venv/bin/activate`.
- **tasks/**: non-FQCN modules or known bugs (Phase 3, step T).
- **pins**: a newer stable exists upstream (Phase 2 flags this).
- **hygiene**: duplication / non-DRY / production gaps (Phase 4 flags this).

Verdicts are heuristic — grep markers prove conformance of _shape_, not correctness. A repo passing
triage on shape still goes through Phase 2 (pins) and a quick Phase 4 (hygiene) scan. Only a repo
clean on **all** phases is a true no-op; report it as skipped and move on **without** cutting a branch.

> Triage is the cheap path: if the whole walk comes back `conforms`, the run is a legitimate no-op —
> say so plainly and reconcile the project tracker. Don't manufacture churn.

---

## Phase 2 — Latest check (pin, then auto-bump)

Pins stay pinned for reproducibility; "latest" means **deliberately bumping the pin when a newer
stable exists**, not floating ranges. For each repo entering remediation (and opportunistically for
conforming repos), have `releng` probe upstream and propose bumps:

- GitHub Actions — newest release of `setup-uv`, `checkout`, `galaxy-action`.
- Molecule base images — newest `geerlingguy/docker-ubuntuXXXX-ansible`; confirm Arch image rolls.
- Python tooling — newest stable `ansible-core` (respect the `<2.18`-style ceiling unless you also
  raise it deliberately), `ansible-lint`, `molecule`, `yamllint`.
- `git`-pinned upstreams in tasks — `git ls-remote --tags <repo> | grep -v '{}' | tail -5`.

Apply accepted bumps **to the Current Standard table first**, then to the repo's files. Bumping a
floor (e.g. the `ansible-core` ceiling) may require re-running `uv lock` and a fresh `molecule test`.

---

## Phase 3 — Remediation pipeline (per repo that failed triage)

**One branch, one PR per repo per run.** Cut a single branch and accumulate every fix on it:

```bash
git checkout main && git pull --ff-only
git checkout -b update-role
```

If `update-role` exists from a merged PR, `git branch -D update-role` and cut fresh from updated
`main`. Before opening the PR, verify `git log --oneline origin/main..update-role` shows only
intended commits.

### A. Understand the role — `architect`

Read in parallel: `defaults/main.yml`, everything under `tasks/`, `meta/main.yml`, the scenario's
`molecule.yml`, `.github/workflows/cicd.yml`, `README.md`. Establish what the role does, which OS
families it supports, and what variables it exposes before changing anything.

### T. Fix tasks — `infraeng`

Scan all `tasks/` files for these known bugs:

- **Copy-paste bugs** — wrong package/path/service names carried from another role.
- **Missing OS-family guards** — distro-specific tasks need `when: ansible_os_family == '...'`.
- **Debian skipped after OS-specific setup** — if `debian.yml` only sets up a PPA and the generic
  `package:` excludes Debian (`when: ansible_os_family not in ['Archlinux', 'Debian']`), Debian never
  installs. Fix the generic condition to `!= 'Archlinux'`.
- **`when: x | default('true') == true`** — string vs boolean is always False. Fix:
  `when: x | default(true) | bool`.
- **Non-FQCN modules** — `ansible.builtin.package`, `community.general.pacman`, etc.
- **Arch installs** — `archlinux.yml` uses `community.general.pacman`, not generic `package:`.
- **Permission churn** — a `template` (`mode: '0644'`) followed by a `file` setting `0755` on the
  same path always reports changed. Set the final mode in the `template`; drop the `file` task.
- **Stale pacman DB in CI** — split Arch installs into a cache-update task (`update_cache: true`,
  `changed_when: false`) and a separate install task.
- **`no-changed-when`** — any `command`/`shell` task or handler needs `changed_when: false`.
- **`latest[git]`** — every `ansible.builtin.git` needs a pinned `version:` (Phase 2).
- **`meta/main.yml`** — `ArchLinux` (capital L); `min_ansible_version` matches the pin; `galaxy_tags`
  lowercase letters/digits only; never add a role dependency that runs platform-specific tasks
  unconditionally (use `include_role` inside a distro-guarded task file).
- **Verify source-build paths** — Debian source builds land in `/usr/local/bin`, Arch in `/usr/bin`;
  assert with `command: which <pkg>` (`changed_when: false`, `failed_when: false`).
- **Idempotency** — no task should always report `changed`.

> Niche/immutable targets (immutable-rootfs OS, macOS via Homebrew): gate on the correct detection
> fact, install under `$HOME` without `become` where the platform is read-only, never disable a
> platform's security protections. Capture target specifics in the project's `AGENTS.md`, not here.

### L. Lint configs + pyproject — `releng`

`.yamllint` (the `.venv/` ignore is required so yamllint skips the virtualenv):

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

`.ansible-lint`:

```yaml
---
profile: production
exclude_paths:
  - .cache/
  - molecule/
  - .ansible/
  - tests/
```

`pyproject.toml` (uv-managed; values from the Current Standard table). Run `uv lock` after writing:

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

### C. CI workflow — `releng`

Replace with the standard template (versions from the Current Standard table). `lint` is in
`release`'s `needs:` so lint failures block publishing.

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
      - uses: actions/checkout@v7
      - uses: astral-sh/setup-uv@v8.2.0
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
      - uses: actions/checkout@v7
      - uses: astral-sh/setup-uv@v8.2.0
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
      - uses: actions/checkout@v7
      - uses: robertdebock/galaxy-action@1.2.1
        with:
          galaxy_api_key: ${{ secrets.GALAXY_API_KEY }}
          git_branch: main
```

Extra Molecule scenarios: add a job mirroring `molecule` with `-s <scenario>` and add it to
`release`'s `needs:`. macOS path (Homebrew): a `macos` job on `runs-on: macos-latest` that installs
Galaxy **roles and collections in separate steps** (`role install -p <path>` does not install
collections).

**Molecule image breakage (Ubuntu 24.04):**

- **PPAs / `apt_key` fail in containers** (no `gpg-agent`). Prefer the universe package; if a
  third-party repo is truly needed, `get_url` the key into `/etc/apt/keyrings/` and use `signed-by=`.
- **Package renames** — `ttf-dejavu`→`fonts-dejavu`, `conky`→`conky-all`, `i3-gaps`→`i3`,
  `python3-neovim`→`python3-pynvim`.
- **Source builds often unnecessary now** — check `apt show <pkg>` before keeping a source-build task.

### R. requirements + Arch prepare — `releng`

The scenario's `requirements.yml` and the root `requirements.yml` both need at least
`collections: - name: community.general`. Repos with role deps add a `roles:` key:

```yaml
---
roles:
  - name: <owner>.<dependency>
collections:
  - name: community.general
```

If the scenario tests on Arch, add `prepare.yml` to upgrade packages before converge (prevents the
install task's `update_cache` finding newer versions on the idempotency run):

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

### V. verify.yml — `infraeng`

Replace boilerplate with real assertions. Per binary: stat it exists, run `--version`, assert on
output; also stat deployed config files.

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

### D. README + AGENTS.md — `infoarch`

Rewrite boilerplate with real content: what the role does, supported OS, key variables, example
playbook, and a testing section using **plain `molecule`** (not any local wrapper):

```bash
uv sync
source .venv/bin/activate
yamllint .
ansible-lint
molecule test
```

`AGENTS.md` (never `CLAUDE.md`): role purpose, key-variables table, task flow, same testing commands.
**Repo-facing content only** — committed docs must never carry machine-specific detail (local
wrappers, venv PATH prefixes, host-runtime notes); that lives in the project's `AGENTS.md` at the
config root.

### Lint locally, then review

```bash
uv run yamllint . && uv run ansible-lint
```

Fix all errors before proceeding. Then dispatch the read-only reviewers **in parallel** on the branch
diff:

- **`devrev`** — correctness/idempotency: always-`changed` tasks, missing OS guards, copy-paste bugs
  across near-identical task files, FQCN, verify assertions that false-pass/fail.
- **`secrev`** — download-and-execute (`get_url` + `command` of an installer), unpinned/unverified
  sources, predictable `/tmp` paths, committed secrets / hardcoded IPs, weakened platform security.

Triage findings: fix the real ones; discard verified cold-start mistakes. Lint passing is necessary,
not sufficient — only `molecule test` proves an installer works on every platform.

### Test — `qa`

Run `molecule test` (the project's local harness per `AGENTS.md`); `qa` confirms converge +
idempotence + verify green on **every** platform from the **actual play recaps** — never trust an exit
code alone (a wrapping pipe can mask a non-zero exit). Background the test and start the next repo's
phases while it runs, but **confirm PASS before opening that repo's PR**.

---

## Phase 4 — Deep role hygiene (DRY + production readiness)

A code-quality lens beyond lint markers. `architect` analyses (read-only), `devrev` vets, `infraeng`
applies. Look for:

- **Duplication** — near-identical per-OS task files; factor shared steps into `block:` /
  `include_tasks`, distro-specific bits behind guards or `vars/<os>.yml`.
- **Loops over copy-paste** — repeated tasks differing only in a value → a single task with a loop.
- **Variable hygiene** — hardcoded values that belong in `defaults/main.yml`; clear, namespaced
  names; no magic paths/versions inline.
- **Structure** — handlers for restarts (not inline), `block/rescue` where a failure path matters,
  tags where the role is large.
- **Production gaps** — missing `become` scoping, over-broad `become: true`, tasks that should be
  `changed_when`/`check_mode` aware.

**Policy: propose, don't auto-apply.** Apply only **low-risk, behavior-preserving** cleanups (FQCN,
obvious dedup, moving a literal into `defaults/`) on the branch. List everything else — anything that
could change behavior — as a **"Proposed follow-ups"** section in the PR body for the maintainer to
decide. Don't bundle risky refactors into the modernization PR.

---

## Commit, PR, and watch CI

One PR per repo, after all fixes land and local `molecule test` passes:

- Single commit (or a small logical series) on `update-role`; attribute with the `Co-Authored-By:`
  trailer.
- Title: `Update role: <repo-name>`.
- Body: bullet list of changes + a test-plan checklist + any Phase 4 "Proposed follow-ups".
- Never open a PR mid-fixes and a second for the rest — push follow-ups to the same branch.
- **Never push to main; never auto-merge.** Open the PR and let the maintainer merge.

```bash
RUN=$(gh run list --branch update-role --json databaseId --limit 1 --jq '.[0].databaseId')
gh run watch $RUN
gh run view $RUN --json jobs --jq '.jobs[] | "\(.name): \(.conclusion)"'
```

On failure: `gh run view --log-failed $RUN | tail -80`, fix locally → lint → `molecule test` →
commit → push (the open PR picks it up). Repeat until Lint ✅ Molecule ✅ Release ⏭ (release runs
only after merge to main).

---

## Notes

- **`astral-sh/setup-uv` versioning** — no minor tags (`@v8` won't work); use the full version.
  `actions/setup-python` is unnecessary alongside it — pass `python-version:` to the setup-uv step.
- **Newer-Python incompatibility** — `'3.x'` resolves to the newest Python, which may demand a newer
  `ansible-core` than the pin allows. Pin `'3.12'` and cap `requires-python`.
- **macOS Galaxy collections** — `ansible-galaxy role install -p <path>` installs roles only; add a
  separate `ansible-galaxy collection install` step.
- **Transient CI failure (GitHub API rate limit)** — roles hitting
  `api.github.com/.../releases/latest` unauthenticated can trip the 60 req/hr limit on shared
  runners; re-run the job rather than treating it as a code bug.
- **PR branch hygiene** — before opening a PR, confirm `git log --oneline origin/main..update-role`
  shows only intended commits; a branch cut from a non-main base drags its unmerged commits in.
