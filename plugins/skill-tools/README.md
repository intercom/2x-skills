# skill-tools

Tools for authoring and reviewing Claude Code skills.

Part of the [`fin-2x`](../../README.md) marketplace.

## Install

```
/plugin marketplace add intercom/2x-skills
/plugin install skill-tools@fin-2x
```

## Skills

- **[skill-review](./skills/skill-review/)** — Review Claude Code skills against substantive quality standards: a closed 7-category rubric (Structural Discipline, Integrity, Test Coverage, Security, Content Quality, Convention, Cost) with structured JSON output and a determinism contract. Complements Anthropic's `plugin-dev:skill-reviewer` (which covers structural checks) by focusing on whether a skill gives Claude the right kind of content, has appropriate test coverage, and is shaped and placed well.

## License

MIT
