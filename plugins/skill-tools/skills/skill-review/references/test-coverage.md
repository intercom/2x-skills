# Test Coverage — Detailed Criteria

## Scope

Required evals exist for skills with broad reach. Behavioral and structural coverage match the skill's claimed scope. Operational guardrails declared anywhere in the skill (SKILL.md or any reference file) are exercised by at least one eval.

## When This Applies

Severity tiers in scope: **Major**, **Minor**.

- **Major** — required evals missing entirely on a widely-shared skill, OR an operational guardrail declared anywhere in the skill (SKILL.md or any reference file) is not exercised by any eval, OR an eval asserts behaviour the skill no longer implements (a stale eval that now validates *incorrect* output — false confidence), OR an eval that runs green without actually exercising the behaviour it claims to test (a false-coverage eval), OR a `trigger-evals.json` suite on a skill whose frontmatter sets `disable-model-invocation: true` (the suite asserts a routing path the skill has turned off). The stale-eval, false-coverage, and trigger-evals-on-non-autofire cases are Major regardless of reach, because the harm (a green check on wrong or untested behaviour) doesn't depend on adoption. The operational-guardrail-untested case is likewise Major regardless of reach when the guardrail governs an **irreversible or destructive action** (purge, delete, kill-switch enable, force-merge, any mutation) — the personal/project-local carve-out below does not shield those.
- **Minor** — missing evals on a personal or project-local skill (the floor for low-reach skills), OR eval-quality gaps (eval IDs out of sequence, missing structural mirror for a behavioral guardrail, wishlist coverage, a discipline guardrail whose eval never applies pressure).

## When Evals Are Required

Eval requirements scale with **reach** — how many people and sessions depend on the skill. The reviewer must apply this table verbatim — flagging missing evals as Major on a low-reach skill is a false positive.

| Reach | Evals | Reason |
|--------|-------|--------|
| Widely shared — published in a plugin or marketplace, depended on by many engineers | **Required** (Major if missing) | Broad adoption, low tolerance for noise |
| Team-scoped — shared within one team | **Highly recommended** (Minor if missing) | Reduces regression risk; daily use provides some feedback but doesn't catch quality drift |
| Experimental / still proving value | Highly recommended | Evals are the cheapest signal that a skill works |
| Personal / project-local | Optional | Owned by one person or one repo; issues surface through use |

**Why "highly recommended" is the floor for lower-reach skills.** Evals are the only mechanism that catches behavioral regressions when a skill is modified. A shared skill without evals is one careless prompt edit away from breaking silently. Flag the absence as **Minor** to surface it without escalating beyond the rubric — the owner makes the call, but the absence should be visible in every review.

## Finding Types

### New widely-shared skill lacks evals

**Pattern.** A newly-added SKILL.md that is widely shared (published in a plugin/marketplace) has no evals in either supported location (skill-local `evals/` or a repo-root test suite).

**Detection.** Read the diff status provided for the review. When a SKILL.md entry has status `A` (added) or `R<score>` (renamed into scope), glob both eval locations: the skill-local `evals/` directory and the repo-root test suite for that skill (e.g. `evals/<snake>/`, mapping kebab→snake: `name.replace('-', '_')`). If neither exists, flag this finding. Modifications to existing skills (`M`) are grandfathered under the separate finding below.

**Severity.** Major.

**Deterministic.** Yes — directory existence + diff-status classification (`A` / `R<score>` vs `M`).

**Fix.** Add either:
- a skill-local `evals/evals.json` with at least 3 cases (golden + edge + negative), or
- a structural test suite (e.g. a pytest suite) with assertions on tool-call shape.

### Existing widely-shared skill lacks evals

**Pattern.** A widely-shared skill predates the evals-required expectation and has no evals in either location. Should still be surfaced even though it was not caught when it was added.

**Severity.** Major.

**Deterministic.** Yes — directory-existence check (both eval locations absent).

**Fix.** Same as the net-new case — add evals. Use the skill's documented behaviors to derive eval scenarios.

### Operational guardrail untested

**Pattern.** The skill declares — in SKILL.md *or any reference file* — a "never X" / "always Y" rule that governs the skill's *output correctness on real inputs* (e.g. "do not flag runtime-namespace agents as broken references", "reject code-only analysis when logs are available") AND no eval anywhere exercises it. The predicate is not scoped to the SKILL.md body: a guardrail declared only in a reference file is fully in scope, which is exactly why the Detection step below enumerates across every file.

