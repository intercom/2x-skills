# Convention — Detailed Criteria

## Scope

Placement + triggering. Six concerns live here:

1. **Placement** — where a skill lives (personal, project, or a shared plugin).
2. **Similar-skill duplication** — whether another skill in scope covers the same job.
3. **Hook integration** — whether a deterministic trigger event would improve how the skill fires.
4. **Repo-convention adherence** — does the skill follow the repo's own documented frontmatter/authoring conventions.
5. **Skill-vs-script shape** — whether a skill is built as an end-to-end deterministic orchestrator when it should be a thin context block over a bundled script.
6. **Invocation mode** — whether a skill that can't usefully auto-fire (slash-command-only, or a sealed-input sub-routine) is needlessly shaped for it, paying description budget + router noise for discovery it never uses.

## When This Applies

Severity tiers in scope: **Major**, **Minor**.

- **Major** — skill in a clearly-wrong location (the wrong-placement predicate), unambiguous duplicate skill should be merged, a description that carries _no routing signal at all_ (pure feature inventory with nothing a router can match on), a skill shaped as an end-to-end deterministic orchestrator (the orchestration-shaped-skill predicate, Major by default), or a widely-shared skill that can't usefully auto-fire shipping a full multi-trigger auto-fire description (the invocation-mode-mismatch escalation).
- **Minor** — similar-skill differentiation suggestions, hook-integration opportunities, convention drift (frontmatter field violations), a description that leads with a feature list but still contains some trigger signal, a single extractable chain in an otherwise context-rich skill (prefer Cost's `scriptable-bash-chain` for that case), or a skill that can't usefully auto-fire still shipping a multi-trigger auto-fire description (the invocation-mode-mismatch default).

## Determinism

Convention findings are mostly judgment-bound. Placement requires deciding whether referenced tools/datasets/workflows are broadly applicable; similar-skill detection surfaces candidates by reading, but the merge/differentiate/leave-alone verdict is judgment; the description-as-routing-signal finding is judgment (distinguishing a feature inventory from a purpose statement); the repo-convention frontmatter-field check is the lone deterministic finding in this category (a field-value comparison against a documented rule).

---

## Skill Placement (the wrong-placement predicate)

### Decision Tree

Evaluate a skill's placement by matching its content scope to the right location:

| Content Scope                                            | Correct Location                                    |
| -------------------------------------------------------- | --------------------------------------------------- |
| Personal workflow, individual preferences                | Local `~/.claude/skills/` on the engineer's machine |
| Unproven, might help others, or new to one team          | Its own new plugin, or a team plugin                |
| Team-specific workflows or data (cross-repo)             | A team plugin                                       |
| Broadly useful workflow or tool (cross-repo, cross-team) | A widely-shared plugin published to a marketplace   |
| Specific codebase context                                | Repo-level `.claude/rules/` or `.claude/skills/`    |

### Rule of Thumb

If the skill only makes sense in one codebase, it belongs in that repo. If it works across repos but only for one team, it belongs in a team plugin. If it would help every engineer, it belongs in a broadly-shared plugin.

### Common Misplacements

**General content in a team plugin.** Signal: the skill's content is about general development practices (debugging, testing, code review) but lives in a team-specific plugin. Fix: move to a broadly-shared plugin, or add team-specific context that justifies the placement.

**Team-specific content in a broadly-shared plugin.** Signal: the skill references team-specific tools, datasets, or workflows that most engineers wouldn't encounter. Fix: move to the appropriate team plugin. If the team doesn't have a plugin yet, suggest creating one. Severity: **Major** (the wrong-placement predicate). **Deterministic:** No — "team-specific" requires judging whether the referenced tools, datasets, or workflows have broad applicability.

**Repo-level content in a plugin.** Signal: the skill's context is tightly coupled to a specific codebase — file paths, class names, architecture patterns that only make sense in one repo. Fix: move to the repo's `.claude/skills/` or `.claude/rules/` directory.

### Rules vs Skills

A rule is a simplified skill — context triggered when a specific part of the codebase is accessed. Consider a rule instead of a skill when:

- The context applies only to specific files or directories
- There's no need for references, scripts, or examples
- The content is short (a few paragraphs)
- The trigger is file-path-based, not intent-based

Rules live in `<repo>/.claude/rules/` and are simpler to maintain than full skills.

### Promotion Criteria

When a repo- or team-specific skill grows to wide adoption, consider promoting it to a broadly-shared plugin:

- Multiple teams or repos would benefit from the same context
- The skill's content is generalizable beyond one codebase

### New / unproven skills

Don't dump a new or unproven skill into a broadly-shared plugin prematurely — once a skill is used from a given path, users come to depend on that path and it's hard to migrate out. Recommend instead:

- **Its own new plugin** — for a standalone skill.
- **A team plugin** — when it fits an existing team's plugin.

Once several teams depend on it, it can be promoted into a broadly-shared plugin.

### Checking Placement

When reviewing a skill's placement:

1. Read the SKILL.md content and identify the scope (personal, team, broadly-useful, repo-specific)
2. Check the current location from the directory path
3. Compare scope to location using the decision tree above
4. If mismatched, recommend the correct location with reasoning
5. If the content is borderline, note that it could go either way and explain the trade-off

---

## Skill-vs-Script Shape (the orchestration-shaped-skill predicate)

**`finding_type`: `orchestration-shaped-skill`.**

The shape lens on the same smell that [`cost.md`](./cost.md) catches as `script-extractable-orchestration`. A skill is a **context block** Claude composes into a task — facts, configuration, known footguns, judgment guidance. A skill is mis-shaped when it is instead an **end-to-end deterministic orchestrator**: its dominant content is a fixed pipeline (pinned queries, a set sequence of tool/MCP calls, output templates, format conversions) that an LLM re-derives from prose every run, with genuine judgment a thin minority. That belongs as a bundled script with a thin skill on top — not as prose the model re-executes.

This is the same idea as **Rules vs Skills** above (a rule is a simplified skill) pushed one step further: when the deterministic surface is large enough to be _code_, the right container is a `scripts/` file, not a SKILL.md.

### Finding type

| Finding type                                                                                                                                | Severity            | Det? |
| ------------------------------------------------------------------------------------------------------------------------------------------- | ------------------- | ---- |
| Skill is shaped as an end-to-end deterministic orchestrator; the deterministic pipeline should be a bundled script with a thin skill on top | **Major** (default) | N    |

**Pattern.** The skill's substantive content is dominated by deterministic specification — fixed queries, hardcoded IDs/values, set call sequences, exact output templates, mechanical conversions — and the genuine judgment (fuzzy classification, NL synthesis, content-contingent decisions the author couldn't enumerate) is a thin minority. Count body **and** `references/`.

