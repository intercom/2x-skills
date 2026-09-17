# Structural Discipline — Detailed Criteria

## Scope

Body shape and progressive-disclosure hygiene: section organisation, conditional reference loading, and body↔references duplication. Detection is judgment-bound — paraphrased duplication and missing scope hints can't be matched mechanically.

## When This Applies

Severity tiers in scope: **Major**, **Minor**.

- **Major** — large body↔references duplication, or a monolithic body with a supplied count ≥40 KB, in a widely-shared skill (the escalation predicates below).
- **Minor** — duplication and polish (body↔references duplication, flat reference list missing scope hints, embedded changelog / version history in the body, unconditional detail in an oversized body).

## Finding Types

### Body↔references duplication (the duplication pattern)

**Pattern.** Same rule, code block, or instruction text present in both `SKILL.md` body and a file under `references/`. Claude reads both and pays input tokens twice. Includes paraphrased duplication (same content reworded), not just verbatim copies.

**Detection.** Read the body and the reference files and compare — paraphrased duplication requires judgment, so this is not a mechanical match.

**Severity.** Minor by default. **Escalate to Major when both:**
- ≥50 duplicated lines between body and references (mechanically: byte-overlap or paraphrase span flagged by AI), AND
- the skill is widely shared (published in a plugin or marketplace, loaded by many sessions) rather than personal or project-local — the tier where per-session waste compounds across thousands of sessions.

**Deterministic.** No — paraphrased duplication detection requires judgment; intentional partial summarisation looks the same as accidental duplication at the surface level.

**Fix.** Move every rule to exactly one place: body for orchestration flow, references for detailed lookup tables. Cross-reference; don't duplicate.

**How to spot it.** Read the body. For each paragraph, ask: does this same content (or a paraphrased version) exist in a referenced file? If yes, decide which side keeps it (usually references) and replace the body content with a one-line pointer.

### Flat reference list without per-entry scope hints (the flat-reference pattern)

**Pattern.** SKILL.md ends with a flat bullet list of every reference file — Claude proactively reads them all because the list invites it to. The "## Reference Files" or "## References" section has 5+ entries and lacks both per-entry scope hints ("**Load when investigating DB latency**") and a guard phrase ("Do NOT pre-load all references").

**Severity.** Minor.

**Deterministic.** No — "missing scope hint" requires judgment about whether the existing prose adequately scopes the entry.

**Fix.** Each reference entry needs an explicit load trigger ("load when investigating DB latency", "consult for cross-shard analysis"). Open the section with a guard phrase like "Do NOT pre-load all references. Read only those relevant to the task at hand."

**How to spot it.** Find the reference list (usually near the bottom). If 5+ files are listed without per-entry scope hints, that's the anti-pattern. The reference implementation gives each entry a bolded scope phrase plus an arrow-pointer to when it should be loaded.

### Embedded changelog (version history in the body)

**Pattern.** A `SKILL.md` body carries the skill's own change history — a `## Changelog` / `## Status` / `## Version History` / `## Release Notes` section, or a run of dated or `vX.Y.Z` version entries describing what changed in each release. A skill body should describe how the skill behaves *now*, not how it got here. Version history belongs in git, full stop: git history is the source of truth, and most repos already derive a per-plugin changelog from it automatically. A hand-typed changelog in the body is redundant with both, loads into every consumer's context, and drifts out of sync the moment it's written.

**Detection.** Look for a heading like `## Changelog` / `## Status` / `## Version History`, or 2+ version-stamped entries (`**v0.2.0** — …`, `## [1.3.0] - 2026-…`) that narrate *the skill's own* evolution.

**Severity.** Minor.

**Deterministic.** No — a heading match alone is not enough. A skill whose *domain* is changelogs (e.g. one that writes product changelog posts, or instructs the model to append a Change Log to a document it produces) legitimately uses the word. The finding is the skill narrating *its own* version history, which needs judgment to tell apart from changelog-as-subject.

**Fix.** Delete the version-history block from the body — don't relocate it, don't replace it with a pointer. Git history already records what changed and when, and a generated changelog file typically already turns that into a durable record; the body should carry neither a changelog nor a reference to one. Keep any genuine current-state context that was mixed into the section (roadmap, scope, sibling-skill relationships), reworded to present tense, under a non-changelog heading.

