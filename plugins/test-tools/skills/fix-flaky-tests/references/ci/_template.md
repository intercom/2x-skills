# CI Provider: <NAME> — TEMPLATE

Copy this file to `references/ci/<provider>.md` to add support for a new CI provider, then
register its detection signal in `references/discovery.md`. The job of a CI file is to
answer one question: **how do I get the real error message, seed/order, and failing-test
list for a specific failing job?** Everything in `SKILL.md`'s HARD GATE depends on it.

## Fetching the error

The exact tools/commands/API for this provider. Examples:
- CircleCI: `get_build_failure_logs` / `get_job_test_results` MCP tools, or the CircleCI API
- GitHub Actions: `gh run view <run-id> --log-failed`, `gh run download`, the Checks API

Parse out: exception/error message + stack trace, total failed-test count, distinct files
affected, and the random seed/order if the framework randomizes.

## Provider-specific gotchas

Anything that makes log retrieval non-obvious — log retention windows, retried/rerun jobs
attaching logs to a new run, matrix jobs splitting output, artifact-only test reports, etc.

## If logs are unavailable

The HARD GATE still applies. If logs can't be retrieved (auth, retention, API down), ask
the user to paste the exception and backtrace verbatim. A user-pasted error is equivalent
for the gate. Code-only analysis is never a substitute.

## A/B verification constraints

Whether this provider cancels superseded builds on a branch (which forces baseline and
experiment onto separate branches), concurrency limits, and how to trigger N runs for
measurement-driven verification (`references/ci-only-flakes.md`).

## Listing default-branch builds

How to list recent runs on the default branch to establish whether a failure pre-exists a
PR (`references/handling-unrelated-ci-failures.md`).