**Fix (extract-glue — never "delete the skill").** Recommend restructuring: move the deterministic pipeline into a bundled `scripts/` file the skill invokes, and keep the SKILL.md as the thin layer that runs the script and handles the judgment kernel. Name which sections are pipeline and which are kernel. Do not tell the author to remove the skill — the kernel is what keeps it a skill.

**Severity.** **Major by default** — a mis-shaped skill carries its full deterministic surface into every session's context and re-derivation, and the shape is hard to migrate once users depend on the skill path. Downgrade to **Minor** only when the orchestration is a _single_ extractable chain in an otherwise context-rich skill — and in that case prefer Cost's `scriptable-bash-chain`. No Critical.

**Deterministic.** No — estimating the glue:judgment ratio and judging "this is an orchestrator, not a context block" is judgment-bound.

**Firing bar (Major-by-default ⇒ strict).** Fire on _dominance_, not _presence_ — almost every skill has some glue. Do NOT fire when the deterministic steps feed a genuine judgment output that is the skill's product; do NOT fire on pure-context / pure-reference skills (all project-specific facts, no executed sequence — that is the ideal skill shape); do NOT fire on small skills (<100 lines measured across SKILL.md body **plus** `references/` combined — not the body alone, since glue hides in references).

**Boundary with Cost.** Same defect, two lenses: Cost (`script-extractable-orchestration`) owns the _per-session token-cost mechanism_; Convention (`orchestration-shaped-skill`) owns the _shape_ judgment ("should this be a skill at all, or a script with a thin skill?"). When a skill is mostly glue end-to-end, file **both** (one finding per category — the rubric already files two when a skill is both mispriced and misplaced). When only a single chain is extractable from an otherwise-sound skill, file Cost alone. Both share the extract-glue fix; neither ever recommends deletion.

