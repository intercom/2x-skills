# skills

A collection of Claude skills we think are generic enough to be useful to everyone.

## Skills

- **[skill-review](./skill-review/)** — Review Claude Code skills against substantive quality standards: a closed 7-category rubric (Structural Discipline, Integrity, Test Coverage, Security, Content Quality, Convention, Cost) with structured JSON output and a determinism contract. Complements Anthropic's `plugin-dev:skill-reviewer` (which covers structural checks) by focusing on whether a skill gives Claude the right kind of content, has appropriate test coverage, and is shaped and placed well.

## Using a skill

Each skill is a self-contained directory with a `SKILL.md` entrypoint. Drop it into `~/.claude/skills/` (personal), a repo's `.claude/skills/` (project-local), or a plugin, and Claude Code will pick it up.
