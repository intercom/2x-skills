# Framework: RSpec (Ruby / Rails)

How the generic flake categories (`references/classification-generic.md`) manifest in
RSpec, plus the RSpec-only mechanics, detection commands, and reproduction commands. This
file is framework-level — it applies to any RSpec/Rails app. Product-specific patterns
(particular services, error classes, infra) live in the app profile, e.g.
`references/profiles/your-app.md` (add your own — none ship by default).

## Detecting an automated skip

The generic "automated skip" fast-exit (see `SKILL.md`) appears in RSpec as `it`→`xit`,
`describe`→`xdescribe`, `context`→`xcontext`, or a trailing `, skip:` / `pending`:

```bash
grep -n 'xit\|xdescribe\|xcontext\|, skip:\|pending' <spec_file>
git log --oneline -1 -- <spec_file>   # who skipped it, and when
```

A skip is never a valid fix. Revert it as part of the real fix (revert + fix root cause in
one PR if the root cause isn't yet fixed; revert alone if it is).

## Reproduction commands

State-poisoning and ordering flakes CAN reproduce locally with the right seed and spec
list (everything else is usually CI-only — see `references/ci-only-flakes.md`):

```bash
bundle exec rspec --seed <seed> <poisoner_spec> <victim_spec>   # ordering / poisoning
bundle exec rspec --seed <seed> <spec_list_from_ci>             # replay the CI bin
```

Limit to 2 attempts per hypothesis. If it passes twice, the flake is CI-only; stop running
locally and switch to measurement-driven verification.

## RSpec-specific manifestations

| Generic category | RSpec mechanics & fix |
|------------------|------------------------|
| **Global state poisoning** | Poisoner mutates a `@@class_var`, module `@ivar`, `Thread.current[:x]`, or a constant, often in an `around`/`after` hook whose `ensure` restores the wrong value. Find mutators: `grep -rn 'disable!\|@@\|Thread.current\[' spec/`. Fix the hook to restore the initializer default; harden the victim with explicit setup in `before`. |
| **Test-ordering dependency** | `before(:all)` / `before(:context)` side effects and fixtures leak across examples. Move state into `before(:each)`; reset associations in `before`. |
| **Timing / race** | `Time.now`/`Time.zone.now`/`Time.current.to_i` near an `expect` without `freeze_time`. Freeze the clock or inject time. Note: `freeze_time` can make time-window/refresh races *worse* (it clamps every query) — prefer fixing the source's time handling. |
| **Assertion expectation in setup** | `expect(...).to receive` in a `before` block makes ALL examples fail with "expected to receive X but didn't", masking the real error. Change `expect` to `allow` for isolation stubs in `before`; keep `expect` in the example body. |
| **Mutable shared config** | A config/memoized method returns a direct reference to a hash that another example mutates → `KeyError` or unexpected values. Return `.deep_dup`, or stub the config in tests. |
| **Non-deterministic ordering** | Positional assertions (`response[0]`) on an unordered AR/ES query. Use `match_array` or `find { |e| e["key"] == value }`. |
| **STI / autoload race** | `config.eager_load = false` in the test env: an association scope built before an STI subclass is loaded returns a subset. Reorder `let!` to load the subclass first; add `association(:name).reset` in `before`. |
| **Background-thread DB race** | Source uses `Concurrent::Future.execute` / a thread pool; the background thread's DB call races RSpec's transaction rollback (`TRILOGY_CLOSED_CONNECTION`, random failures in the *next* spec). Stub the spawning method: `allow(described_class).to receive(:background_method).and_return(nil)`. |
| **Thread-boundary state (Capybara `:js`)** | A feature spec drives a real browser; the Rails server runs in a separate thread that loads its own model instances and its own thread-local caches. Clearing a thread-local in the test thread doesn't reach the server thread, so stale cached flags cause non-deterministic redirects. Stub at the model boundary the server thread loads: `allow_any_instance_of(Model).to receive(:flag?).and_return(false)` — `allow_any_instance_of` is correct because the server thread loads a fresh instance from the DB. |

## Capybara / Selenium browser-crash noise

Feature specs run a real browser via Selenium. Under CI load Chrome/Chromium crashes
intermittently:

```
Selenium::WebDriver::Error::SessionNotCreatedError: Could not start a new session
```

These are **infrastructure noise, not spec-logic failures**. When measuring fix efficacy,
filter browser crashes out before computing pass rates. If every failure in a batch is a
browser crash, the measurement is unreliable and the spec may not be flaky at all — the
browser is. Do NOT treat a browser-crash-only failure set as a regression signal.

## RSpec mocking conventions

Fix the poisoner first, harden the victim second. Prefer `allow` over `expect` for setup
stubs. Route mocks by argument value, never by call-order counters (call order is
non-deterministic under parallel execution). If the host app ships RSpec mocking rules
(e.g. a `.claude/rules/rspec.md`), follow them — the app profile names the path.
