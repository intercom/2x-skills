# Changelog

All notable changes to the `security-tools` plugin are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-09-17

### Added

- `references/permission-scopes.md` — the permission-scope detail from Rule 5, with a hard trigger to load it before adding, removing, or narrowing any scope. Both failure modes it documents are silent: a clipped token scope fails inside a reusable callee while CI stays green, and a stripped `id-token: write` fails at run creation with no logs.
- A response-style section: output findings, not a walk through the rules.

### Fixed

- The Rule 1 audit command now parses the workflow YAML instead of pattern-matching lines, so it catches `${{ }}` in block-scalar and list-item `run:` steps that the old `grep`/`awk` scanner missed.
- The workflow-edit hook injects its nudge once per session instead of on every edit.

## [0.1.0] - 2026-07-07

### Added

- Initial release of the `security-tools` plugin.
- `secure-github-actions` skill — hardens GitHub Actions workflows against supply-chain and injection attacks with a 14-rule review checklist and audit commands.
