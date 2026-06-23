---
name: load-sdlc-agents
description: Load SDLC personas into Antigravity by reading agents/*.md and calling define_subagent. Use when starting a complex task requiring SDLC subagents.
---

# Load SDLC Agents Skill

The `agent-config` repository defines SDLC personas (like `architect`, `devlead`, `qa`) in the `agents/` directory as markdown files. While Claude Code auto-loads these, Antigravity requires them to be explicitly defined via the `define_subagent` tool.

When the user asks to load the SDLC agents, or you are starting a complex task that would benefit from specialized subagents, follow these steps:

1. Use `list_dir` to find all markdown files in the `agents/` directory of the `agent-config` repository.
2. For each persona (e.g., `architect.md`, `devlead.md`):
   - Use `view_file` to read the persona's content.
   - Extract the `description:` from the YAML frontmatter.
   - Use the remaining markdown body as the `system_prompt`.
   - Call the `define_subagent` tool with the extracted `name`, `description`, and `system_prompt`. Enable read and subagent tools by default. Enable write tools if the persona is meant to implement code (like `devlead` or `infraeng`), but leave write tools disabled for read-only personas (like `devrev`, `qa`, `secrev`).

Once defined, these subagents will be available for you to `invoke_subagent` for the duration of the conversation.
