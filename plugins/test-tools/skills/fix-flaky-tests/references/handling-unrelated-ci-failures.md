# Handling Unrelated CI Failures on Fix PRs

A fix PR may fail CI on a **completely unrelated test** that is broken on the default
branch. This is common — a broad change (e.g. editing a shared test helper) can widen the
set of tests that run, raising the chance of hitting a pre-existing breakage. Some apps
have test-selection systems that normally run a subset; a shared-helper edit can force a
full run. (For app-specific selection behaviour, see your app profile, e.g.
`references/profiles/your-app.md`.)

## Establishing that the failure is unrelated

The failure is unrelated when the failing test has no edit-graph or data-graph connection to
your change, and the same failure appears on recent default-branch builds. Check this by
reading the failing test, comparing it to your diff, then listing recent default-branch
builds (via the CI provider file, e.g. `references/ci/buildkite.md`) — if the default branch
is also failing on the same test, or `git log --oneline --since="1 week ago" -- <failing_test_file>`
shows churn matching a known fix-in-flight, the breakage pre-exists your PR.

Once established as unrelated, **do not modify the unrelated failing test in your fix PR** —
that dilutes the review and creates an artificial dependency. Resolve it by moving your
branch forward or by retrying, based on the state of the default branch:

| Default-branch state for the failing test | Action |
|--------------------------------------------|--------|
| Fix already merged | Rebase onto the latest default branch and force-push: `git fetch origin <default> && git rebase origin/<default> && git push --force-with-lease` |
| Still broken | Retry the build — the broken test may land in a different shard/bin on retry and pass. If it keeps failing, wait for the upstream fix to land, then rebase. |

If the failure turns out to be related to your change after all (the backtrace touches code
you edited, or the test exercises a path you modified), it is not "unrelated" — treat it
like any other flaky-test investigation and fix it in your PR.
