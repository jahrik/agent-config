---
name: skill-creator
description: How to author a skill in this repo — the SKILL.md format, writing the description as the routing trigger, body structure, context budget, and verifying it activates. Use when creating or editing a skill.
---

# Skill Creator

How to add or edit a **skill** — an on-demand knowledge or procedure pack that Claude loads when
its `description` matches the task. For subagents and global rules, see `agent-config-authoring`.

## When to make a skill

Make a skill when you keep re-explaining the same reference knowledge or repeatable procedure.
If it's a _persona_ with a stance and tool scope, that's a subagent. If it's a short, universal
directive, that's a rule in `AGENTS.md`.

## Format

Create `skills/<slug>/SKILL.md`:

```markdown
---
name: <slug>
description: <one line — what it is AND when to use it; this is the routing trigger>
---

# <Title>

## <Sections with the actual content>
```

- `name` matches the directory slug.
- Extra files (templates, references, scripts) can live in the skill directory; link to them from
  `SKILL.md` so they load only when needed.

## The description is the trigger

The `description` is the **only part always in context** — it's what Claude matches to decide
whether to load the skill. Treat it as the most important line:

- Front-load the keywords that should activate it; name the _task_, not just the topic.
- Say _when to use it_ ("Use when …"), not only what it is.
- One line, ≤ ~25 words.
- After writing it, **verify it triggers**: in a fresh session, describe the task in your own
  words and confirm Claude reaches for the skill. If it doesn't fire, rewrite the description with
  the words you actually used — tune the trigger, not the body.

## Body

- Lead with what a reader needs to _do_; commands and templates over prose.
- Keep it ≤ ~500 lines. If it grows past that, split detail into sibling files the `SKILL.md`
  links to, so the body stays scannable.
- **Portable base rule:** no account names, registries, OS, or local paths — say "the project's
  conventions" / "the project's environment (`AGENTS.md`)". Machine specifics live in each repo's
  `AGENTS.md`, not in the skill.

## Validate and register

```bash
uvx pre-commit run --all-files   # secret scan + prettier
```

Then register the skill in `AGENTS.md` (Skills list) and the `README.md` structure block.

## Deployment

The `ansible-ai-agents` role symlinks `skills/` into each tool (Claude Code `~/.claude/skills`,
AGY `~/.gemini/config/skills`), where it is auto-discovered by description.
