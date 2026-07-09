---
name: fix-flaky-tests
description: Investigate and fix flaky or intermittently-failing tests in any framework and CI system — detects the framework, CI provider, and app profile, then applies the matching classification and fix patterns. Triggers on a flaky-test issue or CI URL, a test that "passes on retry" or "fails in CI but passes locally", a bot that skipped a test, or a request to reopen or dispute the closure or diagnosis of a flaky-test issue (for that case open the issue first; its title or label confirms scope even when the prompt has no flaky-test keywords).
allowed-tools: Bash Read Grep Glob Edit Write Skill
---

# Fix Flaky Tests

Reference guide for investigating and fixing flaky tests across frameworks (RSpec, Jest,
pytest, Go test, …), CI systems (Buildkite, CircleCI, GitHub Actions, …), and apps. The
methodology is universal; framework idioms, CI log-fetch procedures, and app-specific flake
catalogues are loaded on demand via **progressive discovery**. Compose the workflow to the
situation rather than following rigid steps.

<HARD-RULES>
- NEVER skip a test (xit, skip, pending, `t.Skip`, `.skip`, etc.) as a fix
- NEVER fabricate a root cause — if you can't identify it, say so
- NEVER propose a fix without the actual CI error message (exception + backtrace from the CI logs, or pasted verbatim by the user)
- NEVER proceed with code-only analysis if the CI error cannot be established. Stop and ask the user for it. There is no "reduced confidence" mode.
- NEVER assume infrastructure flakiness without build-wide evidence
- Only fix if you can identify the root cause with HIGH confidence
- NEVER claim a fix is complete until CI is green — a "fix" that fails CI is not a fix. Monitor the PR build, investigate failures, and iterate until it passes.
- Verification of a proposed fix must come from a green CI build, never from local runs. Local runs cannot replicate CI's parallelism, shared caches, or cross-test ordering, so a local pass means almost nothing.
- Local reproduction during **investigation** (observing state while the bug happens, confirming the mechanism) is a different activity — allowed and encouraged when the test environment is available. When no environment is available (headless), the investigation is limited to CI logs + code reading.
</HARD-RULES>

## Required Input

One of:
- A bug-tracker issue link about a flaky test
- A test file path
- A CI build/job URL with a failing run
- An advisory question about a flaky test (reproduction strategy, verification, noise interpretation)
- A request to address, reopen, or dispute a *closed* flaky-test issue ("this was mis-identified / wrongly closed")

**Disputed or already-closed issues — re-derive, don't trust the close.** Treat any
existing investigation or closing comment as a hypothesis, not a finding — re-establish the
root cause from the actual CI logs (the HARD GATE below applies regardless of what the
comment claims). Closing comments are frequently plausible-but-wrong: they cite a mechanism
that doesn't match the real backtrace, or apply the infrastructure fast-exit ("a shared
dependency was briefly down → no code fix") to a build where only **one** test failed. A
single-example failure is the opposite of build-wide infra evidence — it usually means that
one test is uniquely fragile: e.g. a strict assertion on a process-global sink (an error
reporter, a metrics client) with no pass-through fallback, tripped by a benign *handled*
report emitted by unrelated setup during the same example. That is a fixable code-side bug
owned by the test's source team, not an infra ticket. If you reopen, correct the routing to
that owning team.

## Discover the Environment (do this first)

Before classifying anything, detect the stack so the right knowledge loads. Run the
detection in **`references/discovery.md`** — it covers three tiers:

1. **Test framework** (from `Gemfile`/`package.json`/`pyproject.toml`/`go.mod` + test dirs)
   → load `references/frameworks/<framework>.md`. Only `rspec.md` ships fully fleshed;
   others fall back to `references/classification-generic.md` + `frameworks/_template.md`.
2. **CI provider** (from `.buildkite/`/`.circleci/`/`.github/workflows/`) → load
   `references/ci/<provider>.md` for how to fetch logs. Only `buildkite.md` ships fully
   fleshed; others use `ci/_template.md`, but the HARD GATE below still applies.
3. **App profile** (from `git remote get-url origin`) → load `references/profiles/<app>.md`
   if one matches (e.g. `your-org/your-app` → `profiles/your-app.md`). No app profiles ship
   by default — add your own by following the shape in `references/discovery.md`. If none
   matches, use the generic + framework tiers only and do not invent app-specific
   classifications.

