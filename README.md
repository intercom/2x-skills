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
- **[claude-code-tools](./plugins/claude-code-tools/)** — Meta-tools for running Claude Code well. `permissions-analyzer` vets your permission allowlist against a GREEN/YELLOW/RED safety model; `tool-misses` finds and fixes missing CLI tools / BSD-GNU incompatibilities; `cc-cost-analysis` is a framework for analyzing Claude Code usage costs from OpenTelemetry data.
- **[test-tools](./plugins/test-tools/)** — Investigate and fix flaky tests. The `fix-flaky-tests` skill detects your framework and CI provider, classifies the flake, and enforces green-CI-as-the-only-verification discipline across RSpec, Jest, pytest, Go test, and more.
- **[code-review-tools](./plugins/code-review-tools/)** — The `thermo-nuclear-code-review` skill runs an extremely strict structural and architectural review, hunting for "code judo" simplifications rather than correctness bugs or style nits.

## License

MIT