---

## Similar Skills / Duplication Risk

Duplication is the most expensive form of skill rot — two skills in different plugins that cover the same job drift apart, surprise Claude's trigger matcher, and force authors to maintain the same project-specific facts in two places.

This dimension surfaces potential overlap between the skill under review and other skills in scope so the author can decide: **merge**, **differentiate**, or **leave alone**.

### What "Similar" Means

Similarity is not a single threshold — it's a layered signal. A pair of skills is only a rot candidate when **two or more** signals line up. A single signal alone is noise.

### Signal Hierarchy

| Signal                                                                   | Strength | Detection                                                          |
| ------------------------------------------------------------------------ | -------- | ------------------------------------------------------------------ |
| Near-duplicate sentences in `description` frontmatter                    | Strong   | Sentence-level overlap, not just shared domain words               |
| Overlapping trigger phrases (the quoted `"..."` phrases in descriptions) | Strong   | Same user-facing verb + object ("check CI status", "create a PR")  |
| Same underlying tool + same audience + same verb                         | Strong   | Both "query the warehouse for revenue", both "post a release note" |
| Identical `allowed-tools` + overlapping domain                           | Medium   | Same MCP + same reference files                                    |
| Related names with overlapping scope                                     | Medium   | `foo-data` vs `foo-query`, `investigate-X` vs `X-investigator`     |
| Same plugin + same broad domain (observability, PRs, data)               | Weak     | Not enough alone — most plugins specialize in a domain             |
| Shared trigger words but different objects                               | Weak     | Both mention "review" but one reviews PRs, other reviews skills    |

### False-Positive Patterns

These look similar but are **intentional** — flagging them is noise.

| Pattern                                            | Why it's fine                                                   |
| -------------------------------------------------- | --------------------------------------------------------------- |
| Regional variants (`-us`, `-eu`, `-au`)            | Deliberate separation for data-residency compliance             |
| Environment variants (`-experimental`, `-staging`) | Different maturity tiers                                        |
| Same domain, different backends                    | Two different observability tools — different data              |
| Same tool, different datasets                      | Same query tool over a production app vs an analytics warehouse |
| General skill + specialized workflow               | A general query skill vs a specific named runbook               |
| Same verb, different audience                      | A query skill for engineers vs one for analysts                 |

### Detection Method

Extract 3-5 distinctive nouns/verbs from the skill's purpose — domain terms, not generic words like "query" or "check". Then:

1. `Glob plugins/*/skills/*/SKILL.md` and `.claude/skills/*/SKILL.md` to enumerate candidate skills.
2. `Grep` those distinctive terms across the frontmatter `description:` lines to surface adjacent skills.
3. Read the top matches' full SKILL.md files and apply the signal hierarchy above to decide: merge, differentiate, or leave alone.

Does **not** render a merge/differentiate/leave-alone verdict automatically — that requires judgment on whether the lexical overlap reflects real scope overlap.

### Recommended Actions

For each surfaced candidate, suggest **one** of these three — don't hedge.

**Merge.** Both skills do substantially the same job. Consolidating reduces drift and simplifies discovery.

- When: Strong description overlap, same audience, same underlying tool, no meaningful scope distinction.
- Suggest: which skill survives (usually the one with better evals, more recent updates, or the more comprehensive references/), and a one-line note on what facts need to carry over from the other.
- Severity: typically **Major** if unambiguous, **Minor** if borderline.

**Differentiate.** The skills are genuinely distinct but their descriptions or trigger phrases conflate them. Claude's router will pick the wrong one.

