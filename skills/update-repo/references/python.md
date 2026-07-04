# Python projects

Shared machinery: `common.md`. Conventions: the `python` skill.

Candidates: dirs whose primary content is `.py` files, `requirements.txt`, `setup.py`, or
`pyproject.toml`; hybrids count. Skip repos where Python is incidental, and archived forks. For
old learning/demo projects the bar is **"runs on a current Python and lints clean"** — minimal,
behavior-preserving changes, not a rewrite.

## Triage checklist

- Python 2 syntax (`print` statements, `urllib2`, `except E, e`)
- No lint CI workflow; no ruff config or `ruff check` failures
- Unpinned or dead/renamed packages in `requirements.txt`
- `AGENTS.md` missing; README missing/stub

## Steps

1. **Understand** — entry points, deps, README: what it does, how it runs, whether it has tests.
2. **Port to Python 3** — `print(x)`, `urllib.request`, `except E as e`, `.items()`, etc. Verify
   everything compiles: `python3 -m py_compile $(git ls-files '*.py')`; smoke-test any runnable
   entry point in a venv.
3. **Deps** — pin to currently-installable releases; replace dead packages with successors; drop
   Python-2-only deps. Smoke test: `python3 -m venv /tmp/venv-<repo> && .../pip install -r
requirements.txt`.
4. **Ruff** — `pyproject.toml` with `[tool.ruff]` `line-length = 100`, `target-version = "py311"`;
   `uvx ruff check --fix .` + `uvx ruff format .`; review the diff — autofix must not change
   behavior. Exclude generated code (migrations) instead of editing it.
5. **`ci.yml`** — `lint` job: checkout → `astral-sh/setup-uv` (full-version pin, `python-version:
"3.x"`) → `uvx ruff check .` → `uv run python -m py_compile $(git ls-files '*.py')`. `test` job
   (`uv run --with-requirements requirements.txt --with pytest pytest`) only if `tests/` exists —
   drop a job that never runs.
6. **README** — what it does, install, run, examples; note prominently if it's a learning archive
   not meant for production.
7. **AGENTS.md** — purpose, venv setup + run, lint/test commands, quirks (old APIs, expected
   config files).

## Notes

- **`setup-uv` versioning** — pin the full version (`@v8.1.0`-style); moving major tags don't resolve.
- **Default branch** — legacy repos may use `master`; match CI `branches:` triggers to reality.
- Add `.gitignore` (`__pycache__/`, `*.pyc`, `venv/`) before `git add -A` — `py_compile` creates
  pycache.
- **Dead-beyond-repair dep stacks → frozen archives**: py3 syntax + modern imports + lint/compile
  CI only, README explaining why it doesn't run. Dead external services: note in README, don't fix.
- No type hints or modern packaging unless trivial — these predate both.
- Pure exercise collections: py3 syntax, ruff, README, AGENTS.md — no CI test job.
