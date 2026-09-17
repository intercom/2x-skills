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
- NEVER propose a diagnosis-driven fix without the actual CI error message (exception + backtrace — fetched from the CI logs OR already pasted in the prompt / by the user). The cheap fast exits are the sole exception: already-fixed, bot-skip revert, and broken-not-flaky resolve an issue from git/PR history without a CI error and may open a PR. This rule governs the real investigation that follows a failed fast-exit.
- NEVER proceed with a real investigation if the CI error is not in hand. **"In hand"** = the exception + backtrace is present in the prompt OR was retrieved by a tool. A broken log fetch does NOT mean "no error" when the caller already supplied it in the prompt — check the prompt first, and if the error is there, proceed normally (a headless run with its CI access down but the error pasted is a valid investigation). Only when the error is genuinely absent AND cannot be fetched: **interactive caller** (a user can answer) — stop and ask for it; **headless caller** — no interactive user to answer (an automated or scheduled invocation with nobody to ask; if unsure, assume headless) — ABORT and return the **CI-Logs-Unavailable Abort** (see HARD GATE below). Never downgrade to a guess or a "best-effort" hypothesis; there is no "reduced confidence" mode.
- NEVER run a test locally, for any reason — not `bundle exec rspec`, `script/test`, `jest`, `pytest`, `go test`, or any equivalent. Not to reproduce, not to confirm a mechanism, not to verify a fix. This holds for every flake category, including seed-reproducible state-poisoning/ordering, and having a local test environment available changes nothing. Diagnose from the CI error and source reading. Whether a replay can be staged on CI at all is a property of the pipeline, not a universal — some let you pin a seed or re-run a named shard; others re-shard on every build so there is nowhere to replay one. Read the discovered provider and profile files before concluding either way, and work from whatever evidence they name. The ban above is on running the test *here*; it says nothing about what CI can be asked to do.
- NEVER assume infrastructure flakiness without build-wide evidence
- Only fix if you can identify the root cause with HIGH confidence
- NEVER claim a fix is complete until CI is green — a "fix" that fails CI is not a fix. Monitor the PR build, investigate failures, and iterate until it passes.
- Verification of a proposed fix must come from a green CI build, never from local runs. Local runs cannot replicate CI's real backing services, test-isolation model, or cross-test ordering, so a local pass means almost nothing.
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

**First check whether the CI error is already in hand.** If the failing job's exception +
backtrace was pasted into the prompt (or supplied earlier by the user), the gate is already
satisfied — proceed with the investigation even if you cannot fetch logs yourself. A headless
run whose CI access is down but whose prompt contains the error is a valid investigation, not
an abort. Only when the error is NOT already present do you try to fetch it.

Fetch the failing job's logs using the CI provider file for the detected provider (e.g.
`references/ci/buildkite.md`). Extract: exception class + message + backtrace, total
failed-test count, and which unique files are affected.

**If the CI error is not in the prompt and cannot be fetched** — MCP not connected, API down,
logs expired, retrieval returns nothing useful — what you do next depends on whether there is
a user to ask:

- **Interactive caller:** ask the user to paste the error verbatim. A user-pasted error is
  equivalent to a tool-fetched one for this gate. Stop and wait rather than guessing.
- **Headless caller (no interactive user to answer — an automated or scheduled invocation
  with nobody to ask; if unsure, assume headless):** the CI error is genuinely absent, so it
  is **100% unsafe to proceed** — ABORT with the message below. This holds for every
  detected provider (Buildkite, CircleCI, GitHub Actions) — the missing signal is the CI
  error, not any one tool. Do NOT substitute local reproduction, code reading, or a
  speculative write-up for the missing CI error, and do NOT open a PR or post a diagnosis
  comment. A confident-but-unfounded diagnosis is worse than none: it ships an inert "fix",
  closes the issue, and sends the next engineer down a false trail. (A local run is never the
  way out of this: it cannot discover a root cause when the error is absent, and cannot
  confirm one either. See HARD-RULES.)

**Code-only analysis is never an acceptable substitute.** Do not retry failing log calls
more than twice in a session.

### CI-Logs-Unavailable Abort (headless)

When headless and the CI error cannot be established, stop all work and return the message
below to the caller — unmissable and unsoftened, it is the entire deliverable. Produce
nothing else, and in particular no PR and no issue comment. Keep the wording verbatim in
substance, but name the **detected CI provider** and its feature in place of the Buildkite
placeholders (the same abort applies to CircleCI and GitHub Actions runs):

> **ABORTED — cannot safely investigate this flaky test.** The failing job's CI logs could
> not be retrieved (the log source for the detected provider — e.g. the Buildkite / CircleCI /
> GitHub Actions API or tooling — was unavailable or not connected), and there is no user to
> paste the error. Diagnosing a flaky test without its actual CI error produces confident but
> wrong root causes, so I did not proceed. **No diagnosis, no PR, and no issue comment were
> produced.** To re-run: grant this invocation CI log access for the detected provider, or
> paste the failing job's exception + backtrace, then re-invoke.

Do not soften this into a partial finding, a "here's my best guess" hypothesis, or a
"blocked, but I reproduced something locally" report. The correct output of a blind
investigation is the abort message and nothing more.

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

## Response Style

Skip narration and step commentary ("Now I'll fetch the logs…", "Let me classify this…").
Speak when you have a finding, a question, or a decision point. Emit the
CI-Logs-Unavailable Abort verbatim, with no preamble.

## Investigate Root Cause

Diagnose from the CI error + source reading first — that is what identifies the root cause.
Reproduction vs verification are different activities. **Reproduction** runs the test to
observe state while the bug happens. **Verification** ("has my fix worked?") always belongs
on CI (see below) — never run the test locally to check a fix.

**There is no reproduction step you run yourself.** Diagnose ordering / state-poisoning
flakes from the failing run's CI evidence — **`references/ci-only-flakes.md`** has the
method. If code reading cannot close the mechanism, that is the STOP case below — not a cue
to measure a guess.

**Headless / automated invocation:** a misconfigured local test harness is not your problem —
you never invoke it. Diagnose from the CI error + code reading and let the PR build verify.

For **state poisoning** (common), the poisoner is usually a sibling test that mutates global
state and doesn't restore it; find it by reading the failing shard's test list in the CI log
and checking which of those co-resident tests mutates the state the victim depends on. For
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
- **`references/frameworks/rspec.md`** — RSpec idioms, what CI evidence RSpec can yield (fully fleshed); `_template.md` for new frameworks
- **`references/ci/buildkite.md`** — Buildkite log-fetch (fully fleshed); `_template.md` for new providers
- **`references/ci-only-flakes.md`** — why these flakes give no local signal, noise filtering, measurement-driven verification
- **`references/handling-unrelated-ci-failures.md`** — diagnosing CI failures unrelated to your fix PR

App profiles (`references/profiles/<app>.md`) are an extensibility point for your own
product-specific flake catalogue and workflow conventions — none ship by default; add your
own by following the shape described in `references/discovery.md`.

### Worked Examples

Following the Reported → Validated → Classified → Root cause → Fix → Sweep → Guidance format
(both are synthetic RSpec cases):

- **`examples/cross-app-guardrails-poisoning.md`** — global state poisoning via module-level instance variables
- **`examples/thread-local-cache-signup-spec.md`** — thread-local cache in Capybara feature specs