**How to spot it.** Read the body top to bottom. A section that reads "here's what we changed in each version" — rather than "here's how this skill behaves now" — is the anti-pattern, even when it also carries a few present-tense facts worth keeping.

### Unconditional detail in an oversized body (the monolith pattern)

**Pattern.** A `SKILL.md` body over ~24,000 B (~6k tokens) that carries detail only some invocations need — exhaustive query catalogues, every error-code branch, full worked walkthroughs, per-region variants — inline rather than behind a conditional pointer. The whole body loads the moment the skill activates, so a task needing one branch pays for all of them. A `references/` directory does not help here: activation reads the body, not the directory.

**Detection.** The qualitative predicate carries the finding, because a review runs on Read/Grep/Glob and cannot measure bytes. Step 1 already has you read the whole body — so ask of each section: does *every* invocation need this, or only some? The finding is a body that is long **and** made mostly of sometimes-needed detail. A body that is long because the orchestration flow itself is long is not. Byte figures here are calibration, not a required measurement: ~24,000 B (~6k tokens) is roughly where a body stops fitting in one screenful of Read output by a wide margin. Use an exact count only when one is available — supplied in the request, or read off a lint report.

**Severity.** Minor by default, including whenever no byte count is available. **Escalate to Major only when all three:**
- an exact body byte count is available (supplied in the request or from a lint report), AND
- it is ≥40,000 B (~10k tokens), AND
- the skill is widely shared (published in a plugin or marketplace, loaded by many sessions) — the tier where per-activation waste compounds.

Never infer a byte count in order to reach Major. Without one, file Minor and say the count was unavailable.

**Deterministic.** No — whether a section is task-conditional or load-bearing on every path needs judgment, and the size input is an estimate under Read-only tooling. A mechanical lint gate for the same budget may exist or land separately in a given repo and would bind net-new skills only; this finding is what covers grandfathered bodies either way, so do not treat a mechanical gate as a precondition for firing.

**Fix.** Move each task-conditional section into `references/<topic>.md` and replace it with a one-line pointer carrying its load trigger (pointer shape: see the flat-reference pattern above). Keep routing, decision rules, and guardrails that apply on every path in the body. Do not relocate the whole body — a body reduced to a bare index of references is the flat-reference anti-pattern.

**How to spot it.** Scan the body's headings for ones naming a case, variant, or catalogue ("region failures", "EU region", "Common Queries") — those are candidates, not verdicts. Confirm each against the skill's own scope before counting it: an EU-only skill's "EU region" section is needed on every invocation, and a catalogue every path consults is routing. Headings naming a step in the flow ("Decide the scope", "Report the verdict") belong in the body.

## Out of Scope / False-Positive Guardrails

- **Worked examples are not duplication.** A single bash block in the body showing the expected shape of one call, with the detailed walkthrough in `references/examples.md`, is the correct pattern. The anti-pattern is the entire walkthrough being in both places.
- **Tables intentionally summarising a fuller reference are not duplication.** A 5-row inline table in the body that points to a 30-row reference table is summarisation, not duplication. Flag only when the inline content is comprehensive enough to replace reading the reference.

## Rewrite Policy

**Do not produce a suggested rewrite for Structural findings.** The fixes are mechanical or structural (split body into `references/`, deduplicate a section, add per-entry scope hints). Describe the fix in prose — e.g. "Move the 'Common Queries' section from SKILL.md into `references/common-queries.md` and replace the body with a one-line pointer." The author owns the structural change. Format spec for the (unused-here) rewrite block lives in [`suggested-rewrites.md`](./suggested-rewrites.md).

## Notes for Implementers

- Body↔references duplication is judgment-bound: intentional partial summarisation looks the same as accidental duplication at the surface level. Weigh whether the inline content is comprehensive enough to replace reading the reference before flagging.
- Progressive disclosure is the goal, not brevity for its own sake. A long body is healthy structure only when the length *is* the routing — the flow, the decision rules, the always-applicable guardrails. Size alone is not the finding; size plus sections that only some invocations need is. Having a well-organised `references/` directory does not by itself redeem an oversized body, because activation loads the body regardless of what sits beside it.
