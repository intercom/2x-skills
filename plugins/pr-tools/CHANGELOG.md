# Changelog

All notable changes to the `pr-tools` plugin are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-09-17

### Added

- `attach-github-assets` — `--post-to <pr|issue>:<number>` posts one comment with all the files attached, using `gh`'s native `--attach` where available and uploading and composing the body itself where it is not. Ships a bats suite covering both paths.
- `create-pr` — a hard length budget for the description, a plain-words requirement with worked good and bad examples, a rule keeping reviewer-directed rationale out of the body (a decision made during the work is not a request to publish it), and a single-attribution-line rule.

### Fixed

- `create-pr` — `check-pr-context.sh` now names the repo when asking `gh` for visibility and the default branch, and falls back to the local clone's `origin/HEAD` before assuming `main`.

## [0.1.0] - 2026-07-07

### Added

- Initial release of the `pr-tools` plugin.
- `create-pr` skill — opens or updates a well-formed GitHub pull request for the current branch, with intent-gathering, diff validation, and public-repo safeguards.
- `attach-github-assets` skill — uploads local screenshots and recordings to GitHub and returns markdown-ready URLs.
