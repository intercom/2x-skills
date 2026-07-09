---
name: thermo-nuclear-code-review
description: >
  Run an extremely strict structural and architectural quality review on a diff, branch,
  or file set, hunting for "code judo" moves that dramatically simplify the implementation
  — not correctness bugs or style nits.
metadata:
  user-invocable: true
  argument-hint: "[PR URL, branch, or file paths]"
  keywords: [thermonuclear, code judo, maintainability audit, harsh review, deep code review]
allowed-tools: Bash, Read, Glob, Grep
---

# Thermo-Nuclear Code Quality Review

An unusually strict review focused on structural quality, architectural health, abstraction cleanliness, and codebase maintainability. This is not a correctness review — it asks whether the code is making the codebase *better* or *worse*.

The guiding principle is **code judo**: actively search for restructurings that preserve behavior while making the implementation dramatically simpler, smaller, more direct, and more elegant. Do not stop at "this could be a bit cleaner." Look for moves where whole branches, helpers, modes, conditionals, or layers disappear entirely. Prefer the solution that feels inevitable in hindsight.

## Scope — What This Review IS and IS NOT

| This review covers | This review does NOT cover |
|---|---|
| Structural quality and architectural health | Correctness bugs (use a dedicated correctness-focused review) |
| Abstraction quality and decomposition | Style nits and formatting |
| Complexity growth and spaghetti detection | Test coverage gaps |
| Layer violations and architectural drift | Security vulnerabilities |
| File size and modularity | Performance micro-optimizations |
| Type boundary and contract cleanliness | Linting violations |

If a correctness review or repo-specific rule enforcement is needed, run that separately. This skill is the architectural conscience.

## Review Context

- **Pin the fixed point first**: Establish what the diff is measured against before reading any code. Use whatever the user supplies — a PR URL, branch, commit SHA, tag, `main`, or `HEAD~5`. If none is given, ask. Then capture the diff once with a three-dot (merge-base) comparison: `git diff <fixed-point>...HEAD`, and the commit list with `git log <fixed-point>..HEAD --oneline`. Before analyzing, confirm the ref resolves (`git rev-parse <fixed-point>`) and the diff is non-empty — a bad ref or empty diff should fail here, not surface as a confusing empty review.
- **Full-file reads required**: For every file with >10 lines changed, read the entire file, not just diff hunks. Structural review depends on surrounding patterns, file size before the change, and consistency with existing conventions.
- **Pre-change file size matters**: For files already >800 lines, note the pre-change line count — the 1000-line threshold (Standard 1) is evaluated against the post-change total.
- **Large diffs**: For diffs >200 changed lines, save to a temp file for reference during analysis.
- **Code smell baseline**: Apply `references/code-smells.md` alongside the standards — an always-on set of Fowler structural smells (Feature Envy, Data Clumps, Primitive Obsession, Shotgun Surgery, etc.) that catches structural problems the numbered Standards don't name explicitly.
- **Skip what tooling enforces**: RuboCop, ESLint, Prettier, and type-checkers already block formatting, naming-convention, and lint issues. Do not spend findings on what CI catches — the review's value is the structural judgement no linter can make.
- **Concrete suggestions**: For each finding, identify the specific standard or smell violated, locate the exact file and line range, and draft a concrete code judo move or restructuring — not a vague observation.

---

## Non-Negotiable Standards

### 0. Be ambitious about structural simplification

Do not stop at "this could be a bit cleaner." Look for opportunities to reframe the change so that whole branches, helpers, modes, conditionals, or layers disappear entirely. Assume there is often a code judo move available — a reorganization that uses the existing architecture more effectively and makes the change dramatically simpler. If you see a path to delete complexity rather than rearrange it, push hard for that path.

### 1. Do not let a PR push a file past 1000 lines without a very strong reason

Treat crossing 1000 lines as a structural smell. Prefer extracting helpers, subcomponents, modules, or local abstractions instead of letting a file sprawl. If the diff crosses that threshold, explicitly call it out. Only waive this if the file is clearly organized and the growth is structurally justified — not just "I added more methods here because this is where the other ones are."

### 2. Do not allow random spaghetti growth

