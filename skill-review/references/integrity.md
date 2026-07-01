# Integrity — Detailed Criteria

## Scope

Claims made in the skill hold against reality. Three sub-checks:

- **Existence** — every named file, skill, agent, command, slash-command, MCP tool, script, or cross-plugin reference points to something that actually exists, **and every tool the body instructs Claude to call is declared in `allowed-tools`** so the call isn't blocked at runtime.
- **Equivalence** — files declaring "must stay identical" actually match; counts and totals claimed in prose match what's in the referenced tables; **two instructions in the skill's files don't contradict each other** (the skill doesn't say X here and not-X there).
- **Behaviour** — executable code the skill ships **or invokes** (scripts under the skill's own `scripts/`, shared scripts at the plugin root the SKILL.md references, and runnable `bash`/`python` blocks the body tells Claude to run) actually works as documented: no crash on a documented-valid input, no hardcoded-environment break, no silently-wrong output.

The Existence and Equivalence sub-checks are **binary** — either a reference resolves or it doesn't, either two paired files match or they don't, and there is no "polish" tier for them. The Behaviour sub-check is **judgment-bound** — it requires reading the code and reasoning about what it does — and it is the one place this category carries a Critical tier (a silently-wrong result is worse than a loud missing reference). See [`security.md`](./security.md) for the *safety* of those same scripts; Integrity asks only whether they **work**.

## When This Applies

Severity tiers in scope: **Critical** (Behaviour sub-check only), **Major**.

- **Critical** — a bundled script produces *silently-wrong output* on normal inputs (the `logic-bug-produces-wrong-output` finding). This is the one Integrity violation that fails *silently*: no missing-file signal, no stack trace, just a wrong answer the author trusts. Existence and Equivalence violations are never Critical — Claude surfaces a missing reference rather than silently doing the wrong thing.
- **Major** — every Existence and Equivalence finding (broken references, an instructed tool missing from `allowed-tools`, divergent rubrics, contradicted counts, contradictory instructions), plus Behaviour findings that fail *loudly* (a script that crashes on a documented input, or breaks on any machine but the author's).
- **Minor** — not in scope. A reference either resolves or it doesn't; code either works or it doesn't. There is no partial-integrity tier.

## Blast Radius

Integrity's existence checks resolve against **the repo / marketplace under review** — the set of skills, agents, commands, and plugins that ship from the same source the skill under review ships from. A reference is "broken" only when it names something that *should* live in that source but doesn't. References to namespaces that resolve **outside** that source — Claude Code's runtime, Anthropic's official marketplace, or any third-party plugin not present in this repo — are out of blast radius and are never flagged (the reviewer can't see them, and their absence here is expected). See the out-of-blast-radius rule below for the exact exclusions.

## Existence Sub-Check

### Cross-plugin reference doesn't resolve

**Pattern.** SKILL.md or a reference file mentions `<plugin>:<skill>` (e.g. `acme-tools:foo`) where `<plugin>` ships from the repo under review, and the referenced item is absent from this repo.

**Severity.** Major.

**Deterministic.** Yes — same-repo existence check across the plugins that ship from this repo. Out-of-blast-radius prefixes are pre-excluded, so the match decision is a single boolean.

**Fix.** Either create the referenced item, fix the reference, or remove the claim.

### MCP tool reference doesn't resolve

**Pattern.** The skill body or a reference file names an MCP tool that doesn't exist — a made-up name (`sf_query`), a stale name from before a server rename, or a short-form name where the skill will actually receive the fully-qualified one (`mcp__plugin_<ns>_<server>__<tool>`). The skill instructs Claude to call it; the call fails at runtime because no such tool is registered.

**Detection.** Read the skill's declared MCP servers and `allowed-tools` list, compare the named tool against the documented tool surface for each server. Check whether the name is the correct fully-qualified form.

**Severity.** Major.

**Deterministic.** Yes in principle — the registered tool names for a server are enumerable, so the match is a boolean once the server is known. Judgment is needed to resolve "which server backs this skill" and the short-vs-fully-qualified mapping.

**Fix.** Use the exact registered tool name (fully-qualified `mcp__plugin_<ns>_<server>__<tool>` form where the skill receives it), or correct the stale name. If the skill genuinely doesn't depend on that tool, remove the reference.

### Internal slash-command or skill reference doesn't resolve

**Pattern.** The skill names a `/slash-command` or a `Skill(skill: "<plugin>:<name>")` / skill invocation that has no backing skill or command in the repo under review — a dead reference (`/quality-check` with no such skill), or a bare `/create-pr` where the correct invocation is `Skill(skill: "<plugin>:create-pr")` and the unqualified form won't resolve as written.

**Severity.** Major.

**Deterministic.** Yes — same-repo existence check, identical mechanism to the cross-plugin reference check.

**Fix.** Point at a command/skill that exists and invoke it in the resolvable form, or remove the claim. Apply the same out-of-blast-radius exclusions below (a runtime or third-party-marketplace command is not flagged).

### Instructed tool is missing from `allowed-tools`

**Pattern.** The skill body (or a reference file) tells Claude to invoke a tool — `Skill(...)`, an `Agent` / `Task` subagent dispatch, `WebFetch`, `WebSearch`, `Bash` to run a bundled script, or a fully-qualified MCP tool (`mcp__plugin_<ns>_<server>__<tool>`) — but that tool is **absent from the skill's declared `allowed-tools`**. When `allowed-tools` is set, Claude Code restricts the skill to exactly that surface, so the instructed call is denied at runtime: the subagent never launches, the bundled script is unreachable dead code, the web fetch is blocked. The skill claims a capability its own declared surface can't deliver — a broken claim, the same shape as a reference that doesn't resolve.

**Detection.** Read the `allowed-tools` frontmatter, then scan the body and reference files for tool invocations the skill *instructs*: `Skill(skill: "...")`, "dispatch the Agent tool", "use `WebFetch`", `bash`/`python` blocks the body says to run (these need `Bash`), and named MCP tools. For each instructed tool, check it's present in `allowed-tools` directly or via a wildcard (`mcp__plugin_<ns>_<server>__*` covers that server's tools). Flag any instructed tool not covered.

**Severity.** Major.

**Deterministic.** Yes — set-difference between the tools the body instructs and the `allowed-tools` list. Judgment is only needed to recognise an *instruction to call* a tool versus a passing mention; the membership check itself is mechanical.

**Fix.** Add the missing tool to `allowed-tools` (use the wildcard or fully-qualified form for MCP tools), or stop instructing it if the skill genuinely doesn't need it.

**Direction.** This finding fires in **one direction only — instructed-but-undeclared.** The inverse (a tool *declared* in `allowed-tools` but never invoked in the body) is **not** flagged: `allowed-tools` is a superset policy, an unused declaration makes no false claim, and flagging it adds noise with no runtime consequence. See the false-positive guardrails for the `allowed-tools`-absent case.

### Out-of-blast-radius prefix flagged as broken

**Pattern.** Reference uses a prefix that resolves outside the repo under review and the referenced item isn't in this repo.

**Action.** **Do not flag.** These prefixes resolve outside this reviewer's blast radius:

- Claude Code runtime namespaces (e.g. `plugin-dev:*`) — these ship with Claude Code itself, not from this repo.
- Anthropic's official marketplace (e.g. `superpowers:*`) — auto-installed plugins whose files live in the user's plugin cache, not in this repo.
- Any third-party / external plugin not present in the repo under review.

Graceful-degradation phrasing ("if installed", "or the equivalent fallback") is correct usage, not a broken-reference signal.

## Equivalence Sub-Check

### Paired files declare "must stay identical" but diverge

**Pattern.** Two files both declare they're supposed to match (a rubric, a list, a table) but the actual content has drifted. The classic shape: a SKILL.md and a companion agent file both declare "this rubric must stay identical" but one side has silently diverged on a predicate, a parenthetical clarification, or an edge-case sentence.

**Severity.** Major.

**Deterministic.** Yes — once the AI identifies the declared-paired section pair, the match check is a byte-diff. (The pair declaration itself is structural — "must stay identical" / "must match" text in the file.)

**Fix.** Either bring the diverged file back to match, or remove the "must stay identical" declaration if drift is intentional. The cleanest structural fix is to eliminate one of the duplicated copies entirely — make one file the source of truth and have the other reference it.

### Prose count doesn't match referenced table

**Pattern.** SKILL.md says "the table has 7 columns" or "we cover 6 patterns" but the referenced file has a different count.

**Severity.** Major.

**Deterministic.** Yes — integer comparison between the claimed count and the actual table row/column count.

**Fix.** Either update the prose or update the table — whichever was meant.

### Two instructions contradict each other

**Pattern.** Two instructions in the skill's files cannot both be followed — the skill says X in one place and not-X in another, applying to the *same* condition. Shapes seen in practice:

- A stated invariant the body later violates — frontmatter / Hard Rule declares "Read-only — no mutations", then a later step instructs "enable the `bulk_delete_killswitch`".
- A body↔reference conflict on the same step — the body says "attempt the fix if it's a single file"; the reference for that bucket says "do NOT attempt to implement — just describe".
- A control-flow contradiction — "Stage 1's verdict is ignored here" one sentence after "run only if Stage 1's verdict = INVESTIGATE".
- A directional pointer that points the wrong way — "see the fallback section **above**" when that section is below.

Whichever instruction Claude reads first wins, so behaviour is unpredictable at exactly the decision point that matters. This is the general semantic case of Equivalence; the prose-count check above is its integer special case.

**Detection — enumerate same-condition instruction pairs across files.** This finding is under-fired because the two halves of the contradiction usually live in *different files* (body vs reference, or one reference vs another), so neither reads as wrong in isolation. Don't wait for a contradiction to jump out. Build a short list of the directives that govern each key decision point or action the skill performs (which tool to call, which order, which URL/value to use, whether to attempt vs describe, read-only vs mutate), drawing from SKILL.md *and* every reference file, then check each directive against the others that govern the *same* condition. The miss pattern is a body rule and a reference snippet that quietly disagree (e.g. "the conversations table is blocked" in one place, three `Conversation.find` snippets in another) — only visible if you put the same-condition directives side by side.

**Severity.** Major.

**Deterministic.** No — recognising that two instructions conflict requires reading both and reasoning about whether they can co-hold under the same condition. Unlike the prose-count check (integer comparison), there's no mechanical match.

**Fix.** Resolve the conflict: pick the correct instruction and remove or rewrite the other, or scope each to its actual condition if they were meant for different cases. Describe the resolution in prose — do not rewrite the section.

## Behaviour Sub-Check

This sub-check requires **reading the actual script files** the skill ships or invokes. That includes scripts under the skill's own `scripts/` **and** shared scripts at the plugin root (e.g. `${CLAUDE_PLUGIN_ROOT}/scripts/...`) that the SKILL.md references and tells Claude to run — a skill folder with no `scripts/` dir of its own is **not** evidence that there are no scripts to review. Glob for the script paths the SKILL.md names and read them wherever they live. Never raise a Behaviour finding from SKILL.md prose alone — if the skill bundles or invokes scripts (or runnable `bash`/`python` blocks the body tells Claude to execute) and they're behaviourally relevant, read them.

**Mandatory read step — and it cuts both ways.** Before emitting *any* Integrity status, enumerate every script the SKILL.md and reference files name or instruct Claude to run (Glob the referenced paths under the skill's `scripts/`, the plugin root, and any `bash`/`python` block the body says to execute), and **Read each one in full.** This is the most under-fired part of Integrity: the bug is real and readable, but the reviewer never opens the file and defaults to a clean pass. The read requirement is therefore *symmetric* — just as a Behaviour finding requires having read the script, an Integrity **`pass` requires having read every referenced script**. You cannot pass what you did not open. If a named script is for some reason unreadable, say so explicitly rather than passing silently; never infer a script works from its filename, its surrounding prose, or the skill merely having evals.

### Script crashes on a documented-valid input

**Pattern.** A bundled script raises an unhandled exception on an input the skill documents as supported — an unmapped `dict`/enum key, an unguarded `None`, an index that runs past the end, a type the code didn't anticipate. The skill claims to handle the input; the code doesn't.

**Severity.** Major (fails loudly — the author sees the stack trace).

**Deterministic.** No — requires understanding which inputs the skill treats as valid and whether the code handles them.

**Fix.** Handle the documented input explicitly — map the missing key, guard the `None`, validate before indexing. Show the corrected code. The classic shape is `MAPPING[value]` where `value` comes from user/Claude input but `MAPPING` doesn't cover every documented case — a `KeyError` waiting on the first unlisted value.

### Hardcoded environment assumption

**Pattern.** A bundled script embeds something tied to one machine: an absolute home path (`/Users/<name>/...`, `/home/<name>/...`), a fixed directory that only exists on the author's box, or a missing `if __name__ == "__main__":` / dependency guard that prevents the script from running as the skill documents. Works for the author, breaks for everyone else and in CI.

**Severity.** Major (fails loudly — the script errors on first use elsewhere).

**Deterministic.** No — the `/Users/` / `/home/` literal is regex-detectable, but distinguishing a hardcoded breakage from a documented, overridable default requires judgment.

**Fix.** Derive the path at runtime (`Path.home()`, `os.environ`, `${CLAUDE_PLUGIN_ROOT}`, an argument with a sensible default), or document the required setup explicitly. Add the missing `__main__` guard. Show the corrected snippet.

### Logic bug produces wrong output

**Pattern.** The code runs cleanly and returns a result, but the result is wrong on normal inputs. Over-broad regex that matches more than intended (`#?(\d+)` capturing any digit run, not just PR numbers), an off-by-one in a slice or range, the wrong field read from a payload, a comparison that inverts under an expected value.

**Severity.** Critical — silent wrongness has no runtime signal and tends to be trusted. This is the only Critical tier in Integrity.

**Deterministic.** No — requires reasoning about what the correct output should be for representative inputs.

**Fix.** Tighten the logic to the intended domain (anchor the regex, fix the bound, read the right field). Show the corrected code; where the skill has evals, note the regression case that would have caught it (the missing eval is a separate Test Coverage finding — the bug itself is the Integrity finding).

## Out of Scope / False-Positive Guardrails

- **Out-of-blast-radius prefixes never get flagged.** This is the single most common Integrity false positive. The full prefix exclusion list is above — treat absence of any reference that resolves outside the repo under review as valid by default.
- **Graceful-degradation phrasing is correct usage.** "If `<plugin>:foo` is installed…" or "fall back to manual review if the script isn't available" — these are NOT broken-reference signals, they're correct depend-but-degrade patterns.
- **No `allowed-tools` block → no instructed-tool finding.** When the frontmatter omits `allowed-tools` entirely, the skill inherits the session's full toolset, so nothing is blocked — never raise the instructed-tool finding against a skill that declares no `allowed-tools`. The finding applies only when `allowed-tools` is present *and* an instructed tool falls outside it. Likewise, do not flag the inverse (declared-but-uninvoked tool) — that's the superset-policy case, not a broken claim.
- **Conditional branches are not contradictory instructions.** "If the issue is single-file, attempt the fix; otherwise just describe it" is correct branching, not a contradiction — the two directives apply to *different* conditions. Only raise the contradictory-instructions finding when both directives govern the *same* condition and cannot both hold. Graceful-degradation/fallback phrasing and a "don't do this" anti-pattern shown beside the real instruction are likewise not contradictions.
- **Behaviour findings require reading the script — never speculate.** No crash / hardcoded-path / wrong-output finding may be raised from SKILL.md prose alone. If the relevant script isn't read, there's no Behaviour finding.
- **Anti-pattern examples are not Behaviour findings.** A skill (like this one) that *shows* a buggy snippet as a "don't do this" example is teaching, not shipping a bug. Use surrounding context — is the code framed as the skill's tool, or as a cautionary example? Likewise, illustrative/pseudo-code blocks that aren't wired to run are not Behaviour findings.
- **Safety defects are Security, not Integrity.** Command injection, unquoted expansion enabling exploits, credential leaks, and path traversal live in [`security.md`](./security.md). Integrity's Behaviour sub-check is only for code that *doesn't work* (crash / non-portable / wrong output). A defect that is both → file the more severe.

## Rewrite Policy

**Produce a suggested rewrite for every Behaviour finding (crash, hardcoded environment, wrong output).** These are about executable code, so the fix is concrete code — show the corrected branch, the runtime-derived path, or the anchored regex inline in the finding's details block, per [`suggested-rewrites.md`](./suggested-rewrites.md). Keep it minimal — patch the defect, don't refactor the surrounding script.

For all other Integrity findings (broken cross-plugin / MCP-tool / command reference, instructed-tool-not-in-`allowed-tools`, paired-file divergence, prose-count mismatch, contradictory instructions), describe the fix in prose. Two paths exist for paired-file divergence — bringing the diverged side back to match, or eliminating the duplicated copy entirely so one file becomes the source of truth — pick the cheaper one and explain why. Do not write the diff or the merged file.

## Notes for Implementers

- Most Existence and Equivalence findings are deterministically detectable for the repo under review and same-repo paired files: cross-plugin refs, MCP-tool / command resolution, the instructed-tool-vs-`allowed-tools` set-difference, prose-vs-table counts, and paired-file diffs are all boolean checks once the relevant files are read (`deterministic: true`). The **one Equivalence exception is `contradictory-instructions`** — deciding two directives conflict requires semantic judgment, so it is `deterministic: false`. The **Behaviour** sub-check is also judgment-bound — crash / portability / wrong-output detection requires reading the code and reasoning about it, so `deterministic: false` for all three Behaviour finding types. The determinism eval must filter the judgment-bound findings (`contradictory-instructions` + the three Behaviour types) out of its tuple-equality assertion (same treatment as Content Quality), while keeping the boolean Existence/Equivalence findings in scope.
- The reason Integrity has no Minor tier: a reference either resolves or it doesn't, and code either works or it doesn't — there's no "mostly resolves" or "kind of works". The Critical tier is the deliberate exception, scoped to exactly one finding (`logic-bug-produces-wrong-output`): silent wrong output is worse than a loud missing reference. Keep both properties when adding finding types — no Minor, and Critical only for silent-wrongness.