- When: both skills have legitimate non-overlapping use cases, but the descriptions share trigger phrases or fail to call out the distinction.
- Suggest: a concrete edit to the description of the skill under review — sharpen the triggers to exclude the other skill's scope.
- Severity: **Minor**.

**Leave alone.** The similarity is superficial or intentional. Document the decision so the next reviewer doesn't re-flag it.

- When: regional/environment variants, same domain but different backends/datasets, or general skill + specialized workflow.
- Suggest: nothing to change — but optionally note the distinction in the description for future clarity.

---

## Hook Integration

Not all skills need hooks. Only suggest a hook when there is a **concrete, deterministic trigger event** — a specific file being written, a specific command being run, or a specific tool being invoked. "No hook needed" is a valid and common verdict for intent-based skills.

### Finding Types

| Finding type                                                                                           | Severity                                            | Det? |
| ------------------------------------------------------------------------------------------------------ | --------------------------------------------------- | ---- |
| Hook would improve triggering determinism (specific file write, CLI command, or tool invocation event) | Minor (informational)                               | N    |
| "No hook needed" — intent-based or broad-domain skill                                                  | n/a (informational only, not surfaced as a finding) | N    |

### When Hooks Add Value

**File-write patterns.** The skill applies when specific files are created or modified. A PreToolUse Write hook matching the file path ensures the skill loads. Example: a migration skill applies when writing to `db/migrate/*.rb` — hook matches the path.

**Command patterns.** The skill applies when a specific shell command is run. A PreToolUse Bash hook matching the command pattern triggers deterministically. Example: a create-PR skill firing on `gh pr create`.

**Tool invocation patterns.** The skill applies when a specific MCP tool is called. A PreToolUse hook on the tool name triggers deterministically. Example: an observability skill could hook on its server's tool-name pattern (`mcp__<server>__*`) to load context before queries.

**Eval reliability.** The skill has good evals but they fail intermittently because description-based triggering is non-deterministic. A hook provides deterministic triggering during eval runs. Mention this separately from the core triggering concern — it's a test-infrastructure benefit, not a runtime triggering improvement.

### When Hooks Are Unnecessary

**Intent-based skills.** The skill triggers on user intent expressed in natural language, with no specific file/command/tool trigger. Example: a "learn" skill — there's no file or command that would fire it; the description handles triggering.

**Broad domain skills.** Many different actions could apply, making a specific hook impractical. Example: a "code-review" skill applies to any code review activity — too broad a trigger surface for a single hook.

**Reliably-triggered skills.** The description already triggers reliably in practice. If users consistently get the skill when they need it, a hook adds complexity without value. Test this by reviewing `trigger-evals.json` results or skill-activation telemetry.

### Pragmatic Assessment Framework

When reviewing for hook opportunities, ask:

1. **Specific file pattern?** Skills mentioning directories, file extensions, or path patterns → suggest PreToolUse Write hook with path matcher.
2. **Specific command?** Skills applying when running specific CLI commands → suggest PreToolUse Bash hook with command matcher.
3. **Specific tool?** Skills wrapping or guiding MCP tool usage → suggest PreToolUse hook on the tool name.
4. **None of the above?** → "No hook needed. Description-based triggering is appropriate for this skill."

### Hook Configuration Reference

Hooks live in the plugin's `hooks.json`:

```json
{
  "hooks": [
    {
      "type": "command",
      "event": "PreToolUse",
      "matcher": "Write",
      "command": "path/to/hook-script.sh"
    }
  ]
}
```

The hook script receives tool input as JSON on stdin and can output instructions for Claude. Exit code 0 = allow, exit code 2 = block with message.

---

## Description as a Routing Signal

**`finding_type`: `description-as-routing-signal`.**

A skill's `description` is loaded into every session and is the surface Claude's router matches against. It must state **what the skill is for and when to reach for it** — a routing signal. When the first sentence instead enumerates the skill's _implementation features_ ("does duplicate-check, scoring, ownership routing, and a draft GitHub issue"), it reads as a body summary, not a trigger, and the router has nothing crisp to match — the skill mis-fires or fails to fire.

