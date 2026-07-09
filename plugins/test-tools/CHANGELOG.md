# Changelog

All notable changes to the `test-tools` plugin are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-07-09

### Added

- Initial release of the `test-tools` plugin.
- `fix-flaky-tests` skill — investigates and fixes flaky or intermittently-failing tests across frameworks (RSpec, Jest, pytest, Go test, …) and CI systems (Buildkite, CircleCI, GitHub Actions, …), with progressive discovery, a framework-agnostic classification model, and CI-as-the-only-verification discipline.
- A `UserPromptSubmit` hook that auto-loads the skill on flaky-test phrasing the description alone would miss (advisory questions, disputed issue closures).
