---
description: Walk the Python project repos alphabetically and modernize each one (Python 3, ruff lint, CI, README, AGENTS.md)
---

Scan `/home/deck/github` for Python project repos — directories whose primary content is `.py` files, `requirements.txt`, `setup.py`, or `pyproject.toml` (currently: `chatterbot-voice`, `checkio`, `edward`, `flask_wishlist`, `GitHarvester`, `linuxacademy-python`, `microblog` — but always rescan: the list is illustrative, and hybrid repos like `edward` with a Dockerfile alongside the Python code still count as Python projects). Sort alphabetically and work through each one in order. Inspect each repo's current state live — do not rely on any saved status list.

**Skip a repo** if it's not really a Python project (a couple of incidental scripts in a repo of another type doesn't count), or if it's an archived fork of someone else's project (e.g. `inaturalist`).

**A repo needs updating** if any of the following are true:
- Python 2 syntax anywhere (`print` statements, `urllib2`, old-style `except`)
- No `.github/workflows/ci.yml` lint workflow
- No `pyproject.toml`/ruff config and code doesn't pass `ruff check`
- Dependencies in `requirements.txt` are unpinned or reference dead/renamed packages
- `AGENTS.md` is missing
- README is missing or stub

Work through all repos in a single run. After finishing each repo, move to the next without stopping.

These are old learning/demo projects — the goal is "runs on a current Python and lints clean", not a rewrite. Keep changes minimal and behavior-preserving.

---

## Steps (apply to each repo in turn)

### 1. Understand the repo
Read the entry-point scripts, `requirements.txt`/`setup.py`, and `README.md`. Figure out: what it does, how it's run, and whether it has tests.

### 2. Port to Python 3 (if needed)
- `print x` → `print(x)`, `urllib2` → `urllib.request`, `except E, e` → `except E as e`, `dict.iteritems()` → `.items()`, etc.
- Verify every file at least compiles: `python3 -m py_compile $(git ls-files '*.py')`
- If the project has a runnable entry point, smoke-test it in a venv.

### 3. Fix dependencies
- Pin versions in `requirements.txt` to currently-installable releases (`pip index versions <pkg>` or test in a throwaway venv)
- Replace dead/renamed packages with their successors; drop ones only needed for Python 2
- Smoke test: `python3 -m venv /tmp/venv-<repo> && /tmp/venv-<repo>/bin/pip install -r requirements.txt`

### 4. Lint with ruff
Add to `pyproject.toml` (create the file if missing):
```toml
[tool.ruff]
line-length = 100
target-version = "py311"
```
Then:
```bash
uvx ruff check --fix .
uvx ruff format .
```
(or `pipx run ruff` / a venv if `uvx` is unavailable). Review the diff — don't let autofix change behavior.

### 5. Add `.github/workflows/ci.yml`
```yaml
---
name: CI

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]
  workflow_dispatch:

jobs:
  lint:
    name: Lint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - uses: actions/setup-python@v6
        with:
          python-version: '3.x'
      - run: pipx run ruff check .
      - run: python3 -m py_compile $(git ls-files '*.py')

  test:
    name: Test
    runs-on: ubuntu-latest
    if: ${{ hashFiles('tests/**') != '' }}
    steps:
      - uses: actions/checkout@v5
      - uses: actions/setup-python@v6
        with:
          python-version: '3.x'
      - run: pip install -r requirements.txt pytest
      - run: pytest
```
Drop the `test` job entirely if the repo has no tests rather than shipping a job that never runs.

### 6. Update `README.md`
Real content: what it does, requirements, install (`pip install -r requirements.txt`), how to run it, examples. Note prominently if the project is a learning archive not meant for production.

### 7. Add `AGENTS.md`
**Repo-facing content only** — never put machine-specific notes (Steam Deck, `~/.venv/ruff`, missing uvx/pipx) into committed docs; that context lives in the global `~/.claude/CLAUDE.md`. Keep it short and scannable: commands first, minimal prose.
Create `AGENTS.md` (not `CLAUDE.md`) with:
- Project purpose (one paragraph)
- How to set up a venv and run it
- Lint/test commands
- Anything quirky (old APIs it talks to, config files it expects)

### 8. Commit, push, open PR
- Branch name: `update-repo`
- Commit message: summarise what changed and why
- PR title: `Modernize: <repo-name>`
- PR body: bullet list of changes made

### 9. Monitor CI and fix failures
```bash
RUN=$(gh run list --branch update-repo --json databaseId --limit 1 --jq '.[0].databaseId')
gh run watch $RUN
gh run view $RUN --json jobs --jq '.jobs[] | "\(.name): \(.conclusion)"'
```
If a job fails: `gh run view --log-failed $RUN | tail -60`, fix locally, push, watch the next run.

---

## Notes
- **Forks**: `chatterbot-voice` and `GitHarvester` are forks (`gh repo view jahrik/<repo> --json isFork`) — skip them like `inaturalist`
- **Local ruff**: no `uvx`/`pipx` on the Steam Deck — use `~/.venv/ruff/bin/ruff` (create with `python3 -m venv ~/.venv/ruff && ~/.venv/ruff/bin/pip install ruff` if missing)
- These repos use `master` as the default branch — set the CI `branches:` triggers to `master`, not `main`
- Add a `.gitignore` (`__pycache__/`, `*.pyc`, `venv/`) before `git add -A` — running `py_compile` creates pycache that otherwise lands in the commit
- For repos whose dependency stack is dead beyond repair (e.g. `microblog`: Flask-OpenID against shut-down OpenID 2.0 providers, sqlalchemy-migrate, nose), keep them as **frozen archives**: py3 syntax + modern import names + lint/compile CI only, README explaining why it doesn't run — don't resurrect deps or rewrite. Exclude generated code (migration repos) from ruff instead of editing it.
- These repos predate type hints and modern packaging — don't add either unless trivial; the bar is "works on current Python, lints clean, documented"
- Some talk to external services that may be dead (e.g. old APIs in GitHarvester, chatterbot upstream is unmaintained) — note that in the README instead of trying to fix it
- Repos that are pure exercise collections (`checkio`, `linuxacademy-python`) only need: py3 syntax, ruff, README, AGENTS.md — no CI test job