This is the **semantic** half of description quality. The mechanical description-shape concerns — over-length, preamble, keyword spray — are **out of this skill's scope**. This finding is only the judgment call that can't be made mechanically: "does the first sentence route, or does it summarise the body?"

### Finding type

| Finding type                                                         | Severity                                                   | Det? |
| -------------------------------------------------------------------- | ---------------------------------------------------------- | ---- |
| Description summarises the body instead of stating purpose + trigger | Minor, or Major when there is **no** routing signal at all | N    |

**Pattern.** The description's opening leads with a feature/implementation inventory rather than an action-led purpose statement. The canonical fix shape is a single sentence naming the job and the trigger: _"Triage a Continuous Improvement submission — check duplicates, score feasibility, route ownership, and draft a GitHub issue."_

**Severity.** Minor by default (a feature-list opener that still contains some matchable trigger signal). **Major** only when the description carries no routing signal at all — pure feature inventory a router can't act on. Do not escalate on taste; if a reasonable trigger phrase is present, it's Minor.

**Deterministic.** No — distinguishing "feature inventory" from "purpose statement" is judgment. Follow the project's skill-description style guidance (and Anthropic's public guidance on writing skill descriptions); cite it in the fix.

**Fix.** Rewrite the first sentence as an action-led purpose + trigger. This is the one description finding that gets a suggested rewrite (see Rewrite Policy below) — the corrected `description:` line.

**Boundary.** If the only problem is mechanical description shape (length, preamble, keyword spray), there is NO Convention finding — those are out of this skill's scope. This finding requires a _semantic_ defect: does the first sentence route, or summarise the body?

## Invocation Mode (the invocation-mode-mismatch predicate)

**`finding_type`: `invocation-mode-mismatch`.**

A skill's `name` + `description` load into every session's system prompt and compete in Claude's router. That cost buys _discovery_ — the router can auto-fire the skill when user intent matches. A skill that **can't usefully auto-fire** — a slash-command-only skill, or a sealed-input sub-routine that consumes a structured object a router could never supply — never needs that discovery, so the auto-fire surface is pure overhead: context budget spent and router noise added for a skill that will never usefully auto-fire. The mismatch is such a skill shaped as if it wants discovery. (Being dispatched by another skill, or carrying `user-invocable: false`, does _not_ by itself put a skill here — a dispatched or non-user-invocable skill can still be a legitimate intent-driven auto-fire skill.)

### Finding type

| Finding type                                                                                                                              | Severity                                                                                   | Det? |
| ----------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ | ---- |
| Skill that can't usefully auto-fire (slash-command-only, or a sealed-input sub-routine) still ships a multi-trigger auto-fire description | **Minor** (default); **Major** for a widely-shared skill with a full auto-fire description | N    |

**Pattern.** A skill carries an auto-fire surface that does no useful work. Two things must both hold. **(1) Auto-fire can't help this skill** — it is either slash-command-only (declares "run via /<skill>", "only when the user explicitly asks", "invoked intentionally") or a sealed-input sub-routine that consumes a structured object an upstream orchestrator/adapter produces (e.g. "consumes a TriageContext and emits a sealed TriageResult"), so a router auto-fire from a bare user prompt could never supply what it needs. **(2) It is shaped to court the router anyway** — its `description:` is a multi-trigger surface ("Use when the user mentions X, asks to Y, says Z…") built to win an auto-fire it can't use. That wasted description is the defect. (Setting `disable-model-invocation: true` is good hygiene for such a skill, but a clean one-line description with the field merely unset is the acceptable precision boundary — do not fire on a missing field alone.) **What does NOT establish (1):** `argument-hint` / `$ARGUMENTS` (auto-fire skills carry those too), `user-invocable: false` (it blocks _user_ invocation, leaving the skill model-reached — many auto-fire skills set it), or "dispatched by X" / "never invoked directly" on their own (a dispatched skill can still be a legitimate auto-fire skill). A skill whose auto-fire is its actual purpose — it acts on free-form user intent, like a context or domain skill — is never in scope, however rich its triggers.

There are **two** correct end states, depending on how the skill is reached:

