---
name: python
description: Python project conventions — uv, ruff lint/format, ty type checking, pytest, pre-commit, and CI. Use when writing or updating a Python project, its dependencies, tests, or its lint/CI setup.
---

# Python Skill

## Conventions

- **Packaging & deps:** `uv` (`pyproject.toml` + committed `uv.lock`); per-project `.venv/`;
  `src/` layout with `tests/` mirroring it.
- **Format & lint:** `ruff` — config in `[tool.ruff]` in `pyproject.toml`, not separate dotfiles.
- **Type checking:** `ty` (Astral) — hints expected on library code, looser for one-off scripts.
- **Testing:** `pytest`, fixtures over setup/teardown classes. **No test reaches the network or a
  live external service** — mock `subprocess`, HTTP clients, and any API calls (`pytest-mock`,
  `monkeypatch`) so the suite is hermetic. Honor any coverage bar the repo already sets.
- **Local gate:** `pre-commit` runs the same checks CI does (ruff lint+format, ty, secret scans);
  install once per clone with `uv run pre-commit install`.
- **Python:** 3.11+ supported; repos currently target 3.13.

## Common commands

```bash
uv init / uv sync / uv add <pkg> / uv add --dev <pkg>
uv run ruff format . && uv run ruff check .   # add --fix to auto-fix
uv run ty check
uv run pytest
uvx pre-commit run --all-files                # every gate, as CI would
```

## CI

GitHub Actions with `astral-sh/setup-uv`, running the same gates on push/PR: `ruff check`,
`ty check`, `pytest`. CI and pre-commit run identical commands — green locally means green in CI.
Publishing specifics (`uv build`/`publish`/`tool install`) belong in each repo's `AGENTS.md`, not
this portable base.
