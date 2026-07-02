# fin-2x

A marketplace of Claude Code skills built by the Fin 2x team.

## Install

Add the marketplace, then install the plugin you want:

```
/plugin marketplace add intercom/2x-skills
/plugin install skill-tools@fin-2x
```

## Plugins

- **[skill-tools](./plugins/skill-tools/)** — Tools for authoring and reviewing Claude Code skills. Includes the `skill-review` skill, which reviews skills against a closed 7-category quality rubric (Structural Discipline, Integrity, Test Coverage, Security, Content Quality, Convention, Cost) with structured JSON output and a determinism contract.

## Repository layout

```
.claude-plugin/marketplace.json   # marketplace catalog
plugins/<plugin>/                  # one directory per plugin
  .claude-plugin/plugin.json       # plugin manifest
  skills/<skill>/SKILL.md          # skills shipped by the plugin
```

## License

MIT
