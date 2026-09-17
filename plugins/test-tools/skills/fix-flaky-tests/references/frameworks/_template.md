# Framework: <NAME> (<LANGUAGE>) — TEMPLATE

Copy this file to `references/frameworks/<framework>.md` to add support for a new test
framework, then register its detection signal in `references/discovery.md`. Keep
framework-level mechanics here; product-specific patterns belong in an app profile.

## Detecting an automated skip

How a bot or engineer skips a test in this framework, and how to detect it. Examples:
- Jest/Vitest: `it.skip`, `describe.skip`, `xit`, `test.todo`
- pytest: `@pytest.mark.skip`, `@pytest.mark.xfail`, `pytest.skip(...)`
- Go: `t.Skip(...)`, a `//go:build ignore` guard

```bash
# grep pattern(s) that find a skip in this framework
git log --oneline -1 -- <test_file>   # who skipped it, and when
```

A skip is never a valid fix — revert it alongside the real fix.

## Reading the failing run

Local runs are never sanctioned, in this framework or any other, and a replay staged on CI
is usually not available either — the pipeline decides which tests share a shard. Document
what the CI log gives you to read instead: whether this framework randomizes order and
records the seed (Jest `--seed`, `pytest-randomly --randomly-seed`, Go's per-package
ordering), whether the log names the tests that ran in that shard and in what order, and
whether anything in the shard's setup output identifies shared state.

State plainly whether this framework's ordering can be inferred from the log at all — if it
cannot, say so, so a caller doesn't chase evidence that was never recorded.

## Framework-specific manifestations

How each generic category from `references/classification-generic.md` shows up in this
framework's idioms, with the fix direction. Fill the rows that actually occur:

| Generic category | <framework> mechanics & fix |
|------------------|------------------------------|
| Global state poisoning | (module-level mutable state, shared fixtures, etc.) |
| Test-ordering dependency | (suite-scoped setup, shared temp state) |
| Timing / race | (fake timers, async/await, polling) |
| Assertion expectation in setup | (strict mock in beforeEach/fixture) |
| Thread/process-boundary state | (workers, subprocesses, browser drivers) |

## Mocking / isolation conventions

The idiomatic way to stub, fake time, and isolate state in this framework. Note any
host-app rules file the profile should point to.
