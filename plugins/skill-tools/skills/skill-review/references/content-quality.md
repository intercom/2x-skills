# Content Quality — Detailed Criteria

## Scope

Whether the body provides project-specific context Claude couldn't know, or over-prescribes step-by-step procedures Claude could derive itself.

This category is about **what's in the body** — context vs instructions. It does NOT cover *how the skill fires* (hook integration moved to [`convention.md`](./convention.md) because triggering is a placement/triggering concern, not a content-quality concern).

This category lives entirely in AI judgment. Detection requires understanding what counts as "context Claude couldn't know" vs "instruction Claude could derive."

## When This Applies

Severity tiers in scope: **Critical** (rare), **Major** (rare), **Minor** (typical).

- **Critical** — declared procedure produces wrong or dangerous output on normal inputs.
- **Major** — procedure smell OR a weak completion criterion, WITH a citable concrete behavior it causes. Don't escalate on taste alone.
- **Minor** — procedure smell, a weak completion criterion, or a no-op instruction, without concrete consequence; over-prescription patterns.

## Determinism

**Every finding type in this category is judgment-bound** (`deterministic: false`). Detection requires distinguishing context from instruction and judging whether a numbered list is "procedure smell" vs "checklist of things to verify". Rerun variance is expected; the determinism eval explicitly filters Content Quality findings out of its tuple-equality assertion — it only asserts equality on the deterministic subset across all categories.

---

## Context vs Instructions — The Core Distinction

Good skills provide **context Claude couldn't know without the skill author**. Bad skills provide **step-by-step procedures Claude could figure out on its own**.

Claude already knows how to query APIs, write migrations, parse logs, and follow standard workflows. What it doesn't know:

- How a particular project has configured its tools (environments, datasets, column names)
- Project-specific conventions and quirks that differ from standard setups
- Known footguns and workarounds specific to this codebase or infrastructure
- Which tools/datasets/endpoints to use for which scenarios

### Good Context Examples

**Telemetry/observability skill** — tells Claude project-specific configuration:
> Always query with `env: "live"` (NOT "production" — the tool stores it as `live`). Dataset: `svc-metrics`. The fields `latency_ms`, `route`, and `tenant_id` are always present; `session_id` only appears on user-facing spans. When querying DB-level span fields, do NOT filter on `is_entrypoint=true` — those attributes live on child spans.

This is perfect: environment names, dataset names, column availability, and an exception rule that Claude couldn't derive from the tool's generic documentation.

**Tooling skill** — warns about a known tool bug:
> An MCP tool whose fully-qualified name exceeds the runtime's 64-character limit fails to register and can crash the session — prefer a shorter-named alias if the server offers one.

This is the kind of footgun context that saves hours of debugging.

**Create-migration skill** — documents a project's framework quirks:
> This project uses advisory locks for migrations. The managed database doesn't support foreign keys. Always use `algorithm: :instant` when available.

These are deviations from the framework's standard behaviour that Claude would get wrong without this context.

### Bad Context Examples (Procedure Smell)

**Over-prescribed deployment checker:**
> 1. First, open the deploy tool and check the deployment status
> 2. Then, look at the pipeline stages
> 3. Next, check if there are any locked stages
> 4. If a stage is locked, check who locked it
> 5. Then check the approval status
> 6. Finally, check the rollback history

This is procedure smell. Claude already knows how to use the deploy tool's MCP tools. The skill should instead tell Claude what's *unusual* about this project's deployment pipeline — which stages tend to get stuck, what locked stages mean organizationally, common deployment quirks.

**Over-prescribed query workflow:**
> Step 1: Open the telemetry tool. Step 2: Select the `svc-metrics` dataset. Step 3: Add a filter for env=live. Step 4: Set the time range to last 1 hour.

Compare with the good version above. Same information, but the good version gives configuration facts while the bad version gives instructions.

### Procedure Smell Heuristics

Flag a skill when:

- **Numbered step lists** dominate the content ("Step 1:", "Step 2:", "1.", "2.", "3.")
- **Sequential instructions** assume a specific order ("First... Then... Next... Finally...")
- **The content reads like a tutorial** rather than a reference
- **Removing the steps would leave no content** — if the only value is the ordering, the skill is over-prescribing
- **Each step describes something Claude already knows** — "open the tool", "select the option", "click the button"

Do NOT flag when:

- Steps describe a genuinely non-obvious order that matters (e.g., "run migration before seeding because advisory locks require it")
- The procedure encodes project-specific workflow requirements, not generic tool usage
- The numbered list is a checklist of things to verify, not a procedure to follow