Be highly suspicious of new ad-hoc conditionals, scattered special cases, or one-off branches inserted into unrelated flows. If a change adds if-statements in unrelated code paths, treat that as a design problem, not a stylistic nit. Prefer pushing the logic into a dedicated abstraction, helper, state machine, policy object, or separate module instead of tangling an existing path. Call out changes that make the surrounding code harder to reason about, even if they technically work.

### 3. Bias toward cleaning the design, not just accepting working code

If behavior can stay the same while the structure becomes meaningfully cleaner, push for the cleaner version. Do not rubber-stamp "it works" implementations that leave the codebase messier. Strongly prefer simplifications that remove moving pieces altogether over refactors that merely spread the same complexity around.

### 4. Prefer direct, boring, maintainable code over hacky or magical code

Treat brittle, ad-hoc, or "magic" behavior as a code-quality problem. Be skeptical of generic mechanisms that hide simple data-shape assumptions. Flag thin abstractions, identity wrappers, or pass-through helpers that add indirection without buying clarity.

### 5. Push hard on type and boundary cleanliness

Question unnecessary optionality, loosely-typed interfaces, excessive use of `Hash` params in Ruby, `any`/`unknown` in TypeScript, or cast-heavy code when a clearer type boundary could exist. Prefer explicit typed models or shared contracts over loosely-shaped ad-hoc objects. If a branch relies on silent fallback to paper over an unclear invariant, ask whether the boundary should be made explicit.

### 6. Keep logic in the canonical layer

Most non-trivial codebases have clear architectural layers. Feature logic must not leak into shared paths, and implementation details must not leak through APIs. Prefer existing canonical utilities over bespoke one-offs. Push code toward the right module instead of normalizing architectural drift.

### 7. Feature flags must not create permanent branching debt

A feature flag is a temporary deployment mechanism, not a long-term branching strategy. Flag usage that:
- Adds conditionals in 3 or more locations (the flag is structuring too much logic)
- Has no clear cleanup path (no linked issue, no expiry, no `# TODO: remove after...`)
- Branches deeply inside existing methods rather than wrapping at a higher level
- Creates nested conditionals (`if flag_a && flag_b`)

### 8. Treat unnecessary sequential orchestration and non-atomic updates as design smells

If independent work is serialized for no good reason, ask whether the flow should run in parallel. If related updates can leave state half-applied, push for a more atomic structure. Do not over-index on micro-optimizations, but flag avoidable orchestration complexity that makes the implementation more brittle.

---

## Common Structural Patterns by Stack

The patterns below are common architectural conventions worth checking regardless of which specific standards or repo-local guides apply. Adapt them to whatever stack the codebase under review actually uses.

**Layered backends (e.g. a Rails or similar monolith):**
- Controllers should be thin — orchestration belongs in commands, domain logic in services
- Callbacks (`after_save`, `before_create`) that grow beyond simple defaults are a structural smell — prefer explicit service calls
- Concerns/mixins that accumulate unrelated methods are God-object anti-patterns — each concern should have a single cohesive purpose
- N+1 queries introduced by new associations or loops are a structural problem (the query boundary is in the wrong place), not just a performance nit

**Frontend (e.g. React, Ember, or similar component frameworks):**
- Components past 300 lines of template/JSX should be decomposed
- Shared modules (e.g. `packages/`, `lib/`) must not accumulate feature-specific logic
- Mixing older and newer framework idioms within the same file is architectural regression

**Workers/Queues:**
- New workers must be idempotent — the same message processed twice should produce the same result
- Workers that mix orchestration with business logic should be split
- DLQ-unaware workers (no error handling strategy) are a structural gap

---

## Structural Code Smell Baseline

Beyond the numbered Standards, carry an always-on baseline of Fowler's structural "Bad Smells in Code" — the full catalogue with *what it is → how to fix* lives in `references/code-smells.md`. It is the structural floor every diff is measured against, even when the touched files document no standards of their own. It is **not** a new axis (this skill stays single-axis and structural); it widens recall for smells the Standards don't name explicitly: Mysterious Name, Feature Envy, Data Clumps, Primitive Obsession, Repeated Switches, Shotgun Surgery, Divergent Change, Message Chains, Refused Bequest.

Two binding rules keep the baseline honest — **the repo overrides the baseline**, and **every smell is a judgement call, never a hard violation**. `references/code-smells.md` is the single source of truth for both rules and how they bind; apply them from there.

## Escalation Triggers

