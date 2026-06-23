---
name: update-python-repo
description: Walk the Python project repos alphabetically and modernize each one (Python 3, ruff lint, CI, README, AGENTS.md)
---

Scan your projects directory for Python project repos — directories whose primary content is
`.py` files, `requirements.txt`, `setup.py`, or `pyproject.toml`. Hybrid repos (e.g. Python
code alongside a Dockerfile) still count. Sort alphabetically and work through each in order.
Inspect each repo's current state live — do not rely on any saved status list.

**Skip a repo** if it's not really a Python project (a couple of incidental scripts in a repo
of another type doesn't count), or if it's an archived fork of someone else's project.

**A repo needs updating** if any of the following are true:

- Python 2 syntax anywhere (`print` statements, `urllib2`, old-style `except`)
- No lint CI workflow
- No `pyproject.toml`/ruff config and code doesn't pass `ruff check`
- Dependencies in `requirements.txt` are unpinned or reference dead/renamed packages
- `AGENTS.md` is missing
- README is missing or a stub

Work through all repos in a single run. After finishing each repo, move to the next without
stopping. For old learning/demo projects the goal is "runs on a current Python and lints
clean", not a rewrite — keep changes minimal and behavior-preserving.

---

## Steps (apply to each repo in turn)

### 1. Understand the repo

Read the entry-point scripts, `requirements.txt`/`setup.py`, and `README.md`. Figure out: what
it does, how it's run, and whether it has tests.

### 2. Port to Python 3 (if needed)

- `print x` → `print(x)`, `urllib2` → `urllib.request`, `except E, e` → `except E as e`,
  `dict.iteritems()` → `.items()`, etc.
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

Review the diff — don't let autofix change behavior.

### 5. Add `.github/workflows/ci.yml`

```yaml
---
name: CI

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
      - uses: astral-sh/setup-uv@v6
        with:
          python-version: "3.x"
      - run: uvx ruff check .
      - run: uv run python -m py_compile $(git ls-files '*.py')

  test:
    name: Test
    runs-on: ubuntu-latest
    if: ${{ hashFiles('tests/**') != '' }}
    steps:
      - uses: actions/checkout@v5
      - uses: astral-sh/setup-uv@v6
        with:
          python-version: "3.x"
      - run: uv run --with-requirements requirements.txt --with pytest pytest
```

Drop the `test` job entirely if the repo has no tests rather than shipping a job that never runs.

### 6. Update `README.md`

Real content: what it does, requirements, install (`pip install -r requirements.txt`), how to
run it, examples. Note prominently if the project is a learning archive not meant for production.

### 7. Add `AGENTS.md`

**Repo-facing content only** — never put machine-specific notes (local venv paths, host tooling)
into committed docs; that context lives in the project's environment notes (`AGENTS.md` at the
config root). Keep it short and scannable: commands first, minimal prose.
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

- **Forks**: skip archived forks of other people's projects (`gh repo view <owner>/<repo> --json isFork`).
- **Default branch**: some legacy repos still use `master` — set the CI `branches:` triggers to match the repo's actual default.
- Add a `.gitignore` (`__pycache__/`, `*.pyc`, `venv/`) before `git add -A` — `py_compile` creates pycache that otherwise lands in the commit.
- For repos whose dependency stack is dead beyond repair, keep them as **frozen archives**: py3 syntax + modern import names + lint/compile CI only, with a README explaining why it doesn't run — don't resurrect deps or rewrite. Exclude generated code (e.g. migrations) from ruff instead of editing it.
- These repos predate type hints and modern packaging — don't add either unless trivial; the bar is "works on current Python, lints clean, documented".
- Some talk to external services that may be dead — note that in the README instead of trying to fix it.
- Pure exercise collections only need py3 syntax, ruff, README, AGENTS.md — no CI test job.
