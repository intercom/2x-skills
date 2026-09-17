# CI-Only Flakes: Local Reproduction Is Out of Bounds

Local test runs are never a sanctioned diagnostic step, for any category. What follows
explains why these categories in particular would give zero signal locally regardless, and
the CI-side techniques that replace a local run.

Many flakes never reproduce locally, but the reason is usually **not** raw resource
pressure. The conditions that actually matter: **real backing services** (a real
datastore/cache with persistent state, instead of a local stub or a clean process),
**test ordering and cross-test state** (many CIs run a large, often random-ordered batch,
so an earlier test's residue reaches a later one — check the runner model, since some CIs
isolate each test), and **wall-clock timing** (real time elapses between operations).
Genuine resource **load** is a comparatively rare cause, and when it *is* the cause it
**usually** presents as a **timeout or an OOM kill**, not as a wrong value, a wrong record,
or a mismatched assertion (on some runners an eventual-consistency, retry, or fallback path
can surface load as a wrong value — but that is the exception, not the default). Treat "it
was just under load / CI was busy" as a hypothesis to prove from the actual error, not a
default. A test that passes 100/100 locally can fail 1/10 in CI because of these conditions,
not because CI is slower.

Whether CI workers share backing services or each gets its own is **app-specific — check the
app profile** (e.g. isolated per-worker sidecars running tests sequentially vs. many workers
sharing one datastore concurrently produce very different flake mechanisms). See that app's
profile, e.g. `references/profiles/your-app.md` — add your own if useful.

## Categories that rarely reproduce locally

| Category | Why local passes | What to do instead |
|----------|------------------|--------------------|
| Suffix / identifier collision | Low-resolution identifiers (e.g. second-precision timestamps) are unique when tests run minutes apart locally, but collide when a CI batch runs many tests against one datastore in the same second (whether workers are parallel or a single worker runs a fast sequential batch) | Fix: append high-entropy uniqueness to the identifier |
| Thread-boundary cache staleness | A cache populated on one thread is read on another (e.g. a server thread vs the test thread). The split exists wherever the code runs across threads (browser driver, background worker) — a naive single-threaded local run just doesn't exercise it, so it surfaces in CI | Fix: stub at the boundary the other thread crosses |
| Cache TTL expiration | Locally the read follows the write immediately; in CI more wall-clock time elapses between them, so a short TTL expires first | Fix: lengthen TTL for the test, or use an in-memory fake |
| Lock / resource contention | No contention with one process; or a real lock taken by earlier code in the batch is never released | Fix: stub the lock/resource when not under test |
| Background-thread DB race | The code under test spawns a thread whose DB call races the test's transaction rollback — only manifests when that async path runs | Fix: stub the method that spawns the background work |

For these, a local run would give zero signal even if it were allowed — which it isn't. Go
straight to the fix and verify with measurement-driven verification (below).

## Measurement-driven verification

Verify a fix by comparing CI failure rates across two branches:

1. **Baseline branch** (no fix): push the unchanged test, trigger N CI builds, record the
   pass rate — excluding infrastructure noise (e.g. browser crashes).
2. **Experiment branch** (with fix): push the proposed fix to a *separate* branch, trigger
   N CI builds, record the pass rate — same noise exclusion.
3. **Compare:** a meaningful improvement needs enough builds to clear the noise floor. For
   a ~10% failure rate, N=10 is a starting point; N=20+ gives clearer signal. If the two
   rates are statistically indistinguishable, the fix probably isn't addressing the cause —
   go back to classification.

This is the only rigorous verification for flakes that cannot be reproduced locally.

**Separate branches are required** when the CI provider cancels superseded builds on a
branch (Buildkite's `cancel_running_branch_builds`, and similar on other providers). You
cannot A/B two variants on one branch — pushing the experiment kills the baseline build.
See the CI provider file (e.g. `references/ci/buildkite.md`) for the provider's specifics.

## Filtering infrastructure noise from measurements

Some "failures" are infrastructure, not the test: browser/driver crashes
(`SessionNotCreatedError`), datastore-unavailable errors, OOM kills. Exclude these before
computing pass rates. If *every* failure in a batch is infra noise, the measurement is
unreliable and the test may not be flaky at all. See the framework file for how its
browser/driver failures look.

## Ordering / state-poisoning flakes: read the shard, don't replay it

These are the flakes people reach for a replay on. Whether one is even available depends on
the pipeline, so settle that from the provider and profile files first. **Where the pipeline
re-shards on every build, there is nowhere to run one:** it decides which tests share a
shard, so neither a local run nor a scratch branch can re-assemble the failing shard's test
list, and a pinned seed on its own reproduces nothing once those tests are split across
shards. Where a pipeline can re-run a named shard, that is a CI-side option worth taking.

Either way the failing run's log is the first evidence: the seed and the test files that
shared the shard. Read those co-resident files' cleanup code against the state the victim
depends on to establish the mechanism. Don't assume a per-example execution order is in
there — what the log exposes is provider- and framework-specific. Co-residency plus the seed
is normally the whole of it. If code reading still can't close the mechanism, stop and
report; do not measure a speculative fix.

## Decision table: strategy by category

| Situation | Strategy |
|-----------|----------|
| State poisoning / ordering with known seed | Read the failing shard's test list from the CI log, fix the poisoner, monitor CI |
| Suffix / identifier collision | Fix the identifier, push PR, monitor CI |
| Thread-boundary / cache staleness | Fix the stub, push PR, monitor CI |
| Browser/driver crash noise | Push PR, monitor CI, ignore crashes (noise) |
| Infrastructure (datastore unavailable) | Close the issue (no code fix) |
| Unknown / low confidence | Do NOT push a speculative fix — document findings on the issue, gather more CI failure samples, escalate to the owning team |
