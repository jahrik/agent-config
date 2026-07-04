# Authoring details

## Subagent template (`agents/<slug>.md`)

```markdown
---
name: <slug>
description: Use to <when to dispatch this agent — used for routing>
tools: Read, Grep, Glob, Bash # omit to inherit all; scope reviewers read-only
model: sonnet # opus for heavy reasoning (architect, reviewer); omit to inherit
---

You are <role>. <One-line charter.>

**Distinct from:**

- `<neighbor>` — <what it does> (what you do instead)

## Scope

## Mindset

## Principles

## Does NOT

## Escalate

- **<target agent or human maintainer>** — <the trigger condition>.
```

- `description` says _when to use it_ (that's how the orchestrator picks). Agents that should
  fire automatically (reviewers, testers) start it with **"Use proactively …"**.
- **Distinct from:** disambiguate against the 2–3 overlapping agents — one line each, "they do X;
  you do Y". Highest-leverage routing aid; keep it tight.
- **Escalate** is a list of `target → trigger` pairs, not prose — it encodes the handoff graph.
- **`model`**: `opus` for heavy-reasoning/high-stakes (architect, reviewer), `sonnet` for the rest;
  omit to inherit the session model.
- Review-only agents (`reviewer`, `qa`) get read-only tools — no `Edit`/`Write`.
- Body ≤ ~150 lines — a focused system prompt, not a manual.

## Context budget

| File                            | Loaded               | Target                                                   |
| ------------------------------- | -------------------- | -------------------------------------------------------- |
| `AGENTS.md` (global + project)  | every turn           | ≤ ~200 lines / ~2k tokens                                |
| skill / subagent `description:` | every turn (routing) | one line, ≤ ~25 words                                    |
| skill body (`SKILL.md`)         | on invoke            | ≤ ~2KB (detail → `references/`, procedures → `scripts/`) |
| subagent body                   | on spawn             | ≤ ~150 lines                                             |

## Deployment (how it reaches each tool)

The `ansible-ai-agents` role symlinks from `~/.config/agents/` (the clone of this repo):

| Source      | → Destination                | Tool                 |
| ----------- | ---------------------------- | -------------------- |
| `AGENTS.md` | `~/.claude/CLAUDE.md`        | Claude Code (global) |
| `skills/`   | `~/.claude/skills`           | Claude Code          |
| `agents/`   | `~/.claude/agents`           | Claude Code          |
| `AGENTS.md` | `~/.gemini/config/AGENTS.md` | AGY/Antigravity      |
| `skills/`   | `~/.gemini/config/skills`    | AGY/Antigravity      |

Subagents are a Claude Code feature; other tools don't read `~/.claude/agents/`. The _content_ is
portable — shared rules belong in `AGENTS.md`, which AGY reads too.

## Where environment specifics go

Tooling and local-desktop detail (local wrappers, container-runtime shims, host paths, OS quirks,
publishing secrets) belongs in **each repo's own `AGENTS.md` / `README.md`**, never in the agents,
skills, or global `AGENTS.md` — those stay portable so a fork reuses them unchanged. Truly
machine-local notes go in a private file outside this shared config. When a skill or agent needs
that context, it refers to "the project's environment (`AGENTS.md`)" generically.