### The Composability Principle

Skills are composable context blocks — Claude mixes and matches them to accomplish tasks. A skill that tries to orchestrate an entire workflow from end to end is fragile. Skills should provide the building blocks (context, configuration, known-issues) and let Claude compose the workflow based on the user's actual request.

When a skill violates this:

- Claude may skip steps it deems unnecessary (and often it's right to)
- The skill becomes brittle when workflows change
- The skill can't be combined with other skills effectively
- Users get frustrated when Claude follows the rigid procedure instead of adapting

### Temporal Self-Reference — Edit History in the Body

Skills accumulate edit-history phrasing as they're iterated: "X **now** does Y", "this **no longer** does Z", "we **switched** to W", "that bug **is fixed**, so it returns cleanly". The change was interesting to the author at the moment of editing, but the consumer never saw the prior version — to them the "now / no longer" frame is dead weight, and worse, it rots: the "now" is true only relative to an edit nobody reading the skill can see. Skill bodies should read in **timeless present tense** — state that *X does Y*.

A skill's own change history already lives in version control (and, for plugins, a derived changelog). The body is the wrong place either way — a self-referential "we changed X to Y" duplicates that history where nothing keeps it in sync. The fix is to drop the edit-history phrasing, not to relocate it: version control is the source of truth.

**Two kinds of temporal phrasing — only the first is a finding. The deciding factor is whether the consumer collides with the "before", NOT whether the change is about the skill itself:**

| Kind | Does the consumer still meet the "before"? | Typical subject | Action |
|------|--------------------------------------------|-----------------|--------|
| **Self-reference / dead edit-history** | No — the old state lived only in a past revision of the skill, or is otherwise invisible to the reader (they just use the current form). | usually the skill / its script, but also an external system whose change the skill merely narrates ("the upstream service **now** supports X") | **Flag.** Flatten to present tense. |
| **World-state** | Yes — the old form is still live (old catalog rows, deployed configs, an endpoint that still 405s) and the consumer hits it. | an external entity: a renamed table, a moved endpoint, a deprecated flag. | **Do not flag.** The before→after mapping is reconciliation knowledge. |

**The distinguishing test:** *does the "before" state still exist somewhere the consumer will encounter it?* If yes — old catalog rows, deployed configs, historical dashboards, an endpoint that still 405s — keep the mapping; it's content. If the "before" only ever existed in a prior revision of the skill text, it's edit history; flatten it.

World-state phrasing to **leave alone** (the mapping is the payload):

- "the `incidents` table was renamed to `issues`" — an agent querying the warehouse will see both names; the alias is the Rosetta stone.
- "the API moved its MCP endpoint from `/api/ai/mcp` to `/api/mcp/public`; the old path now returns HTTP 405" — the skill's job is to fix stale configs that still point at the old path.
- "(formerly 'Free tier')", "(formerly % Actioned)" — aliases the consumer meets in existing reports.

Self-reference to **flag and flatten**:

- "that bug is fixed, so it now returns cleanly" → "returns cleanly" (or drop entirely if the working behaviour is already stated).
- "the upstream service now supports SSO as a first-class option" → "supports SSO as a first-class option".
- "do not assume the script shortens the line — it no longer does" → "it does not".

**When the framing wraps a load-bearing fact, keep the fact — flatten only the framing.** Self-reference often rides on top of a real current-state fact (an ordering constraint, a config value, a reason). "We switched the dedup step to run before enrichment" carries an ordering constraint that still governs behaviour — flatten to "Dedup runs before enrichment", do not drop the sentence. Drop a sentence wholesale only when nothing but edit history remains once the framing is gone (e.g. a since-fixed bug whose working behaviour is already stated elsewhere).

Severity: **Minor** by default (cosmetic rot). Escalate to **Major** only when the stale "now" actively misleads — e.g. "now returns cleanly" describing behaviour that has since regressed, where the temporal claim asserts something currently false.

**Out of scope / false-positive guardrails — do NOT flag:**

- **Explicit changelog / version-history sections** (`## Changelog`, `**v0.2.0** — …`). Temporal phrasing is correct there — that's the one place edit-history belongs. (Whether such a section should live in the body at all is a separate, larger question; note it, don't flatten it.)
- **World-state changes** (the right column above).
- **Domain vocabulary** — "No longer relevant" as a triage *verdict*, "used to filter" in its *purpose* sense, "has since changed" as a *conditional the skill reasons about* ("if the code has since changed, …").
- **Dated provenance with an audit trail** — "(added 2026-04-27)" attached to a fact the author deliberately timestamped so a maintainer can judge staleness. That's a knowledge-base convention, not rot.