Beyond the standards above, escalate aggressively when you see patterns that compound over time:

- A complicated implementation where a code judo reframing could delete whole categories of complexity
- Refactors that move code around but fail to reduce the concepts a reader must hold
- Copy-pasted logic instead of extracted helpers, or bespoke helpers duplicating a canonical utility
- "Temporary" branching likely to become permanent debt
- Callbacks growing beyond simple defaults into orchestration logic
- At scale: chatty service calls, unbounded queries, synchronous work that should be async

---

## Preferred Remedies

When identifying a structural problem, prefer suggestions like:

- **Delete a whole layer** of indirection rather than polishing it
- **Reframe the state model** so conditionals disappear instead of getting centralized
- **Change the ownership boundary** so the feature becomes a natural extension of an existing abstraction
- **Turn special-case logic** into a simpler default flow with fewer exceptions
- **Extract a helper or pure function** from an overloaded method
- **Split a large file** into smaller focused modules
- **Move feature-specific logic** behind a dedicated abstraction
- **Replace condition chains** with a typed model, enum, or explicit dispatcher
- **Separate orchestration from business logic** (commands orchestrate, services contain logic)
- **Collapse duplicate branches** into a single clearer flow
- **Delete wrappers** that do not meaningfully clarify the API
- **Reuse the existing canonical helper** instead of introducing a near-duplicate
- **Extract a concern** only if it has a single cohesive purpose (not a junk drawer)
- **Move the logic** to the layer that already owns the concept
- **Make the worker idempotent** by checking state before mutating it

Do not be satisfied with "maybe rename this" feedback when the real issue is structural. Do not be satisfied with a merely cleaner version of the same messy idea if there is a plausible path to a much simpler idea.

---

## Review Tone

Be direct, serious, and demanding about quality. Do not be rude, but do not soften major maintainability issues into mild suggestions. If the code is making the codebase messier, say so clearly. If the implementation missed an opportunity for a dramatic simplification, say that clearly too.

Good phrases:
- "this pushes the file past 1k lines — can we decompose before adding more?"
- "this adds another special-case branch into an already busy flow — can we move this behind its own abstraction?"
- "this works, but it makes the surrounding code more tangled — let's keep the behavior and restructure"
- "this feels like feature logic leaking into a shared path — can we isolate it?"
- "this abstraction isn't earning its keep — can we just use the direct flow?"
- "there's a code judo move here — if we restructure X, these three branches disappear entirely"
- "this concern is becoming a junk drawer — it mixes unrelated responsibilities"
- "this controller is doing domain logic that belongs in a service/command"
- "this callback chain is growing into orchestration — extract to an explicit service call"
- "this worker isn't idempotent — what happens if the same message is processed twice?"

---

## Output Format

Present findings in priority order.

### Severity Levels

1. **BLOCKER** — Structural regression that should not merge. Clear architectural violation, unjustified file-size explosion, or missed code judo move that would dramatically simplify the change.
2. **MAJOR** — Significant structural concern that will create maintenance burden. Spaghetti growth, layer violations, permanent branching debt.
3. **SUGGESTION** — Structural improvement opportunity. The code works and is not actively harmful, but there is a cleaner path.

### Format per finding

```
### [BLOCKER/MAJOR/SUGGESTION] — <Short title>
**File:** `path/to/file.rb:L42-L67`
**Rule:** <Which standard this violates>

<2-3 sentences: what is wrong and why it matters structurally>

**Code judo move:** <Specific restructuring that would eliminate the problem, if applicable>
```

### Verdict

End every review with exactly one of:

**APPROVE** — No structural regressions. The codebase is as healthy or healthier after this change.

**RETHINK** — Blocker(s) found. The implementation needs structural rework before merge. Summarize what needs to change.

**REFINE** — No blockers, but major issue(s) worth addressing. Summarize the improvements.

---

## Approval Bar

Do not approve merely because behavior seems correct. The bar is: **no violation of Standards 0–8 above** that the author cannot clearly justify. In particular, treat these as presumptive blockers:

- A plausible code judo move exists that would delete significant incidental complexity
- The PR pushes a file past 1000 lines
- The PR scatters feature checks across shared code instead of isolating them
- The PR duplicates an existing helper or puts logic in the wrong layer
- The PR adds a worker without idempotency guarantees
</content>
