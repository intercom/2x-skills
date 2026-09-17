# Changelog

All notable changes to the `test-tools` plugin are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-09-17

### Changed

- `fix-flaky-tests` — no longer asks for a local test run. A local pass says nothing about a flake that only happens on CI, so ordering and state-poisoning flakes are diagnosed from the failing shard's test list in the CI log instead.
- An invocation with no user to ask for the CI error now aborts with a fixed message rather than producing a diagnosis, a PR, or an issue comment from code reading alone.
- Wrong-value flakes are attributed to shared state, ordering, and wall-clock timing rather than to load or parallelism, which only ever produce timeouts and out-of-memory kills.

## [0.1.0] - 2026-07-09

### Added

- Initial release of the `test-tools` plugin.
- `fix-flaky-tests` skill — investigates and fixes flaky or intermittently-failing tests across frameworks (RSpec, Jest, pytest, Go test, …) and CI systems (Buildkite, CircleCI, GitHub Actions, …), with progressive discovery, a framework-agnostic classification model, and CI-as-the-only-verification discipline.
- A `UserPromptSubmit` hook that auto-loads the skill on flaky-test phrasing the description alone would miss (advisory questions, disputed issue closures).
