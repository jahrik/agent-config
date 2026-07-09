# Agent Harness Regression Checklist

A manual, canonical dogfood checklist. Run these 5 tasks after major changes to the harness (skills, MCP servers, or agent personas) to verify end-to-end functionality.

## 1. Ansible Skill & Environment

- **Prompt:** "Check the `ansible-arch-workstation` role for any linting errors and fix them."
- **Expected Pass:** The agent successfully activates the `ansible` skill, runs `uv run ansible-lint` via the `mtest` / `uv` environment, and correctly interprets the results.
- **Guards Against:** Breakage in the `ansible` skill routing, Python/uv environment path loss, or local tooling execution failures.

## 2. GitHub MCP Workflow

- **Prompt:** "Create a new branch named `test-pr-workflow`, create an empty commit, and open a PR with the title 'test: GitHub Workflow' on `jahrik/mcp-servers`."
- **Expected Pass:** The agent uses `github-workflow` skill conventions. It must use the `gh_*` tools (e.g. `gh_pr_create`) from the `mcp-github` server instead of the `gh` CLI.
- **Guards Against:** The `github-workflow` skill failing to activate, regression of the `gh` CLI denial policy, or `mcp-github` authentication/tool failures.

## 3. Data Server (DuckDB)

- **Prompt:** "Using the data server, run a duckdb query to count the total number of tools available in the `mcp-servers` directory's JSON schemas."
- **Expected Pass:** The agent delegates to the `data` MCP server using `duckdb_query` to scan/parse JSON files instead of writing a local Python script or using `rg`/`jq` loops.
- **Guards Against:** The `data` MCP server being offline, DuckDB extension load failures, or agents reverting to improvised data-wrangling pipelines.

## 4. Memory Round-Trip

- **Prompt:** "Remember that my favorite test keyword is 'immutable-marshmallow'. Then recall my favorite test keyword."
- **Expected Pass:** The agent calls the `remember` tool on the `memory` MCP server, then successfully calls `recall` and finds the fact.
- **Guards Against:** The `memory` MCP server failing to load, DuckDB lock contention on `memory.db`, or the `fts` extension failing to index.

## 5. LSP Navigation

- **Prompt:** "Use the LSP server to find the definition of the `JobStatus` enum in the `dispatcher` server, and list its references."
- **Expected Pass:** The agent uses `lsp_definition` and `lsp_references` from the `lsp` MCP server, rather than falling back to `rg`.
- **Guards Against:** The `lsp` MCP server initialization failures, language-server process crashes (pyright/ruff), or workspace root resolution errors.
