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
- **[security-tools](./plugins/security-tools/)** — Harden GitHub Actions workflows against supply-chain and injection attacks. Includes the `secure-github-actions` skill (a 14-rule review checklist plus audit commands) and a hook that auto-loads it when you edit a workflow file.

## License

MIT