- **Slash-command skill** (the user runs `/<skill>`): `disable-model-invocation: true` plus one action-led purpose line that names the invocation — e.g. "Stress-test a Linear issue's plan against the codebase; runs only when the user invokes /grill-me." Lead with the verb: a description starting "Use when…" fails the no-preamble convention many description linters (and Anthropic's guidance) enforce.
- **Helper-only skill** (dispatched by another skill / orchestrator, never user-run): `disable-model-invocation: true` plus a one-line description of _what it does and who dispatches it_ — e.g. "Dispatched by the triage orchestrator to verify hypotheses against live code and return a TriageResult." Do NOT rewrite a helper-only "called by / dispatched by" description into user-invocation text; that misstates how the skill runs. (Note: a `user-invocable: false` skill is _not_ user-invoked-only — that field blocks the user from invoking it, leaving it model- or dispatch-reached. The field that turns auto-fire off is `disable-model-invocation: true`.)

**Fix.** Collapse the multi-trigger `description:` to a one-line purpose statement matching how the skill is reached — an action-led purpose line naming the slash invocation for command skills, or a _what-it-does + who-dispatches_ line for sub-routines — and set `disable-model-invocation: true` so the router can't fire a skill that can't use the invocation. Never convert a sub-routine's "called by / dispatched by" description into user-invocation text, and never lead a rewritten description with "Use when…" — the no-preamble convention rejects that, so lead with the action verb. Cite the project's skill-description style guidance.

**Severity.** Minor by default. **Escalate to Major when** the skill is widely shared AND the `description:` is a full multi-trigger auto-fire surface — there the wasted description loads into thousands of sessions and the router noise competes against skills that _do_ need to fire. Cite the predicate; silent escalation is not allowed.

**Deterministic.** No — the `disable-model-invocation` field value is a mechanical read, but judging "auto-fire can't usefully serve this skill" is judgment-bound, so the finding overall is `deterministic: false`.

**How to spot it.** (1) Decide whether auto-fire could do useful work for the skill: a slash-command-only skill or a sealed-input sub-routine cannot, while an intent-driven context/domain skill can — never infer "can't auto-fire" from `argument-hint`, `user-invocable: false`, or "dispatched by X" alone. (2) If it can't usefully auto-fire, check the `description:`: a multi-trigger auto-fire surface is the defect. A clean one-line description is the acceptable boundary even if `disable-model-invocation` is unset — don't fire on the missing field alone. (3) Fire only when the skill is in scope AND ships a multi-trigger auto-fire description. A model-invoked skill whose rich trigger description does real routing work is correct and normal — not this finding.

**Boundary with `description-as-routing-signal`.** That finding fixes a _model-invoked_ skill whose description fails to route (sharpen the triggers so it fires). This finding _drops a wasted auto-fire surface_ from a skill that can't usefully auto-fire (collapse the multi-trigger description; set the field for sealed-input sub-routines). They point in opposite directions — never file both on the same skill. Mechanical description-shape (length, preamble, keyword spray) stays out of scope; this is the semantic call of whether the invocation _mode_ fits the skill's purpose.

## Repo-Convention Findings

**`finding_type`: `repo-convention-violation`.**

**Pattern.** The skill's (or a bundled agent's) frontmatter violates a convention the repo documents for itself — in its `CLAUDE.md`, contributing guide, or authoring docs. The canonical example: an agent declares `model: inherit` where the repo's documented default is a specific model (e.g. `model: sonnet` unless the task explicitly justifies a larger one), and `inherit` can silently resolve to a pricier model. Other examples: a required metadata field omitted, a naming convention the repo enforces.

**Detection.** Read the repo's own documented conventions, then compare the skill's frontmatter field values against them (a field-value comparison). Only flag against a convention the repo actually documents — do not invent one.

**Severity.** Minor.

**Deterministic.** Yes — frontmatter field comparison against a documented rule.

**Fix.** Change the field to the documented value (e.g. `model: inherit` → `model: sonnet`), and note the justification in the PR description if the convention allows an exception.

---

## Out of Scope / False-Positive Guardrails

