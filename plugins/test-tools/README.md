# test-tools

Investigate and fix flaky tests across frameworks and CI systems.

Part of the [`fin-2x`](../../README.md) marketplace.

## Install

```
/plugin marketplace add intercom/2x-skills
/plugin install test-tools@fin-2x
```

## Skills

- **[fix-flaky-tests](./skills/fix-flaky-tests/)** — Investigates and fixes flaky or intermittently-failing tests. Detects the test framework (RSpec, Jest, pytest, Go test, …) and CI provider (Buildkite, CircleCI, GitHub Actions, …), then applies a framework-agnostic classification model (global-state poisoning, test ordering, timing/race, resource exhaustion, external-service flake, …). Enforces hard rules: never skip a test as a "fix", never propose a fix without the actual CI error, and treat a green CI build as the only authoritative verification. Extensible via per-framework, per-CI, and per-app reference files — add your own; none ship by default beyond RSpec + Buildkite.

## Hooks

`test-tools` installs a `UserPromptSubmit` hook that auto-loads the skill for flaky-test phrasing the skill description alone would miss — advisory questions ("should I run it more locally?", "did my fix make it worse?") and disputes of a wrongly-closed flaky-test issue. Non-blocking; it only injects a context reminder.

## License

MIT
