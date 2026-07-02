# Structural Discipline — Detailed Criteria

## Scope

Body shape and progressive-disclosure hygiene: section organisation, conditional reference loading, and body↔references duplication. Detection is judgment-bound — paraphrased duplication and missing scope hints can't be matched mechanically.

## When This Applies

Severity tiers in scope: **Major**, **Minor**.

- **Major** — large body↔references duplication in a widely-shared skill (the escalation predicate below).
- **Minor** — duplication and polish (body↔references duplication, flat reference list missing scope hints).

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

## Out of Scope / False-Positive Guardrails

- **Worked examples are not duplication.** A single bash block in the body showing the expected shape of one call, with the detailed walkthrough in `references/examples.md`, is the correct pattern. The anti-pattern is the entire walkthrough being in both places.
- **Tables intentionally summarising a fuller reference are not duplication.** A 5-row inline table in the body that points to a 30-row reference table is summarisation, not duplication. Flag only when the inline content is comprehensive enough to replace reading the reference.

## Rewrite Policy

**Do not produce a suggested rewrite for Structural findings.** The fixes are mechanical or structural (split body into `references/`, deduplicate a section, add per-entry scope hints). Describe the fix in prose — e.g. "Move the 'Common Queries' section from SKILL.md into `references/common-queries.md` and replace the body with a one-line pointer." The author owns the structural change. Format spec for the (unused-here) rewrite block lives in [`suggested-rewrites.md`](./suggested-rewrites.md).

## Notes for Implementers

- Body↔references duplication is judgment-bound: intentional partial summarisation looks the same as accidental duplication at the surface level. Weigh whether the inline content is comprehensive enough to replace reading the reference before flagging.
- Progressive disclosure is the goal, not brevity for its own sake. A long body backed by a well-organised `references/` directory, with the body kept to routing, is healthy structure — flag duplication and flat reference lists, not size alone.
