# Cost — Detailed Criteria

## Scope

Token efficiency: patterns in a skill's body that cost output tokens or context tokens per session without commensurate value. Every skill's name + description loads into every Claude Code session at startup; every body line and reference file is paid for by every session that activates the skill. Small wastes compound across a fleet of sessions.

## When This Applies

Severity tiers in scope: **Major**, **Minor**.

- **Minor** — default for every cost pattern EXCEPT script-extractable orchestration.
- **Major** — two routes: (1) the per-pattern escalation predicates below (each combines broad reach + a body-size or chain-length threshold); silent escalation is forbidden, the reviewer must cite the predicate. (2) **Script-extractable orchestration is Major by default** — the only cost pattern whose smell is severe enough that the whole-skill shape, not a per-pattern threshold, sets the severity (see its section below). Its high default severity is paired with a deliberately strict firing bar.

## Determinism

Every finding type in this category is **judgment-bound** (`deterministic: false`). Distinguishing a sequential bash chain (no decision points between steps) from "worked examples illustrating different cases" requires judgment, and so does deciding whether existing prose qualifies as a Response Style section.

The exception is the size half of each escalation predicate (line count, chain count, reach) — those are mechanically checkable. The size threshold is deterministic; the underlying match is judgment-bound.

---

## Cost Patterns

The remaining cost patterns are all judgment-based — paraphrased duplication and tool-cost mismatches can't be detected by regex. (Body↔references duplication moved to [`structural.md`](./structural.md) — it's about body shape, not cost mechanism. Conditional reference loading is the flat-reference pattern and also lives in `structural.md` — it's about reference-section shape.)

### Scriptable bash chains in skill body

**Anti-pattern.** Skill body contains 3+ fenced bash blocks that string together `gh`/`curl`/`grep`/`jq`/`awk` into a sequential chain (no decision points between steps). The LLM has to re-derive these steps every session.

**Fix.** If the steps are deterministic (no judgment), put them in a shell script. The LLM calls the script once, parses the JSON output, and only handles parts requiring reasoning.

**How to spot it.** Look for sequential code blocks that read like a runbook — no decisions between them, just "run A, parse output, run B with parsed value, run C". That's a script, not skill content. Note: worked examples (one block showing the expected shape of a single call) are fine; the anti-pattern is a _chain_.

**Severity.** Minor by default. **Escalate to Major when both:** the skill is widely shared (published in a plugin/marketplace, loaded by many sessions) AND ≥3 chained bash blocks form a sequential runbook (no decision points between them). Each chained block in a high-traffic skill multiplies token cost across thousands of sessions.

**Deterministic.** No — distinguishing a sequential chain from "worked examples illustrating different cases" requires judgment about whether the steps have decision points.

### Script-extractable orchestration (whole-skill glue)

**`finding_type`: `script-extractable-orchestration`.**

**Anti-pattern.** The whole-skill generalization of the bash-chain pattern above. A skill's _dominant content_ is a fixed, deterministic pipeline — pinned queries, hardcoded IDs/values, a set sequence of tool/MCP calls, exact output templates, and mechanical format conversions (e.g. markdown→Slack) — that the LLM re-derives from prose every session instead of executing a script once. The bash-chain pattern only sees `gh`/`curl`/`jq` blocks _in the body_; this one fires when the same deterministic orchestration is spread across MCP calls and `references/` files, where the bash-chain detector structurally misses it. The tell: heavy "run _exactly_ this query", "do NOT deviate", "verified <date>" language — deterministic spec wearing a skill costume — and a payoff that is mostly gathering + formatting + posting, with genuine reasoning a thin minority.

**Fix (extract-glue — never "delete the skill").** Move the deterministic gathering/formatting/posting into a bundled `scripts/` file the skill invokes once; keep the SKILL.md as the thin layer that tells the script what to run and then handles only the genuine judgment — classification, synthesis, decisions the author could not pre-script. The recommendation is _always_ restructuring (thin skill over a bundled script), never removal: even a heavily-glue skill usually has a judgment kernel worth keeping as a skill. Describe the extraction in prose (no rewrite block — see Rewrite Policy); name which sections are the deterministic pipeline and which are the judgment kernel.

