# Generic Flaky-Test Classification

Framework-agnostic categories. Every flaky test falls into one of these classes regardless
of language or runner. Use this table first, then consult the matching
`references/frameworks/<framework>.md` for how the category manifests in that framework's
idioms, and `references/profiles/<app>.md` for product-specific instances.

| Category | Signals (language-agnostic) | Fix direction |
|----------|------------------------------|---------------|
| **Actually broken (not flaky)** | All tests in a file fail. Deterministic on every run, any seed/order. Started after a specific commit. | Find the breaking commit; fix the new dependency or revert. Not a flake. |
| **Global state poisoning** | Order/seed-dependent. Passes in isolation. A sibling test mutates process-global state (class/module variable, thread-local, singleton, env var, global registry) and doesn't restore it. | Fix the poisoner's cleanup (restore default in teardown/ensure). Harden the victim with explicit setup as defense-in-depth. |
| **Test-ordering dependency** | Shared database/fixture state leaks between tests; suite-level setup (`before(:all)`, module-scoped fixtures) has side effects. | Isolate per-test setup/teardown. Avoid suite-scoped mutable state. |
| **Timing / race condition** | Wall-clock or time-window assertions without a frozen clock; async expectations without synchronization; polling with too-short waits. | Freeze/inject time; await the condition explicitly; widen synchronization, not sleeps. |
| **Shared-singleton collision** | A test double or factory uses a hardcoded key into a process-wide store (in-memory client, cache, registry). Parallel tests overwrite each other's data. | Use a unique key per instance (UUID/random suffix). |
| **Suffix / identifier collision under parallelism** | Wrong record found. Identifier built from a low-resolution source (second-precision timestamp, small random range) collides across many parallel workers. | Append high-entropy uniqueness (e.g. a random hex suffix). Never rely on second-precision timestamps or tiny random ranges for cross-worker uniqueness. |
| **Cache TTL expiration** | Test writes to a real cache with a short TTL; under load the entry expires before the code reads it. | Lengthen the TTL for the test context, or use an in-memory fake. |
| **Resource exhaustion / infrastructure** | OOM kills, connection-pool exhaustion, datastore-cluster pressure. **Build-wide pattern** — many unrelated tests fail in the same run. | Investigate infrastructure, not the test. Do NOT skip. See the infra fast-exit in `SKILL.md`. |
| **External-service flake** | Network timeouts, third-party API errors in CI; passes locally where the service is mocked or reachable. | Improve mocking/isolation so the test doesn't depend on a live external call. |
| **Non-deterministic ordering of results** | Positional assertions (`result[0]`) fail because the underlying query/collection has no defined order. | Assert by membership/match, not position; or impose an explicit order. |
| **Assertion expectation set in setup** | ALL tests in a group fail with "expected to receive X but didn't" — a strict expectation in shared setup masks the real error. | Use a permissive stub for isolation in setup; reserve strict expectations for the test body. |
| **Thread-boundary state** | A test runs production code in a separate thread/process (browser driver, background worker) that reads state the test set on a different thread; cleanup on the test thread doesn't reach it. | Stub at a boundary that crosses the thread (e.g. instance-level on the model the other thread loads), not the test-thread-local cache. |
| **Background-thread / async DB race** | Failures in tests that *follow* a test whose code spawns a background thread touching the database; the thread races the test-transaction rollback. | Stub the method that spawns the background work so nothing touches the DB after the test ends. |

## Quick heuristics

- Passes on retry within the same run → test-side issue (state, ordering, timing), not infra-on-its-own.
- All tests in a file fail every run, any order → broken by a code change, not flaky.
- Many unrelated files fail in one run → infrastructure; take the fast-exit.

## Adding a category

If a root cause doesn't fit any row, add it here only if it's genuinely
framework-agnostic. Framework-specific mechanics belong in the framework file;
product-specific instances belong in the app profile.