The finding type is `temporal-self-reference` (`deterministic: false` — distinguishing self-reference from world-state needs the judgment of "does the old form still exist out there?", which a regex can't make).

### Generating Suggested Rewrites

When a review flags procedure smell or poor context quality, **generate a concrete rewrite of the problematic section** — don't just describe the problem. Authors ignore abstract feedback ("this has procedure smell") but act on tangible alternatives they can copy-paste.

**The Rewrite Method:**

To transform a procedural section into context:

1. **Extract the facts** — What does Claude learn from each step that it couldn't infer? Dataset names, column names, environment values, tool quirks, known gotchas.
2. **Discard the choreography** — Remove ordering words ("First", "Then", "Next"), generic tool instructions ("Open the tool", "Run the query"), and anything Claude already knows how to do.
3. **Restructure as reference** — Present the extracted facts as declarative statements, tables, or constraint lists.

**Rewrite Example — Deployment Checker:**

Before (procedure smell):
```markdown
## Checking Deployments

1. First, open the deploy tool and check the deployment status using `deploy_find`
2. Then, look at the pipeline stages with `deploy_list_pipeline_stages`
3. Next, check if there are any locked stages with `deploy_locked_stages`
4. If a stage is locked, check who locked it and why
5. Then check the approval status with `deploy_approvals`
6. Finally, check the rollback history with `deploy_rollback_history`
```

After (context):
```markdown
## Deployment Context

- **Stuck stages**: The `asset-compile` stage is the most common bottleneck — it can take 15-20 minutes. If it's been longer, check for OOM kills in the sub-deployment logs.
- **Locked stages**: A locked production stage usually means someone is actively investigating an incident. Check the incident channel before attempting to unlock. Only on-call can unlock production.
- **Approval flow**: Deployments need approval from the PR author's team lead for production stages. Staging auto-approves. If approval is missing, the author may have merged from a fork (no team association).
- **Rollback signals**: If `deploy_rollback_history` shows >2 rollbacks in the last hour for the same app, there may be an active incident — check the deployment's incident thread before re-deploying.
```

**What to include in the suggested rewrite:**

- Be a **complete replacement** for the flagged section — ready to copy-paste into SKILL.md
- Preserve all project-specific facts from the original (don't lose real context buried in procedure)
- Be shorter than the original (removing choreography naturally reduces length)
- Use declarative structure: tables, constraint lists, "when X, Y applies" patterns
- Include section headers that match the original so the author can do a clean swap

**What NOT to include:**

- Don't invent context that wasn't in the original — only restructure what's already there
- Don't add new recommendations beyond what the skill already covers
- Don't change the skill's scope or intent

---

## Beyond Procedure Smell — Completion Criteria and No-Ops

Procedure smell is over-prescription of *steps*. Two adjacent defects over-prescribe nothing yet still degrade a skill: a fuzzy stop condition, and a line that restates a default. Both are Content Quality (they're about what's in the body), both are judgment-bound, and both are under-fired — nothing jumps out on a first read, so the skill looks fine until you ask the no-op test of each instruction.

### Weak completion criterion (`finding_type`: `weak-completion-criterion`)

**Pattern.** A skill drives a multi-step or open-ended task but its stop condition can't distinguish *done* from *not-done* — "review the code", "produce a change list", "investigate until you understand it", "leave the code in good shape". When the criterion is fuzzy, Claude's attention slips to the finishing state and it declares completion early (premature completion): the work reads as finished without being finished. (A criterion that is *already* both observable and exhaustive for the task it gates — "all tests pass" for a test-fixing skill whose whole job is the suite — is not this finding; the defect is a criterion that is unobservable *or* observable-but-under-scoped, not the mere presence of a final step.)

**Fix.** Sharpen the criterion into something **checkable** (done vs not-done is observable) and **exhaustive where it matters** ("every model touched in this PR has a corresponding migration entry", not "produce a change list"). When a *later* step is what tempts the early exit — Claude races to the visible finish and skips the legwork of the current one — the structural fix is to split the sequence so the current step must close before the next becomes visible; name that split in the fix.

**Severity.** Minor by default. **Major** when you can cite a concrete behavior the fuzzy criterion causes (an eval or fixture where Claude stopped short). Same "don't escalate on taste" bar as procedure smell.

**Deterministic.** No — judging whether a stop condition is checkable-and-exhaustive vs fuzzy is judgment-bound.

**How to spot it.** Find the skill's completion language — "report your findings", "when done", "produce X", the last step of a numbered list. Ask two questions: (1) could two reasonable runs disagree on whether the task is finished (unobservable)? and (2) could a run satisfy the criterion while leaving load-bearing work the skill is responsible for undone (observable but under-scoped — e.g. "all migration files reviewed" when the real job is classifying every statement)? If either holds, and the skill drives real work (not a pure-context block), it's a weak criterion.

### No-op instruction (`finding_type`: `no-op-instruction`)

**Pattern.** A body line instructs behavior Claude already does by default — "be thorough", "think carefully", "use good judgment", "make sure your answer is correct", "be helpful". It pays context tokens to say nothing and dilutes the load-bearing instructions next to it. A weak leading word ("be thorough") is the common shape: the line names a virtue the model already aims at, so it changes no behavior.

**The no-op test.** Run it on each sentence in isolation: *would removing this sentence change Claude's behavior versus its default?* If not, it's a no-op — delete the whole sentence rather than trimming words from it.

**Fix.** Delete the line. If the author actually wanted *more* than the default — real extra thoroughness, not the baseline — restating the default won't get it: replace the weak word with a strong leading word that genuinely shifts behavior ("exhaustively enumerate every X", "relentless"), or attach a concrete, checkable bar. The technique stays; the no-op wording goes.

**Severity.** Minor.

**Deterministic.** No — deciding a line restates the default (vs carries project-specific teeth) is judgment.

**How to spot it.** Scan for exhortations with no project-specific object: adjectives of diligence ("careful", "thorough", "diligent"), generic quality reminders ("ensure correctness", "do a good job"). A line is a no-op only when stripping it leaves behavior unchanged — an exhortation tied to a real footgun ("be careful: the managed database silently drops the FK") is context, not a no-op.

---

## Out of Scope / False-Positive Guardrails

- **Numbered checklists are not always procedure smell.** A checklist of *things to verify* (not steps to perform in order) is fine — it's a reference structure, not a runbook.
- **Sequential steps for genuinely sequential dependencies are not procedure smell.** "Run the migration before seeding because advisory locks require it" is real ordering context Claude couldn't derive.
- **Hook integration is NOT a Content Quality finding.** Whether a skill should auto-fire on a file write, command, or tool invocation is a placement / triggering concern. See [`convention.md`](./convention.md) § Hook Integration.
- **A fuzzy-sounding criterion in a pure-context skill is not `weak-completion-criterion`.** A context/reference block has no task to complete — there's no step whose stop condition could be premature. Fire only when the skill drives real multi-step work.
- **Emphasis tied to a project-specific footgun is not a no-op.** "Be careful — advisory locks make this non-reentrant" carries teeth Claude couldn't derive. The no-op test fails only when removing the line changes nothing versus default behavior.

## Rewrite Policy

**Produce a suggested rewrite for every procedure-smell / vague-context / `temporal-self-reference` finding that touches SKILL.md.** For `temporal-self-reference`, the rewrite restates the sentence in present tense — keeping the facts that still describe current behaviour and dropping the edit history itself (what changed, the prior behaviour, a since-fixed bug). The edit history is not a current-state fact, so dropping it is not "losing a fact": e.g. "filtering used to time out from a bug that is now fixed, so it returns cleanly" reduces to "filtering returns cleanly" (or to nothing, if that is already stated elsewhere). This is the category where rewrites are most load-bearing — abstract feedback ("this is procedure-smell") doesn't move authors, but a concrete replacement section does. The Rewrite Method earlier in this file is the authoring guide; [`suggested-rewrites.md`](./suggested-rewrites.md) owns the format spec (collapsible block, placement, authoring constraints).

**`weak-completion-criterion` also gets a suggested rewrite** — the sharpened, checkable criterion is concrete and copy-pasteable, so it carries the same load-bearing value. **`no-op-instruction` gets prose only by default** ("delete lines X–Y — they restate the default"); attach a `suggested_rewrite` only when the fix is a strong-leading-word replacement rather than a deletion, in which case the rewrite is the replacement line.

## Notes for Implementers

- Content Quality is the category with the highest false-positive risk. Detection lives entirely in AI judgment because "is this context Claude couldn't know?" requires understanding the broader domain.
- The Suggested Rewrites mechanism is a key product of this category — see `references/suggested-rewrites.md` for format/authoring constraints. The rewrite is the actionable artifact; the finding alone is too abstract to act on.
