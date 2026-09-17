# Changelog

All notable changes to the `claude-code-tools` plugin are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.1] - 2026-09-17

### Changed

- `cc-cost-analysis` — new `references/command-attribution.md` for separating genuine command-level waste from wasteful commands that ride along with real work, plus caveats on weighting tokens per model, treating self-reported cost fields as estimates, cache TTL after an idle gap, excluding automated eval traffic, and estimating compaction cost from a call's token signature.

## [0.2.0] - 2026-09-17

### Added

- `audit-memory` skill — verifies saved memories against current code, PRs and tickets, then archives the stale ones with your approval. Never auto-fires; snapshots every file before any write, and treats an unverifiable claim as `NEEDS-<tool>` rather than stale.

## [0.1.0] - 2026-07-09

### Added

- Initial release of the `claude-code-tools` plugin.
- `permissions-analyzer` skill — vets a Claude Code permission allowlist against a GREEN/YELLOW/RED safety model and merges the safe entries into `~/.claude/settings.json`.
- `tool-misses` skill — scans recent sessions for `command not found` and BSD/GNU incompatibilities, installs missing tools via Homebrew, and records availability in CLAUDE.md.
- `cc-cost-analysis` skill — a framework and query shapes for analyzing Claude Code usage costs from OpenTelemetry data.
- Hooks: proactive nudges toward `permissions-analyzer` (after repeated permission prompts) and `tool-misses` (on a detected toolchain failure), both opt-out.