- **Single signals don't trigger duplication findings.** A pair of skills sharing one weak signal is noise. Require ≥2 signals from the hierarchy to flag.
- **Regional and experimental variants are intentional.** Regional variants (`-us`/`-eu`/`-au`) and `-experimental` twins exist for deliberate reasons (data-residency compliance, maturity tiers); never flag them as duplicates.
- **"No hook needed" is the most common hook verdict.** Don't manufacture hook opportunities to fill the category. Intent-based and broad-domain skills are correctly described-triggered.
- **Cost-efficiency patterns are NOT in this category.** Bash chains, MCP result-size nudges, field projection, and response-style discipline live in [`cost.md`](./cost.md). A skill in the wrong location AND with expensive bash chains gets two findings, one per category.
- **`orchestration-shaped-skill` deliberately co-fires with Cost.** It is the one intentional cross-category pair: the same deterministic-orchestration smell is filed in Cost (`script-extractable-orchestration`) AND Convention (`orchestration-shaped-skill`) when a skill is mostly glue end-to-end. This is by design. A single extractable chain in an otherwise-sound skill is Cost only.
- **Body shape findings are NOT in this category.** Body↔references duplication and flat-reference-list problems live in [`structural.md`](./structural.md).
- **Model invocation is the correct default — do NOT fire `invocation-mode-mismatch` on most skills.** Auto-fire is how the great majority of skills are meant to work. Fire only when auto-fire can't do useful work for the skill (slash-command-only, or a sealed-input sub-routine) AND it still ships a multi-trigger auto-fire description that courts the router. Never fire from `argument-hint` / `$ARGUMENTS`, `user-invocable: false`, or "dispatched by X" / "never invoked directly" on their own. A clean one-line description is the acceptable boundary — do not fire on a missing `disable-model-invocation: true` alone. And never fire merely because a description is long — mechanical description shape is out of scope.
- **Content-quality findings are NOT in this category.** Procedure smell and context-vs-instructions live in [`content-quality.md`](./content-quality.md). Hook integration is here because triggering is a placement/fit concern, but procedure smell is still about _what's in the body_.
- **Only flag a repo-convention violation against a documented convention.** If the repo doesn't document the rule, there's no finding — don't impose a convention from another project.

## Rewrite Policy

**Produce a suggested rewrite for three findings: the similar-skill "differentiate" verdict, the `description-as-routing-signal` finding, and `invocation-mode-mismatch`.** For "differentiate", write the sharpened `description:` text that explicitly redirects the user to the neighbor skill. For `description-as-routing-signal`, write the corrected first sentence as an action-led purpose + trigger per the project's skill-description style guidance. For `invocation-mode-mismatch`, the rewrite is the corrected frontmatter — `disable-model-invocation: true` plus the collapsed one-line `description:` as an action-led purpose statement (naming the slash invocation for command skills, or a what-it-does + who-dispatches line for sub-routines; never user-invocation text for a sub-routine, and never a "Use when…" preamble). In all three the rewrite is frontmatter, not the whole skill (see [`suggested-rewrites.md`](./suggested-rewrites.md) for the rewrite-block format).

**For everything else in this category, describe the fix in prose.** `orchestration-shaped-skill` — describe the extraction: name which sections are the deterministic pipeline (to move into `scripts/`) and which are the judgment kernel (to keep in the thin skill); do not author the script yourself. Placement findings — explain why the current location is wrong and which location (or `~/.claude/` / `.claude/rules/`) is right; do not relocate the skill yourself. Merge / leave-alone verdicts for similar skills get prose only. Hook-integration findings — describe the trigger opportunity ("Add a PreToolUse Bash hook matching `gh pr create`…"); the author writes the hook script themselves. Repo-convention findings get a one-line "change to the documented value" — no rewrite block.

## Notes for Implementers

- Placement and similar-skill duplication are both **structure** concerns. They're together because they're both about how a skill sits relative to its neighbors — not because they're token-efficiency concerns.
- The repo-convention finding is a "field value violates a documented rule" concern — which is why it's a Convention finding and the lone deterministic one here. Only fire it against a convention the repo actually documents.