State the detected stack in one line, then proceed. If a tier is unknown, say so and note
the degraded mode.

## Fast Exits (cheap — no CI logs needed)

Check these BEFORE fetching CI logs or doing deep investigation. They rely only on git and
PR history, so they resolve an issue even when CI logs have expired or the CI MCP is
unavailable — which is exactly when an already-fixed or already-PR'd issue would otherwise
get stuck on the HARD GATE below. Most flaky-test issues are settled here without a full
investigation.

### Already Fixed

Many flaky-test issues already have a fix merged but the issue was never closed. Check for a
merged fix before investigating:

- Test file commits since the issue date: `git log --oneline --since="<issue_date>" -- <test_file>`
- Source file commits over the same window: `git log --oneline --since="<issue_date>" -- <source_file>`
- Merged PRs referencing the test: `gh pr list --search "<test_file_name>" --state merged --limit 5`

If any surface a relevant merged fix, **STOP** and report it. Also close any stale bot-skip
PRs the real fix superseded.

**Partial-fix guard:** if a fix is merged but new flaky issues were filed *after* the fix
date for the same file (possibly a different test within it), the fix was partial — continue
to historical recurrence.

### Existing Open PR

`gh pr list --search "<test_file_name>" --state open` — if one exists, review it rather than
starting over.

### Broken, Not Flaky

`git log --oneline -10 -- <test_file>` and `-- <source_file>`. Signals of broken (not
flaky): ALL tests in the file fail, deterministically, every run, any seed/order; failures
started after a specific commit. Fix: update the test's setup for the new dependency.

### Historical Recurrence (Systemic Signal)

`gh search issues "<test_file_name>" --limit 30 --json number,state,createdAt | jq 'length'`.
**If 3+ issues exist for the same file:** read ALL prior fix PRs, find the common
vulnerability, and fix it systemically. Fixing only the reported test regenerates the issue
within weeks. (App profiles record known serial offenders.)

### Bot Skips

Automated tools "fix" flaky tests by skipping them — never a valid fix, it only hides the
failure. Detect the skip with the framework file's grep pattern and check authorship with
`git log --oneline -1 -- <test_file>`. Action depends on whether the root cause is fixed:

| Bot skipped | Root cause fixed | Action |
|-------------|------------------|--------|
| Yes | Yes | Revert the skip, open a PR restoring coverage |
| Yes | No | Revert the skip AND fix the root cause in the same PR |

## CI Log Access (HARD GATE)

If the fast exits above did not resolve the issue, you are doing a real investigation — and
the actual CI error message is essential. Code-only analysis produces plausible but wrong
hypotheses — in one real case, code analysis concluded "case not created (timeout)" when
the actual error was "wrong case found (suffix collision)."

Fetch the failing job's logs using the CI provider file for the detected provider (e.g.
`references/ci/buildkite.md`). Extract: exception class + message + backtrace, total
failed-test count, and which unique files are affected.

**If logs are unavailable** — MCP not connected, API down, logs expired, retrieval returns
nothing useful — ask the user to paste the error verbatim. A user-pasted error is
equivalent to a tool-fetched one for this gate. Stop and wait rather than guessing.
**Code-only analysis is never an acceptable substitute.** Do not retry failing log calls
more than twice in a session.

## Classify the Failure

Start with the framework-agnostic categories in **`references/classification-generic.md`**
(broken-not-flaky, global state poisoning, test-ordering, timing/race, suffix collision,
resource exhaustion, external-service flake, thread-boundary state, …). Then consult the
**framework file** for how the category manifests in that framework's idioms, and the **app
profile** for product-specific instances (specific services, error classes, infra).

**Infrastructure fast-exit:** a build-wide pattern (many unrelated tests across several
files failing in one run) almost always means infrastructure, not a test bug — close the
issue, no code fix. The app profile defines the exact threshold and common infra exceptions.

**Quick heuristics:** passes on retry in the same build → test-side (state/ordering/timing);
all tests in a file fail every run → broken by a code change, not flaky.

## Investigate Root Cause

Reproduction vs verification are different activities. **Reproduction** runs the test to
observe state while the bug happens — a way to close a confidence gap during investigation.
**Verification** ("has my fix worked?") always belongs on CI (see below).

