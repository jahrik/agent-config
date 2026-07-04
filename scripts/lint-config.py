#!/usr/bin/env python3
"""Lint the agent-config repo for internal consistency.

This config's whole value is consistency, so the conventions it documents are
enforced here mechanically rather than by vigilance. Checks:

  - every skill's frontmatter `name:` matches its directory slug
  - every agent's frontmatter `name:` matches its filename slug
  - every skill and agent has a non-empty `description:`
  - every skill is registered in AGENTS.md and README.md
  - every agent is registered in AGENTS.md and agents/README.md
  - every SKILL.md fits the on-invoke context budget (warn > ~2KB, fail > 2.5KB;
    `references/` and `scripts/` are exempt — they load on demand)
  - every `references/...` / `scripts/...` path a skill mentions actually exists

Structural problems are fatal (exit 1). An over-budget `description:` is a soft
"~25 words" target, so it is reported as a warning and does not fail CI.

Run: python3 scripts/lint-config.py   (exits non-zero on any structural problem)
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SKILLS = REPO / "skills"
AGENTS = REPO / "agents"
DESCRIPTION_WORD_TARGET = 25  # routing-trigger budget; soft, warning-only
SKILL_SIZE_TARGET = 2048  # bytes; ~500 tokens — the working budget (warning)
SKILL_SIZE_MAX = 2560  # bytes; hard ceiling (error) — move detail to references/
SKILL_PATH_RE = re.compile(r"\b((?:references|scripts)/[\w.-]+)")

errors: list[str] = []
warnings: list[str] = []


def err(msg: str) -> None:
    errors.append(msg)


def warn(msg: str) -> None:
    warnings.append(msg)


def parse_frontmatter(path: Path) -> dict[str, str]:
    """Return the top-level scalar keys of a leading `---` YAML block.

    Deliberately tiny (no yaml dependency): good enough for `name`/`description`.
    """
    text = path.read_text(encoding="utf-8")
    if not text.startswith("---"):
        return {}
    end = text.find("\n---", 3)
    if end == -1:
        return {}
    block = text[3:end]
    fields: dict[str, str] = {}
    for line in block.splitlines():
        if line[:1] in (" ", "\t") or ":" not in line:
            continue  # skip nested/continuation lines
        key, _, value = line.partition(":")
        fields[key.strip()] = value.strip()
    return fields


def check_description(label: str, fields: dict[str, str]) -> None:
    desc = fields.get("description", "")
    if not desc:
        err(f"{label}: missing or empty `description:`")
        return
    words = len(desc.split())
    if words > DESCRIPTION_WORD_TARGET:
        warn(f"{label}: description is {words} words (target ~{DESCRIPTION_WORD_TARGET}); consider tightening")


def main() -> int:
    agents_md = (REPO / "AGENTS.md").read_text(encoding="utf-8")
    root_readme = (REPO / "README.md").read_text(encoding="utf-8")
    agents_readme = (AGENTS / "README.md").read_text(encoding="utf-8")

    # --- Skills ---
    for skill_md in sorted(SKILLS.glob("*/SKILL.md")):
        slug = skill_md.parent.name
        label = f"skills/{slug}"
        fields = parse_frontmatter(skill_md)
        if not fields:
            err(f"{label}: SKILL.md has no frontmatter block")
            continue
        if fields.get("name") != slug:
            err(f"{label}: frontmatter name={fields.get('name')!r} != directory {slug!r}")
        check_description(label, fields)
        if f"skills/{slug}/" not in agents_md:
            err(f"{label}: not registered in AGENTS.md Skills list (`skills/{slug}/`)")
        if f"{slug}/" not in root_readme:
            err(f"{label}: not registered in README.md structure block")

        # On-invoke context budget: SKILL.md loads whole; references/scripts don't.
        size = skill_md.stat().st_size
        if size > SKILL_SIZE_MAX:
            err(f"{label}: SKILL.md is {size} bytes (max {SKILL_SIZE_MAX}); move detail to references/")
        elif size > SKILL_SIZE_TARGET:
            warn(f"{label}: SKILL.md is {size} bytes (target ≤{SKILL_SIZE_TARGET}); consider trimming")

        # Every references/... or scripts/... path mentioned must exist.
        for doc in [skill_md, *sorted(skill_md.parent.glob("references/*.md"))]:
            for ref in set(SKILL_PATH_RE.findall(doc.read_text(encoding="utf-8"))):
                if not (skill_md.parent / ref).is_file():
                    err(f"{label}: {doc.name} links {ref!r} but the file does not exist")

    # --- Agents ---
    for agent_md in sorted(AGENTS.glob("*.md")):
        if agent_md.name == "README.md":
            continue
        slug = agent_md.stem
        label = f"agents/{slug}"
        fields = parse_frontmatter(agent_md)
        if not fields:
            err(f"{label}: has no frontmatter block")
            continue
        if fields.get("name") != slug:
            err(f"{label}: frontmatter name={fields.get('name')!r} != filename {slug!r}")
        check_description(label, fields)
        if f"`{slug}`" not in agents_md:
            err(f"{label}: not registered in AGENTS.md Agents table")
        if f"`{slug}`" not in agents_readme:
            err(f"{label}: not registered in agents/README.md table")

    if warnings:
        print(f"lint-config: {len(warnings)} warning(s):", file=sys.stderr)
        for w in warnings:
            print(f"  - {w}", file=sys.stderr)
    if errors:
        print(f"\nlint-config: {len(errors)} problem(s) found:", file=sys.stderr)
        for e in errors:
            print(f"  - {e}", file=sys.stderr)
        return 1
    print("lint-config: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