**How to spot it.** Estimate the ratio of _deterministic specification_ (fixed queries, hardcoded IDs/values, set call sequences, output templates, conversion rules) to _genuine judgment_ (fuzzy classification, natural-language synthesis/summarization, decisions contingent on content the author couldn't enumerate). Count body **and** `references/` — the glue often hides in a "data sources" reference. Fire ONLY when deterministic spec is the **dominant majority** of the skill's substantive content AND the judgment content is a thin minority. This is a ratio judgment, not a presence check.

**Severity.** **Major by default.** A skill shaped as deterministic orchestration pays its full re-derivation cost on every session — and, when run on a schedule / headless (a cron or unattended job), every single day with no human in the loop — while risking that the LLM silently varies a query that was meant to be fixed. Downgrade to **Minor** only in the narrow case of a _single_ extractable deterministic chain inside an otherwise judgment-rich skill — and prefer the `scriptable-bash-chain` finding type for that case. No Critical: this is a cost/shape smell, not a correctness defect (a pipeline that produces _wrong_ output is Integrity).

**Deterministic.** No (`deterministic: false`) — estimating the glue:judgment ratio is judgment-bound.

**Guardrails (Major-by-default demands a strict firing bar — do NOT let this become a noise machine).**

- Fire on _dominance_, never on _presence_. Almost every good skill contains some deterministic glue; that is not the defect.
- Do NOT fire when the deterministic steps exist to _feed_ a genuine judgment output (classification, synthesis) that is the skill's primary product — that's a correct skill shape.
- Do NOT fire on pure-reference / pure-context skills (all project-specific facts Claude couldn't derive — dataset names, column quirks, tool IDs — and no executed sequence). Context is facts Claude needs, not a sequence Claude runs; see [`content-quality.md`](./content-quality.md) § Good Context. A skill being _all facts_ is ideal, not glue.
- Do NOT fire on small skills. The floor is <100 lines measured across the skill's _total_ substantive content — SKILL.md body **plus** `references/` — NOT the body alone (unlike the Response-Style floor, which is body-only). Glue characteristically hides in a reference file, so a 60-line body with a 200-line pinned-query reference is in scope; a genuinely small skill (body + references both tiny) is not.
- A single illustrative tool call / worked example is not orchestration.

**Boundary with Convention.** Cost owns the _token-cost mechanism_ (the LLM re-deriving a deterministic pipeline every session). Convention owns the _shape_ lens of the same smell (a skill built as an end-to-end orchestrator rather than a context block) — `orchestration-shaped-skill` in [`convention.md`](./convention.md). They are the same defect seen from two angles and share the extract-glue fix. When a skill is mostly glue end-to-end, file **both** (one per category, as the rubric does for a skill that is both mispriced and misplaced); when only a single chain is extractable from an otherwise-sound skill, file Cost alone.

### MCP result-size nudges (`num_results`, `limit`, depth)

**Anti-pattern.** Skill calls an MCP tool that supports a size-limiting parameter (a search tool's `num_results`; a SQL tool's row limit; a chat-read tool's message depth), but the skill doesn't tell Claude to set one. Default result sets are often large.

**Fix.** Add explicit guidance in the skill: "When calling X, set `num_results` to 5 unless you specifically need more." For tools whose defaults return large payloads on every call, this is the single biggest lever.

**How to spot it.** Identify the MCP tools the skill calls. For each, check the tool's schema (do its inputs include limit/depth/result-size params?) and check the skill's prose — does it mention a sensible default for that parameter, or leave it implicit?

**Severity.** Minor.

**Deterministic.** No — requires judging which tool calls in the skill are high-volume enough to warrant a size nudge.

### Field selection / projection — ask for less

**Anti-pattern.** Skill calls an MCP that returns full entity payloads when only 3–4 fields are needed. Output tokens are dominated by JSON the LLM reads and then paraphrases.

**Fix.** Two-sided: (1) tell Claude to request only the fields it needs in the skill prose; (2) push the MCP server itself to support field projection (companion change in the server's repo). Either side alone helps; both together compound.

**How to spot it.** Read example tool calls in the skill. Do they ask for specific fields, or fetch defaults? If the MCP supports projection and the skill doesn't use it, flag.

**Severity.** Minor.

**Deterministic.** No — requires judging which fields the skill actually consumes downstream.

### Response Style discipline (banning narration)

**Anti-pattern.** Skill body lacks guidance against narration ("Now I'll run the query...", "Let me check...", "The results show that..."), so Claude generates these output tokens that add no information for the user.

**Fix.** Add a `## Response Style` (or similar) section to high-traffic skills explicitly banning narration and result-paraphrasing. Even short guidance moves the needle measurably.

**How to spot it.** This applies to _high-volume_ skills (widely shared, activated frequently — which broadly correlates with skill body size). For those skills, check whether a Response Style / Output Style section exists. For small / low-traffic skills, the cost-benefit doesn't justify the guidance — see the suppression floor below.

**Severity.** **Suppression floor — do NOT flag at all when SKILL.md body < 100 non-frontmatter lines.** Below that, the skill emits too little output for Response Style discipline to move the needle measurably, so a finding here is noise — not even Minor. This is the calibration that keeps the pattern from over-firing on every mid-sized skill. At or above the floor: **Minor by default; escalate to Major when** the skill is widely shared (the high-traffic case where narration cost compounds across thousands of sessions). The 100-line gate is the single threshold for both the floor and the escalation — below it nothing fires, at/above it the reach decides Minor vs Major.

**Deterministic.** No — judging whether existing prose qualifies as a Response Style section (vs. scattered tone guidance) requires reading the body. The body-line-count half of the predicate IS mechanical; the Response-Style-presence half is not.

---

## Severity Escalation for Cost Patterns (rollup)

The per-pattern severity blocks above name each escalation predicate explicitly. This rollup table is the canonical view; the per-pattern blocks are authoritative.

| Pattern                   | Default                 | Escalate to Major when                                           |
| ------------------------- | ----------------------- | ---------------------------------------------------------------- |
| Scriptable bash chains    | Minor                   | widely-shared skill AND ≥3 chained bash blocks                   |
| MCP result-size nudges    | Minor                   | — (case-by-case only)                                            |
| Field projection          | Minor                   | — (case-by-case only)                                            |
| Response Style discipline | Minor (only ≥100 lines) | widely-shared skill AND SKILL.md body ≥100 non-frontmatter lines |

Response Style discipline has a **suppression floor**: do not flag it at all below 100 non-frontmatter lines (not even Minor). At/above the floor it's Minor, escalating to Major for widely-shared skills.

If escalating, cite the predicate explicitly per the escalation rule in the parent severity rubric — silent escalation is not allowed.

---

## Out of Scope / False-Positive Guardrails

- **Worked examples (one bash block) are not the bash-chain pattern.** The anti-pattern is the _chain_ of 3+ blocks forming a sequential runbook.
- **Body↔references duplication is NOT a Cost finding.** Same byte saved, but it's a body-shape concern. Lives in [`structural.md`](./structural.md).
- **Flat reference list is NOT a Cost finding.** Same reasoning — body-shape concern. Lives in [`structural.md`](./structural.md).
- **Tool steering / cheaper-tool selection** is too situational to live as a catalog pattern. Surface case-by-case in specific reviews, not as a Cost finding.
- **Cost-aware _guardrails_** (session-cost triggers, subagent fan-out warnings) are hook-level concerns, not per-skill review concerns.
- **Placement and similar-skill duplication are NOT Cost findings**, even though duplicate skills waste both context budget and engineering time. They live in [`convention.md`](./convention.md) — they're placement/structure concerns.

## Rewrite Policy

**Do not produce a suggested rewrite for Cost findings.** Point at the anti-pattern instance (line range or section name), name the lever (script extraction, `num_results` nudge, field projection, response-style discipline), and let the author apply the lever. The fix is structural (extract to script, add a sentence, restructure tool prose) — the author owns where and how. Format spec for the (unused-here) rewrite block lives in [`suggested-rewrites.md`](./suggested-rewrites.md).

## Notes for Implementers

- The escalation predicates are calibrated against fleet data — body ≥100 lines and ≥3 chained blocks are the thresholds at which the cost mechanism compounds measurably across thousands of sessions. Don't loosen them without new evidence.
- Cost is the most likely category to grow new finding types over time (new MCP servers, new model behaviors). Each new pattern should be backed by a concrete example demonstrating the cost mechanism before it lands in this rubric — the out-of-rubric channel collects candidates for periodic review.
