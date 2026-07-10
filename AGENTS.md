# AGENTS.md — Global AI Agent Configuration

Loaded into every session of every agent — Claude Code (as `~/.claude/CLAUDE.md`) and
AGY/Antigravity (as `~/.gemini/config/AGENTS.md`), deployed by the `ansible-ai-agents` role.
Everything here is paid for on every conversation, so the admission test is: _must this be known
before the first tool call of an arbitrary session?_ Policy and pointers only — details live in
skills, per-repo docs, and tool schemas, loaded on demand.

---

## Hard Rules — Always Follow

1. **Never write secrets, API keys, tokens, passwords, or credentials into any file.** Use a
   secrets manager or environment variables instead (the `hooks/guard-write.sh` PreToolUse hook
   backs this).
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

- **Search:** `rg` over grep/find loops; `fd` for finding files; `tokei` for instant repo
  language/size stats.
- **Code navigation (semantic):** the `lsp_*` MCP tools (`lsp` server, language-server-backed)
  are the IDE-grade path — reach for them over `rg` whenever the question is about
  _meaning_ rather than text: go-to-definition (`lsp_definition`), find-references
  (`lsp_references`), call hierarchy (`lsp_call_hierarchy`), type/implementation
  (`lsp_type_definition`/`lsp_implementation`), symbol search (`lsp_workspace_symbols`),
  diagnostics (`lsp_diagnostics`), and rename refactors (`lsp_rename`, over `sd`/`sed`). They
  resolve imports and scope, so they exclude same-named text and catch uses `rg` misses. Split:
  `rg` = text/pattern, the `lsp` server's tree-sitter tools (`ts_query`/`ts_extract`) = syntax
  structure, `lsp_*` = what a symbol _means_ and connects to. Pass absolute paths. Before `rg`-ing
  a bare symbol name to find where it is defined or used, call `lsp_definition`/`lsp_references`
  instead; drop to `rg` only for text that is not a symbol (log strings, comments, config keys).
- **Data wrangling:** `jq` (JSON), `yq` (YAML), `gron` to flatten JSON into greppable lines when
  the structure is unknown.
- **Large data & API payloads:** the `data` MCP server (`duckdb_*` tools) — run SQL in place over
  big files, logs, CSV/JSON/JSONL/Parquet instead of reading them into context. For large API
  responses (e.g. `gh_api_get`), let the framework dump to a file, then query it with
  `read_json_auto('…')` — bypasses the context window entirely. Before `Read`-ing a data file
  (`.csv/.json/.jsonl/.parquet/.log`), check its size; over ~50 KB reach for `duckdb_*` instead
  of `Read`. Source you need whole (code, configs) is exempt — size doesn't matter there.
- **Editing:** `sd` for bulk find/replace in scripts (saner than `sed`).
- **Lint before CI:** `shellcheck` + `shfmt` (shell), `hadolint` (Dockerfiles), `actionlint`
  (GitHub Actions workflows) — catch failures locally instead of burning a CI round-trip. Before
  committing, lint and format everything you changed; don't push and let CI find it.
- **Viewing/diffs:** `bat` for syntax-highlighted viewing; `delta` for readable git diffs.
- **GitHub:** the `mcp-github` tools only (Hard Rule 7) — never the `gh` CLI.
- **Workspace state:** the `ws_*` MCP tools (read-only `mcp-workspace` server) over ad-hoc
  git/ls loops — `ws_status` (`attention_only: true`) first, `ws_branches` for cleanup
  questions, `ws_repo` for one repo. Cleanup is a separate, deliberate action.
- **Workspace sync:** `repo-sync` for cross-repo clone/pull/status.
- **Async delegation:** the `dispatcher` MCP server to spawn and track background agent jobs
  instead of blocking on a long sub-task.
- **Memory (`recall`):** Call at task start if the work plausibly touches prior decisions,
  preferences, or ongoing context. Do NOT use for trivial or self-contained commands.
  Treat low-relevance hits as noise to discard.
- **Idempotency:** prefer commands and patterns that can safely re-run.

Reach for a committed script (a skill's `scripts/`) before a long one-off pipeline.

---

## Repository Conventions

- Repos follow a type prefix the workflow skills key off of:
  - `ansible-<name>` — Ansible roles, tested with Molecule (Docker driver), published to Galaxy
  - `docker-<name>` — Docker images, multi-arch via buildx, published to GHCR or Docker Hub
  - `arm-<name>` — multi-arch images down to `arm/v7` (Raspberry Pi)
- CI: GitHub Actions.