**Detection — enumerate, then cross-check; do not sample.** This is the single most under-fired finding in the rubric, and the cause is always the same: the reviewer spot-checks a couple of obvious rules instead of enumerating all of them. Work in two explicit steps:

1. **Enumerate every guardrail.** Scan SKILL.md *and every reference file* for each "never X" / "always Y" / "must Y" / "do not X" rule that governs output correctness on real inputs. Build the full list — a guardrail you never enumerated is a guardrail you cannot check. Guardrails hide in reference files and bundled-script comments, not just the SKILL.md body.
2. **Cross-check each against the evals.** For *each* enumerated guardrail, look for an eval (in `evals/evals.json` or the repo-root test suite) whose case would **fail if that specific rule were violated**. An eval that merely operates in the same area does not count — the assertion has to be sensitive to the rule. Flag every guardrail with no such eval.

Passing Test Coverage is a claim that you enumerated the guardrails and found each one covered — not that nothing looked wrong. A skill with N guardrails and an eval suite that happens to be green is the *typical* shape of this miss, not evidence against it.

**Severity.** Major.

**Deterministic.** No — distinguishing "operational guardrail governing correctness" from "style rule" requires judgment about the skill's intent. The boundary below names the test but doesn't make it mechanical.

**Fix.** Add a behavioral eval in `evals.json` that gives Claude a prompt where violating the rule would produce a wrong answer, and assert Claude follows the rule.

**Boundary.** Rules governing output format, tone, writing style, or rewrite mechanics ("be concise", "describe the hook, don't write it", "keep rewrites copy-pasteable", "don't invent new content") are NOT the operational-guardrail-untested predicate — they're Minor. Ask: would a reviewer following this rule produce a different *correctness verdict* than one who ignored it? If no, it's style, not an operational guardrail.

**Reach.** This finding is **not** the whole-skill missing-evals finding and is **not** shielded by the low-reach carve-out below. It is especially Major-regardless-of-reach when the untested guardrail governs an **irreversible or destructive action** — a queue purge, a delete, a kill-switch enable, a force-merge, any mutation, a "refuse the dangerous request" gate. A low-reach skill that ships a destructive guardrail with no eval gets the Major regardless: the cost of a silent regression there is a real production action, not a noisy review. (Ordinary, non-destructive guardrails on low-reach skills still warrant the finding, but the destructive case is the one the carve-out must never swallow.)

### Guardrail eval never applies pressure (`finding_type`: `guardrail-eval-unpressured`)

