---
name: update-repo
description: Maintain and modernize repos by type (ansible-*, docker-*, arm-*, Go, Python) — triage drift live, bump pins, fix lint/CI/tests/docs, one branch + PR per repo. Walk all repos of a type alphabetically, or just the repo in the current dir.
---

# Update Repo

Drift-maintenance orchestration for every repo type: detect the type, load its reference, run the
shared loop.

## Detect the type

| Marker                                        | Reference               |
| --------------------------------------------- | ----------------------- |
| `tasks/main.yml`                              | `references/ansible.md` |
| `go.mod`                                      | `references/go.md`      |
| dir name `arm-*`                              | `references/arm.md`     |
| dir name `docker-*` + `Dockerfile`            | `references/docker.md`  |
| `.py` / `pyproject.toml` / `requirements.txt` | `references/python.md`  |

**Single-repo mode** — cwd matches a marker: run in place. **Walk mode** — otherwise scan the
projects directory for the type, alphabetically, without stopping. Inspect state **live**; never
trust a saved status list. Skip forks. A clean repo is a legitimate no-op — don't manufacture
churn.

## Shared loop

1. **Triage** against the type's checklist; conforming repos skipped without cutting a branch.
2. **Bump pins deliberately** — update the type's Current Standard table first, then the repo;
   pilot broad bumps on one repo end-to-end before propagating.
3. **One branch (`update-repo`), one PR per repo**; accumulate every fix on it.
4. **Lint + test locally**, then `devrev` + `secrev` in parallel on the diff; fix real findings.
5. **Open the PR** — never push to main, never auto-merge. GitHub ops via `mcp-github` tools
   only (`gh_pr_create`, `gh_run_list`, …) — the `gh` CLI is banned.
6. **Fold durable learnings back** via `/skill-creator`; repo one-offs go to that repo's `AGENTS.md`.

Delegation, commit/PR conventions, branch hygiene, transient-CI triage: `references/common.md`.
Load the type reference before touching a repo.
