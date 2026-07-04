---
name: agent-config-authoring
description: Conventions and steps for authoring subagents and global rules in the agent-config repo — formats, context budget, the portable-vs-environment split, deploy, and validation. Use when creating or editing a subagent or a global rule. (For skills, see skill-creator.)
---

# Agent-Config Authoring

How to add or edit **subagents** and **global rules** (skills: see `skill-creator`).
`agent-config` is the single source of truth; the `ansible-ai-agents` role symlinks it into each
tool (full table: `references/authoring-details.md`).

## Which layer?

- **Global rule** → `AGENTS.md`: short, universal, worth always-on cost. File ≤ ~200 lines / ~2k
  tokens; push detail into a skill with a one-line pointer.
- **Skill** → `skills/<name>/SKILL.md`: knowledge or procedure loaded on demand by `description`
  match. ≤ ~2KB; detail in `references/`, executable steps in `scripts/`.
- **Subagent** → `agents/<slug>.md`: a persona with stance + tool scope. Claude Code only.

## Subagent essentials

Frontmatter `name`/`description`/`tools`/`model` + a focused system prompt ≤ ~150 lines with
**Distinct from / Scope / Mindset / Principles / Does NOT / Escalate** sections. `description` is
the routing trigger ("Use proactively…" for auto-fire reviewers). Reviewers get read-only tools;
`opus` only for heavy reasoning. Template + rationale: `references/authoring-details.md`.

## Portable core vs. environment binding

The config is a reusable base others fork. **No repo names, registries, OS names, secret names,
or local paths** in agents, skills, or the global `AGENTS.md` — say "the project's conventions" /
"the project's environment (`AGENTS.md`)". Environment specifics live in each repo's own
`AGENTS.md` + `README.md`.

## Validate before commit

```bash
uvx pre-commit run --all-files   # gitleaks, detect-secrets, prettier, lint-config
```

Prettier reformats markdown tables — let it, re-stage. The `lint-config` hook fails on
`name` ≠ filename/slug, missing registration in `AGENTS.md`/`README.md`, or an over-budget
SKILL.md.
