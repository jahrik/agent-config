# agent-config Improvements Plan

## Todo List

- [ ] **Tighten Skill and Agent Descriptions**
  - [ ] `skills/github-workflow` (currently 40 words)
  - [ ] `skills/agent-config-authoring` (currently 38 words)
  - [ ] `agents/architect` (currently 38 words)
  - [ ] `agents/devrev` (currently 34 words)
  - [ ] `agents/infraeng` (currently 34 words)
  - [ ] `agents/secrev` (currently 34 words)
  - [ ] `skills/skill-creator` (currently 34 words)
  - [ ] `skills/systematic-debugging` (currently 32 words)
  - [ ] `agents/qa` (currently 32 words)
  - [ ] `skills/ansible` (currently 31 words)
  - [ ] `agents/devlead` (currently 31 words)
  - [ ] `skills/update-ansible-role` (currently 29 words)
  - [ ] `agents/releng` (currently 27 words)
  - [ ] `skills/python` (currently 26 words)

- [x] **Expand Antigravity Integration (Optional)**
  - [x] Investigate creating a setup script (or an Antigravity specific skill) that automatically reads the `agents/` markdown personas.
  - [x] Have the script call `define_subagent` to natively register these SDLC personas (e.g., `qa`, `architect`) into the AGY runtime.
