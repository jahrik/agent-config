---
name: session-stats
description: Use when analyzing Claude Code transcripts to extract tool frequencies, bash command histograms, error rates, or token usage.
---

# Session Stats

This skill provides queries to extract operational telemetry (tool usage, bash commands, error rates, context token counts) from local Claude Code transcripts (`~/.claude/projects/**/*.jsonl`).

## When to use

Run these queries when you need to understand:

- Which tools are called most frequently across sessions.
- What Bash commands are run most often.
- The overall success/failure rate of tool calls.
- How many input/output tokens and cache operations a session consumed.
- Which sessions encountered the largest context window peaks.

## How to use

The queries are provided as raw SQL in `scripts/queries.sql`. Because `duckdb_query` automatically detects the JSONL schema from Claude Code transcripts, no setup is required.

To run these queries, read `scripts/queries.sql` and pass the relevant query string to the `data` MCP server's `duckdb_query` tool.

1. **Read the queries**: Use your file reading tool to view `skills/session-stats/scripts/queries.sql`.
2. **Execute the query**: Send the exact SQL string to `duckdb_query` on the `data` server.
3. **Never `Read` transcripts directly**: Always use the provided DuckDB queries. Transcripts are massive and will flood your context window.