Most CI flakes do NOT reproduce locally. Limit to 2 local attempts per hypothesis; if it
passes twice, the flake is CI-only and further local runs add no signal. The framework file
gives the replay command; **`references/ci-only-flakes.md`** explains which categories
reproduce locally vs not, browser/driver noise, and measurement-driven verification.

For **state poisoning** (common), the poisoner is usually a sibling test that mutates global
state and doesn't restore it; confirm by running it before the victim at the same seed. For
**timing**, look for wall-clock assertions without a frozen clock and too-short async waits.
For **resource issues**, prefer the infra fast-exit over a test-side fix.

## Propose and Implement Fix

**Only with a HIGH-confidence root cause.** Fix at the source, not the symptom — a per-test
workaround masks the systemic bug and gets copied by the next engineer.

**Scope before writing:** once the root-cause pattern is known, grep the suite for it. If
more than one test is vulnerable, the fix belongs in source or a shared helper, not copied
into each test. Lead the PR with the systemic fix; any unskip is secondary.

For test-level fixes when a systemic fix isn't possible: fix the poisoner, harden the victim
with explicit setup as defense-in-depth, and follow the framework's mocking conventions.

If you cannot identify the root cause, STOP. Report what you found and tried. No speculative
changes.

**When creating a PR**, use your PR-creation workflow (e.g. `gh pr create`) rather than
pushing straight to the default branch. Route review to the team that owns the **source**
file — the app profile names the mechanism if one exists (e.g. a constant listing owning
teams). Enable auto-merge so it lands on green.

## Verify the Fix

**CI is the only authoritative signal.** A fix that passes 40 local runs but fails in CI is
not a fix. The fix is complete only when the PR build is green; keep iterating on the branch
until it passes. A local pass means almost nothing — never treat it as verification.

For **CI-only flakes**, use measurement-driven verification: compare CI failure rates
between a baseline branch (unchanged) and an experiment branch (fix) over N builds each,
excluding infra noise. See `references/ci-only-flakes.md`. Note the provider may cancel
superseded branch builds, so baseline and experiment need separate branches.

When CI fails on an **unrelated** test, consult **`references/handling-unrelated-ci-failures.md`** —
do not modify the unrelated failing test in your fix PR.

## Sweep for Siblings

**Same-file first.** Most recurring flakes share a vulnerability with sibling tests in the
same file — a partial fix is the leading cause of recurring issues. Fix every hit of the
unsafe pattern inside the reported file before the PR goes out. A suite-wide sweep is
secondary — useful for blast radius and deciding whether to lift the fix into a shared
helper.

## Update Guidance (Novel Findings)

If the root cause is a new framework-agnostic category, add it to
`references/classification-generic.md`. If it's framework-specific, update the framework
file; if product-specific, your app profile. To support a new framework or CI provider, copy
the matching `_template.md` and register its signal in `references/discovery.md`. After
every fix, ask: "Could this skill have caught this earlier or more completely?" If so, open
a PR to this skill's repo.

## Additional Resources

### Reference Files

- **`references/discovery.md`** — detect framework / CI / app, and what to load
- **`references/classification-generic.md`** — framework-agnostic flake categories
- **`references/frameworks/rspec.md`** — RSpec idioms, repro commands (fully fleshed); `_template.md` for new frameworks
- **`references/ci/buildkite.md`** — Buildkite log-fetch (fully fleshed); `_template.md` for new providers
- **`references/ci-only-flakes.md`** — CI-only reproduction, noise filtering, measurement-driven verification
- **`references/handling-unrelated-ci-failures.md`** — diagnosing CI failures unrelated to your fix PR

App profiles (`references/profiles/<app>.md`) are an extensibility point for your own
product-specific flake catalogue and workflow conventions — none ship by default; add your
own by following the shape described in `references/discovery.md`.

### Worked Examples

Following the Reported → Validated → Classified → Root cause → Fix → Sweep → Guidance format
(both are synthetic RSpec cases):

- **`examples/cross-app-guardrails-poisoning.md`** — global state poisoning via module-level instance variables
- **`examples/thread-local-cache-signup-spec.md`** — thread-local cache in Capybara feature specs
