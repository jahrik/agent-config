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
| README + AGENTS.md; keep docs in sync      | `infoarch`          |
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
- **`.pre-commit-config.yaml`**: missing, or missing the standard hooks (gitleaks, detect-secrets,
  pre-commit-hooks, prettier, local yamllint + ansible-lint).
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
- **Ansible best practices (web)** — the knowledge cutoff drifts, so `architect`/`releng` should
  **search the live Ansible docs** before asserting a standard: `docs.ansible.com` (playbook/role
  best-practices, module pages), the **porting guides** (`docs.ansible.com/ansible/latest/porting_guides/`)
  for deprecations/removals across the `ansible-core` line, and the module's own doc page for its
  **current default values and recommended parameters**. Prefer the official docs over memory; cite
  the page when a change is non-obvious. Fold durable findings back into this skill.

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

Copy each from a conforming role; the non-obvious bits:

- **`.yamllint`** — `extends: default`, `ignore: | .venv/` (skip the virtualenv), `octal-values`
  forbidding implicit+explicit octal; most stylistic rules disabled.
- **`.ansible-lint`** — `profile: production`; `exclude_paths: [.cache/, molecule/, .ansible/, tests/]`.
- **`.pre-commit-config.yaml`** — gitleaks, detect-secrets, pre-commit-hooks, prettier (scoped to
  `markdown, json` — leave YAML to yamllint), local `uv run` yamllint + ansible-lint.
- **`pyproject.toml`** — uv-managed; pins per the Current Standard table; run `uv lock` after writing.

### C. CI workflow — `releng`

`.github/workflows/cicd.yml` — copy from a conforming role; pins per the Current Standard table.
Triggers on push/PR to `main` + `workflow_dispatch`. Three jobs:

- **lint** — checkout → setup-uv (`python-version: '3.12'`) → `uv sync` →
  `ansible-galaxy role install -r requirements.yml` → `uv run yamllint .` → `uv run ansible-lint`.
- **molecule** — same setup → `uv run molecule test` (env `PY_COLORS` / `ANSIBLE_FORCE_COLOR`).
- **release** — `needs: [lint, molecule]`, `if: github.ref == 'refs/heads/main'`,
  `robertdebock/galaxy-action`. `lint` **must** be in `needs:` so lint failures block publishing.

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
`collections: [community.general]`; repos with role deps add a `roles:` key (`<owner>.<dependency>`).
If the scenario tests on Arch, add a `prepare.yml` that runs `community.general.pacman` with
`upgrade: true, update_cache: true` (become, `changed_when: false`, Arch-guarded) before converge —
stops the install task's `update_cache` from finding newer versions on the idempotency run.

### V. verify.yml — `infraeng`

Replace boilerplate (`assert: that: true`) with real assertions — copy the pattern from a conforming
role: per binary, `stat` it exists and assert; run `<pkg> --version` (`changed_when: false`) and
assert the name appears in `stdout | lower`; `stat` deployed config files too.

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

- **Minimalism — fewest lines that still read clearly.** The simplest role is the goal: every task,
  parameter, and variable must earn its place. Collapse what a loop or a single module call can do;
  delete dead vars, unused handlers, and commented-out cruft. Simpler beats clever — never trade
  readability for terseness.
- **Omit parameters equal to the module default.** If a module parameter's value matches its
  documented default, **drop it** (`state: present` on most modules, `become: false`, `update_cache`
  where already default, etc.). Confirm the default on the module's `docs.ansible.com` page (Phase 2
  web check) before removing — defaults vary by module and shift across `ansible-core` versions.
- **Don't restate role defaults.** A value already set in `defaults/main.yml` should not be repeated
  inline in a task; reference the variable. Conversely, hardcoded values that belong in `defaults/`
  move there (once) with clear, namespaced names — no magic paths/versions inline.
- **Duplication** — near-identical per-OS task files; factor shared steps into `block:` /
  `include_tasks`, distro-specific bits behind guards or `vars/<os>.yml`.
- **Loops over copy-paste** — repeated tasks differing only in a value → a single task with a loop.
- **Structure** — handlers for restarts (not inline), `block/rescue` where a failure path matters,
  tags where the role is large.
- **Production gaps** — missing `become` scoping, over-broad `become: true`, tasks that should be
  `changed_when`/`check_mode` aware.

When the cleanup changes what the role exposes or how it's used (a variable renamed, a default
added, a parameter dropped), have **`infoarch` update `README.md` + `AGENTS.md` in the same PR** so
the docs never drift from the role — keep them concise and command-first.

**Policy: propose, don't auto-apply.** Apply only **low-risk, behavior-preserving** cleanups (FQCN,
obvious dedup, dropping a redundant default-valued parameter, moving a literal into `defaults/`) on
the branch. List everything else — anything that could change behavior — as a **"Proposed
follow-ups"** section in the PR body for the maintainer to decide. Don't bundle risky refactors into
the modernization PR.

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

## Wrap-up — fold learnings back

Once the run is wrapped up (PRs opened/merged, sweep done), invoke **`/skill-creator`** to update
this skill with anything **durable and general** the session surfaced — a new task-bug pattern, a
shifted upstream standard or pin, a CI breakage and its fix, a sharper triage check. Skip one-off
repo specifics (those belong in the repo's `AGENTS.md`). Keep it lean: prefer a tightened line or a
single bullet over a new template, and trim at least as much as you add.

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
