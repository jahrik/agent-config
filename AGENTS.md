# AGENTS.md — Global AI Agent Configuration

Loaded into every session of every agent — Claude Code (as `~/.claude/CLAUDE.md`) and
AGY/Antigravity (as `~/.gemini/config/AGENTS.md`), deployed by the `ansible-ai-agents` role.
Everything here is paid for on every conversation, so the admission test is: _must this be known
before the first tool call of an arbitrary session?_ Policy and pointers only — details live in
skills, per-repo docs, and tool schemas, loaded on demand.

---

## Hard Rules — Always Follow

1. **Never write secrets, API keys, tokens, passwords, or credentials into any file.** Use a
   secrets manager or environment variables instead.
2. **Never hardcode IP addresses or internal hostnames.** Use variables that config/templating
   fills in at deploy time.
3. **Never create a `CLAUDE.md` file.** Use `AGENTS.md` for all project-level guidance — including
   when a tool's `/init`-style command asks for `CLAUDE.md`. If `AGENTS.md` already exists, update
   it instead of adding a second guidance file.
4. **Ask before destructive operations** (delete, overwrite, drop, purge, reset).
5. **Never commit or push to `main`.** Always branch, open a PR, and let the maintainer merge —
   never `git push` to main and never auto-merge a PR.
6. **Attribute commits** with a `Co-Authored-By:` trailer for the AI model used.
7. **Never use the `gh` CLI.** GitHub operations go through the `mcp-github` MCP tools (`gh_*`);
   agents act as the GitHub App identity, `gh` is the human's own session (a permission deny rule
   and the `hooks/guard-bash.sh` PreToolUse hook back this). If a capability is missing, open an
   issue on `jahrik/mcp-servers` and hand the action to the maintainer.
8. **Report all findings.** In any sweep, survey, or review, surface everything found — never
   silently filter or suppress items. The maintainer decides what to act on.

---

## Map — Where Everything Lives

The harness is three repos:

- **[`jahrik/agent-config`](https://github.com/jahrik/agent-config)** (this repo) — this file,
  `skills/`, `agents/` personas, and `hooks/` guard scripts. Deployed by cloning to
  `~/.config/agents` and symlinking into `~/.claude/` and `~/.gemini/config/`.
- **[`jahrik/ansible-ai-agents`](https://github.com/jahrik/ansible-ai-agents)** — deploys the
  whole harness: agent CLIs, the pinned toolchain in `~/.local/bin`, this config, MCP server
  registration, and GitHub App credentials.
- **[`jahrik/mcp-servers`](https://github.com/jahrik/mcp-servers)** — the MCP servers:
  `mcp-github` (GitHub as the App identity) and `mcp-workspace` (read-only local git surveys,
  registered as `ws`).

Finding things at runtime:

- **Skills and subagent personas**: the harness lists what's available, with descriptions. When a
  skill matches the task, use it before improvising. AGY loads personas via the
  `load-sdlc-agents` skill (no native discovery).
- **Per-repo specifics**: every repo carries its own `AGENTS.md` + `README.md` — read those
  first. Language/stack conventions (including code style) live in the matching reference skill
  (`ansible`, `docker`, `go`, `python`).

---

## Tool Preferences

The deployment role installs a standard toolchain to `~/.local/bin` — prefer it over improvised
pipelines:

- **Search:** `rg` over grep/find loops; `fd` for finding files; `ast-grep` for structural
  (syntax-aware) code search; `tokei` for instant repo language/size stats.
- **Data:** `jq` (JSON), `yq` (YAML), `gron` to flatten JSON into greppable lines when the
  structure is unknown; for bulk data wrangling as it arises: `duckdb` (SQL over large
  CSV/JSON/JSONL instead of reading it), `xsv` (CSV), `htmlq` (HTML), `jc` (classic command
  output → JSON).
- **Editing:** `sd` for bulk find/replace in scripts (saner than `sed`).
- **Lint before CI:** `shellcheck` + `shfmt` (shell), `hadolint` (Dockerfiles), `actionlint`
  (GitHub Actions workflows) — catch failures locally instead of burning a CI round-trip.
- **Viewing/diffs:** `bat` for syntax-highlighted viewing; `delta` for readable git diffs.
- **GitHub:** the `mcp-github` tools only (Hard Rule 7) — never the `gh` CLI.
- **Workspace state:** the `ws_*` MCP tools (read-only `mcp-workspace` server) over ad-hoc
  git/ls loops — `ws_status` (`attention_only: true`) first, `ws_branches` for cleanup
  questions, `ws_repo` for one repo. Cleanup is a separate, deliberate action.
- **Workspace sync:** `repo-sync` for cross-repo clone/pull/status.
- **Idempotency:** prefer commands and patterns that can safely re-run.

Reach for a committed script (a skill's `scripts/`) before a long one-off pipeline.

---

## Repository Conventions

- Repos follow a type prefix the workflow skills key off of:
  - `ansible-<name>` — Ansible roles, tested with Molecule (Docker driver), published to Galaxy
  - `docker-<name>` — Docker images, multi-arch via buildx, published to GHCR or Docker Hub
  - `arm-<name>` — multi-arch images down to `arm/v7` (Raspberry Pi)
- CI: GitHub Actions.