**Pattern.** A **discipline guardrail** — a rule whose whole job is to make Claude resist a temptation (don't skip the review step, don't force-merge, don't answer before reading the logs) — *does* have an eval that exercises the rule's triggering condition and asserts compliance, but only in a neutral frame. It never presents the pressure that would tempt a violation, so it proves the skill behaves when nothing is pushing against it, not that the guardrail *holds*. A discipline rule's failure mode is precisely "folds under pressure while behaving fine in neutral conditions" — a neutral-scenario eval is structurally blind to it and gives false confidence. A discipline eval must recreate the temptation, ideally combining several pressures (a deadline, sunk cost, an authority nudge), and assert the guardrail still holds.

**Detection.** For each discipline guardrail that *does* have an eval, read the eval's prompt: does it apply adversarial pressure toward violating the rule, or does it just ask Claude to do the task in a neutral frame? A prompt with no temptation is unpressured.

**Severity.** Minor — this is an eval-quality gap, not a coverage hole. The guardrail is exercised, just softly.

**Deterministic.** No — judging whether a prompt applies real pressure toward the violation is judgment.

**Fix.** Describe in prose the pressured case to add: a scenario that combines concrete pressures (deadline, sunk cost, authority) and forces an explicit choice, asserting Claude holds the guardrail and does not rationalize past it.

**Boundary with `operational-guardrail-untested`.** The split is whether any eval exercises the guardrail's *triggering condition* — the state the rule governs. If no eval ever puts the skill in that state (the temptation is never even set up), nothing is sensitive to a violation → `operational-guardrail-untested` (Major); happy-path-only coverage of a destructive or irreversible action is effectively no coverage and stays Major there. This finding is the narrower case: an eval *does* exercise the triggering condition and asserts compliance, but in a neutral frame with no pressure toward the violation. Once the triggering condition is exercised, the remaining gap is pressure rather than coverage, so it is `guardrail-eval-unpressured` (Minor) regardless of stakes.

### Eval asserts stale behaviour (Major)

**Pattern.** An eval's expectations describe behaviour the skill no longer implements — the skill was changed (a flow rewritten, an output format swapped, a tool migrated) but its evals weren't updated. The eval now codifies the *old* behaviour, so it passes when Claude does the wrong thing and fails when Claude does the right thing. Example: a skill switched from a remote-doc export to a local-HTML export, but an eval still asserted the remote-doc flow.

**Detection.** Read each eval's expectation against the skill's current documented behaviour and check whether they agree. This requires judgment — the reviewer reads the eval file and the current SKILL.md body and recognises when they disagree.

**Severity.** Major — regardless of reach. This is NOT an eval-quality nit; a stale eval is worse than a missing one, because a missing eval is honestly silent while a stale eval gives a false green check on incorrect output. Do not file it under the Minor eval-quality bucket below.

**Deterministic.** No — judging "the eval expects behaviour the skill no longer does" requires understanding both the eval and the current skill body.

**Fix.** Update the eval's expectation to match the skill's current behaviour, and confirm the assertion would now fail on the *old* behaviour (otherwise it isn't testing the change). Describe the corrected expectation in prose; do not regenerate the eval JSON wholesale.

**When it fires.** Stale evals arise from *modifying* a skill without updating its evals, so this finding is most relevant when the skill is being changed in the current PR (diff status `M`). The single-pass review always reads the eval files against the current SKILL.md, so the finding is reachable whenever the skill ships evals — there is no triage gate that could pass a modified-with-evals skill before its evals are read.

### Eval proves nothing (false-coverage eval) (Major)

**Pattern.** An eval is present and passes, but it doesn't actually exercise the behaviour it claims to test — so its green check is false confidence, the same harm as a stale eval. Two shapes seen in practice:

- **Answer scaffolded into the prompt.** The eval's prompt preamble already states the rule or hands Claude the resolved answer, so the case tests whether Claude can *read the prompt*, not whether the *skill* teaches the behaviour. Example: a "detect the self-contradiction" eval whose prompt pre-states which instruction is correct; or a guardrail eval that scaffolds "(remember: never create labels)" into the prompt that the skill body is supposed to supply.
- **Tests the wrong component.** The eval asserts behaviour of a *different* unit than the skill under test — e.g. an orchestrator skill's eval that asserts what the dispatched *worker* does internally, rewarding a hallucinated worker contract and passing even when the orchestrator itself is wrong.

**Detection.** Read each eval's prompt and expectation against the skill body. Ask: if the skill body were blanked out, would this eval still pass on prompt-content alone? If yes, the prompt is carrying the answer. And: does the assertion target the skill being reviewed, or some other unit it merely dispatches?

**Severity.** Major — regardless of reach. A false-coverage eval is worse than a missing one for the same reason a stale eval is: it shows green while proving nothing, so a real regression slips through silently. Do not file it under the Minor eval-quality bucket below.

**Deterministic.** No — judging "the prompt already contains the answer" or "this asserts the wrong unit" requires reading the eval and the skill body together and reasoning about what the case actually exercises.

**Fix.** Move the behaviour-defining content out of the prompt and into reliance on the skill (the prompt should pose the situation, not pre-resolve it), and re-target the assertion at the skill under review. Confirm the case would now *fail* if the skill's rule were removed — that's the test that it tests anything. Describe the corrected case in prose; do not regenerate the eval JSON wholesale.

### Trigger evals on a skill that can't auto-fire (Major)

**`finding_type`: `trigger-evals-on-non-autofire-skill`** — pinned explicitly because this finding is deterministic and the determinism eval asserts finding-set stability by identifier.

**Pattern.** `evals/trigger-evals.json` is present while the skill's frontmatter sets `disable-model-invocation: true`. Trigger evals assert that the skill's description auto-fires it from natural-language prompts — the exact path `disable-model-invocation: true` turns off. The suite is therefore a contradiction: it either fails permanently (CI noise) or passes without exercising a reachable path (false coverage, the same harm as the false-coverage finding above). `trigger-evals.json` is meaningful only for auto-fired skills. The usual origin is a skill flipped to slash-command-only without its eval suite being cleaned up.

**Detection.** Mechanical: the frontmatter contains `disable-model-invocation: true` AND `evals/trigger-evals.json` exists in the skill's eval directory. `evals.json` behavioural evals are unaffected — they test the loaded skill's reasoning, not routing, and remain required regardless of invocation mode.

**Severity.** Major — regardless of reach, same family as the stale-eval and false-coverage findings.

**Deterministic.** Yes — a frontmatter field read plus a file-existence check.

**Fix.** If the flip to slash-command-only is intended, delete `evals/trigger-evals.json` (keep `evals.json`). If the skill *should* auto-fire, remove `disable-model-invocation: true` instead. Never resolve it by weakening the trigger evals to pass without routing.

**Boundary.** File existence is the whole predicate on purpose — there is no salvageable trigger-evals.json on a `disable-model-invocation: true` skill, so no per-case inspection is needed. Positive cases (`should_trigger: true`) can never pass: the field keeps the description out of the router's context entirely. Negative cases (`should_trigger: false`) pass vacuously for the same reason, so even a negative-only suite proves nothing about description broadening — the description isn't competing in the router at all. An author who wants to keep negative routing checks has set the wrong field: remove `disable-model-invocation: true`, don't keep the suite.

### Eval quality issues (Minor)

- Behavioral eval IDs non-sequential — **deterministic** (numeric sequence comparison)
- Missing structural mirror for a behavioral guardrail — **not deterministic** (judgment about which behavioral evals merit a structural regression test)
- `trigger-evals.json` missing negative cases for adjacent queries that shouldn't trigger this skill — **not deterministic** (judgment about which adjacent queries warrant a negative case)

## How to Write Good Evals (out of rubric scope)

Tutorial content on eval file types, eval archetypes, what makes an eval good vs bad, and the hook trick for eval-trigger reliability lives in your project's eval-authoring guide and the skill-creation workflow. This rubric reference does NOT teach how to write evals — it only enumerates the finding types a reviewer flags. If the reviewer is asked "how should I write this eval?", redirect to that guide.

## Out of Scope / False-Positive Guardrails

- **Eval requirements vary by reach — but this carve-out is about *whole-skill* missing evals only.** Don't flag a personal / project-local / experimental skill for having *no eval suite* — only widely-shared skills are gate-enforced for that. The carve-out does **not** extend to: an untested **destructive/irreversible** operational guardrail, a **stale** eval, a **false-coverage** eval, or a **trigger-evals suite on a `disable-model-invocation: true` skill** (all Major regardless of reach). Those harms don't depend on adoption, so reach doesn't excuse them.
- **The operational-guardrail-untested predicate has a tight boundary.** Style rules ("be concise", "don't paraphrase") are not operational guardrails. Only flag it when violating the rule would change a *correctness verdict*, not the format of the output.
- **One eval location is enough.** A skill that has `evals/evals.json` but no repo-root test suite (or vice versa) is fine. Both is ideal but not required.

## Rewrite Policy

**Do not produce a suggested rewrite for Test Coverage findings.** Eval scenarios depend on the skill's actual operational guardrails — the reviewer can't generate eval JSON without knowing the skill's failure modes deeply. Describe the eval the author should add in prose: "Add a behavioral case where Claude is asked X; assert the response Y, because the skill's rule Z would otherwise be violated." That's enough for the author to write the case themselves. Format spec for the (unused-here) rewrite block lives in [`suggested-rewrites.md`](./suggested-rewrites.md).

## Notes for Implementers

- Diff-status classification for the net-new finding: `A` means the file was added, `R<score>` means it was renamed into scope (e.g. renamed from another plugin). `M` (modified) means the skill already existed — route to the grandfathered finding instead, not the net-new one. This distinction matters: flagging a modified skill as "new skill lacking evals" is a false positive.
- The kebab→snake mapping for repo-root eval directories is `name.replace('-', '_')` — `acme-tools` → `evals/acme_tools/`.
