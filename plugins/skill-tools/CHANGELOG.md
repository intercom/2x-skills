# Changelog

All notable changes to the `skill-tools` plugin are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-09-17

### Added

- `skill-review` — a Hooks category (`references/hooks.md`) that judges whether a hook shipped with a skill is justified at all, using a deterministic-gate test, and whether it is well built: narrow matcher, cheap short-circuit, correct block convention, no heavy synchronous work, no duplication. The rubric is now eight categories.
- New finding types: a discipline rule written in a form too soft to hold, a description that inlines workflow steps, a guardrail eval that only exercises the compliant path, trigger evals on a skill that cannot auto-fire, `disable-model-invocation` breaking a scheduled skill, a retired model ID or superseded API parameter, and four instruction anti-patterns that cost tokens on a frontier model without changing behaviour.

### Changed

- A missing Response Style section is no longer a Cost finding — output style comes from the harness and user settings, not from each skill restating it.
- `no-op-instruction`'s fix now points at a checkable bar instead of suggesting a stronger-sounding word, which was itself one of the anti-patterns above.

### Fixed

- `procedure-smell-with-consequence` is now declared in the Content Quality reference, which the output contract had been citing without it existing there.

## [0.1.0] - 2026-07-02

### Added

- Initial release of the `skill-tools` plugin.
- `skill-review` skill — reviews Claude Code skills against a closed 7-category quality rubric with structured JSON output and a determinism contract.
