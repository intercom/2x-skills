# CI-Only Flakes: Why Local Reproduction Fails

Many flakes never reproduce locally because they depend on conditions that only exist in
CI: **concurrency** (many parallel workers sharing backing services), **load** (slow
responses, timeouts, contention), and **environment** (real datastores, different configs,
clean process state). A test that passes 100/100 times locally can fail 1/10 in CI because
these introduce non-determinism a single dev machine doesn't have.

This file is framework- and CI-agnostic. For the concrete scale and shared-service facts of
a specific app (e.g. a large test suite's parallel worker count and real
memcached/DynamoDB/Redis/ES backing services), see that app's profile, e.g.
`references/profiles/your-app.md` — add your own if useful.

## Categories that rarely reproduce locally

| Category | Why local passes | What to do instead |
|----------|------------------|--------------------|
| Suffix / identifier collision | Low-resolution identifiers are unique on one machine; collide across many parallel workers | Fix: append high-entropy uniqueness to the identifier |
| Thread-boundary cache staleness | Caches only go stale under parallel access patterns | Fix: stub at the boundary the other thread crosses |
| Cache TTL expiration | Cache ops are fast locally, slow under CI load | Fix: lengthen TTL for the test, or use an in-memory fake |
| Lock / resource contention | No contention with one process | Fix: stub the lock/resource when not under test |
| Background-thread DB race | Transaction-rollback races only matter with concurrent threads | Fix: stub the method that spawns the background work |

For these, local runs give zero signal. Limit local attempts to 2 per hypothesis; if it
passes twice, switch to measurement-driven verification.

## Measurement-driven verification

When local runs can't reproduce the flake, verify a fix by comparing CI failure rates
across two branches:

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

## When local verification IS useful

For **test-ordering** or **state-poisoning** flakes, local reproduction with the correct
seed and test list often works — see the framework file for the exact replay command. If it
reproduces, iterate locally (limit 2 attempts). Otherwise treat it as CI-only.

## Decision table: local vs CI verification

| Situation | Local useful? | Strategy |
|-----------|--------------|----------|
| State poisoning / ordering with known seed | Yes | Replay seed + test list, iterate locally |
| Suffix / identifier collision | No | Fix the identifier, push PR, monitor CI |
| Thread-boundary / cache staleness | No | Fix the stub, push PR, monitor CI |
| Browser/driver crash noise | No (noise) | Push PR, monitor CI, ignore crashes |
| Infrastructure (datastore unavailable) | No (no code fix) | Close the issue |
| Unknown / low confidence | No | Do NOT push a speculative fix — document findings on the issue, gather more CI failure samples, escalate to the owning team |
