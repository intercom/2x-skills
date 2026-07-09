# CI Provider: Buildkite

How to fetch the failing job's logs and the error message — the input the HARD GATE in
`SKILL.md` requires before any classification. Buildkite is the log source for repos with a
`.buildkite/` directory.

## Fetching the error

Use your Buildkite tooling of choice (the Buildkite API, a Buildkite MCP server, or the
`buildkite` CLI) to read the failing job's logs directly:

```
- find the build and the failing job (build/job lookup)
- fetch the job's log output and search it for the error message, seed, and spec/test list
```

Parse out: exception class + message + backtrace, total failed-test count, and which
unique files are affected (the count of distinct files drives the infra fast-exit in
`SKILL.md`).

## Auto-retried jobs (common gotcha)

When a job fails and is auto-retried, Buildkite attaches the logs to the **retry** job (a
new UUID). The original UUID is still listed when you fetch the build, but searching logs
on it returns "job not found" because the logs live on the retry. When that happens: fetch
the build with no job-state filter, find the retry job by name, and use its UUID to fetch
logs.

## If logs are unavailable

API not connected, timing out, logs expired, or the log search returns nothing useful — ask
the user to paste the error verbatim:

> I couldn't get the CI error from Buildkite (reason: …). Can you paste the exception and
> backtrace from the failing job, or check that Buildkite access is configured so I can
> fetch it?

A user-pasted error is equivalent to a Buildkite-fetched one for the HARD GATE. Do not
retry failing Buildkite calls more than twice in a session. Code-only analysis is never an
acceptable substitute.

## `cancel_running_branch_builds` limitation (affects A/B verification)

Buildkite's `cancel_running_branch_builds` setting kills all but the latest build on a
branch. Consequences for measurement-driven verification (`references/ci-only-flakes.md`):

- A "with fix" and "without fix" build cannot run simultaneously on the **same** branch.
- Pushing a new commit while a build runs kills the previous build.
- Comparing two variants **requires separate branches**, each kept untouched while builds run.

## Listing default-branch builds (for unrelated-failure triage)

To establish whether a failure pre-exists your PR, list recent builds on the default
branch (filtering by that branch name) and check whether the same test is failing there.
See `references/handling-unrelated-ci-failures.md`.
