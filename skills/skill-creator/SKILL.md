---
name: skill-creator
description: How to author a skill in this repo — the SKILL.md format, writing the description as the routing trigger, body structure, context budget, and verifying it activates. Use when creating or editing a skill.
---

# Skill Creator

How to add or edit a **skill** — an on-demand knowledge or procedure pack loaded when its
`description` matches the task. Make one when you keep re-explaining the same reference knowledge
or procedure. A _persona_ with a stance and tool scope is a subagent; a short universal directive
is an `AGENTS.md` rule (both: see `agent-config-authoring`).

## Format

`skills/<slug>/SKILL.md` with frontmatter `name:` (must match the directory slug) and
`description:`:

- **`SKILL.md`** — the router: when to use, core rules, key commands. **≤ ~2KB** (lint-enforced);
  it loads whole on every invoke.
- **`references/*.md`** — deep detail (templates, checklists, examples), linked from SKILL.md so
  it loads only when needed.
- **`scripts/*`** — executable steps; one reviewed script beats re-derived pipelines
  (`#!/usr/bin/env bash` + `set -euo pipefail`, or Python).

## The description is the trigger

The `description` is the **only part always in context** — it decides whether the skill loads:

- Front-load activating keywords; name the _task_, not just the topic.
- Say _when to use it_ ("Use when …"); one line, ≤ ~25 words.
- **Verify it triggers**: in a fresh session, describe the task in your own words and confirm the
  skill fires; if not, rewrite the description with the words you used — tune the trigger, not
  the body.

## Body rules

Lead with what a reader needs to _do_; commands and templates over prose. **Portable base rule:**
no account names, registries, OS, or local paths — say "the project's conventions" / "the
project's environment (`AGENTS.md`)".

## Validate and register

```bash
uvx pre-commit run --all-files   # secret scan + prettier + lint-config
```

Register the skill in `AGENTS.md` (Skills list) and the `README.md` structure block — the
`lint-config` hook fails on missing registration, a name/slug mismatch, an over-budget SKILL.md,
or a broken `references/`/`scripts/` link. Deployment: the `ansible-ai-agents` role symlinks
`skills/` into each tool.
