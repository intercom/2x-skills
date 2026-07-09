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

## Reproduction commands

The command(s) to replay a specific test with a fixed seed/order and the failing test
list. Note whether this framework randomizes order (and the flag to pin the seed):
- Jest: `jest --runInBand --testPathPattern=... --seed=<n>` (with `--seed` support)
- pytest: `pytest -p no:randomly` / `pytest-randomly --randomly-seed=<n> <nodeids>`
- Go: `go test -run TestName -count=1 ./pkg/...` (note `-count=1` disables caching)

State the local-vs-CI reproduction caveat for this framework.

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
