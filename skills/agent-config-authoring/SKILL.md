---
name: agent-config-authoring
description: Conventions and steps for authoring skills, subagents, and rules in the agent-config repo — formats, context budget, where things live, plus deploy and validation. Use when creating or editing a skill, subagent, or global rule.
---

# Agent-Config Authoring

How to add or edit the three customization layers in this repo. `agent-config` is the
**single source of truth**; the `ansible-ai-agents` role symlinks it into each tool.

## Repo layout

```
agent-config/
├── AGENTS.md          # global rules — always loaded, keep lean
├── agents/            # Claude Code subagent personas (one .md each)
└── skills/            # modular skills (one dir each, with SKILL.md)
```

## Which layer? (rule vs skill vs subagent)

- **Global rule** → `AGENTS.md`. A short, universal directive that should apply to _every_
  session (e.g. "never push to main"). Always loaded — add sparingly.
- **Skill** → `skills/<name>/SKILL.md`. Reference knowledge or a repeatable procedure,
  loaded **on demand** when its `description` matches. Can be long.
- **Subagent** → `agents/<name>.md`. A persona with a defined stance and tool scope,
  spawned for a task. Claude Code only.

## Authoring a skill

Create `skills/<slug>/SKILL.md`:

```markdown
---
name: <slug>
description: <one line — what it is and WHEN to use it; this is the routing trigger>
---

# <Title>

## <Sections with the actual content>
```

- `name` matches the directory slug.
- `description` is the **only part always in context** — make it a tight trigger
  (≤ ~25 words), front-loaded with the keywords that should activate it.
- Keep the body ≤ ~500 lines; split overflow into sibling files the skill links to.

## Authoring a subagent

Create `agents/<slug>.md`:

```markdown
---
name: <slug>
description: Use to <when to dispatch this agent — used for routing>
tools: Read, Grep, Glob, Bash # omit to inherit all; scope reviewers read-only
model: sonnet # opus for heavy reasoning (architect, secrev); omit to inherit
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

- `description` says _when to use it_ (that's how the orchestrator picks). For agents that
  should fire automatically (reviewers, testers), start it with **"Use proactively …"**.
- **Distinct from:** disambiguate against the 2–3 agents this one overlaps with — one line each, framed as "they do X; you do Y". This is the highest-leverage routing aid; keep it tight.
- **Escalate** is a list of `target → trigger` pairs (bold target, then the condition), not prose — it encodes the handoff graph.
- **`model`**: route heavy-reasoning / high-stakes agents to `opus` (architect, secrev) and the rest to `sonnet`; omit to inherit the session model.
- Scope review-only agents (`devrev`, `qa`, `secrev`) to read-only tools (no `Edit`/`Write`).
- Keep the body ≤ ~150 lines — a focused system prompt, not a manual.

## Portable core vs. environment binding

The agents are meant to be a **reusable base others can fork**, so keep two layers separate:

- **Portable core (the agent body):** persona, mindset, does-not, escalation graph,
  distinct-from. Universal SDLC. **No repo names, registries, OS names, secret names, or
  skill names** — say "the project's conventions" / "the matching skill" / "the project's
  environment skill" instead.
- **Environment binding (this config's specifics):** which repos, registries, secrets, and
  OS rules. Lives in `AGENTS.md` (Owner Context / Repository Conventions) and in skills
  (notably the environment skill). A forker overrides those and leaves the agents untouched.

When you catch yourself naming a tool, registry, or path in an agent body, push it down into
a skill or `AGENTS.md` and reference it generically.

## Editing global rules (`AGENTS.md`)

- Add to **Hard Rules** only if it's universal and worth always-on cost.
- Keep `AGENTS.md` ≤ ~200 lines / ~2k tokens. Push detail down into a skill and leave a
  one-line pointer.

## Context budget

| File                            | Loaded               | Target                      |
| ------------------------------- | -------------------- | --------------------------- |
| `AGENTS.md` (global + project)  | every turn           | ≤ ~200 lines / ~2k tokens   |
| skill / subagent `description:` | every turn (routing) | one line, ≤ ~25 words       |
| skill body                      | on invoke            | ≤ ~500 lines (split beyond) |
| subagent body                   | on spawn             | ≤ ~150 lines                |

## Where SteamOS / Deck specifics go

Environment- and device-specific detail (mtest, dswarm, Podman, `holo` rules, dind swarm,
Galaxy key) lives in the **`steamdeck` skill** — never duplicated in `AGENTS.md` or in
subagent bodies. Agents reference the skill instead.

## Deployment (how it reaches each tool)

The `ansible-ai-agents` role symlinks from `~/.config/agents/` (the clone of this repo):

| Source      | → Destination                | Tool                 |
| ----------- | ---------------------------- | -------------------- |
| `AGENTS.md` | `~/.claude/CLAUDE.md`        | Claude Code (global) |
| `skills/`   | `~/.claude/skills`           | Claude Code          |
| `agents/`   | `~/.claude/agents`           | Claude Code          |
| `AGENTS.md` | `~/.gemini/config/AGENTS.md` | AGY/Antigravity      |
| `skills/`   | `~/.gemini/config/skills`    | AGY/Antigravity      |

## Validate before commit

```bash
uvx pre-commit run --all-files   # gitleaks, detect-secrets, prettier
```

Prettier reformats markdown tables — let it, then re-stage. Never commit secrets or
internal IPs (the hooks block them).

## Portability

Subagents are a Claude Code feature; other tools do not read `~/.claude/agents/`. The
_content_ is portable — shared rules belong in `AGENTS.md`, which AGY reads too.
