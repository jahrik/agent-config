---
name: python-skill
description: Python project conventions, tooling, and CI patterns

---

# Python Skill

## Conventions

- **Formatting:** Black
- **Linting:** ruff (`ruff check .`, `ruff format .`)
- **Type hints:** preferred, not required for scripts
- **Python version:** 3.11+ preferred
- **Venvs:** per-project at `.venv/` or `~/venv/<project>`

## Project Structure

```
src/              # or top-level package
tests/
pyproject.toml    # preferred over setup.py
requirements.txt  # pinned deps for deployment
requirements-dev.txt
.github/workflows/
README.md
AGENTS.md
```

## Common Commands

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
ruff check .
ruff format .
python -m pytest
```

## CI Pattern

GitHub Actions with `ruff` lint + `pytest` on push to `main`.

## Notable Projects

- **`edward`** — ChatterBot-based Reddit/Twitter/Gitter bot, deployed via Docker Compose
- **`flask_wishlist`** / **`microblog`** — Flask web apps (`python app.py`)
- **`checkio`** / **`linuxacademy-python`** — Practice/learning repos
