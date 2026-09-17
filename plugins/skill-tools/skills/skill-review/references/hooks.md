# Hooks — Detailed Criteria

## Scope

The hooks **associated with the skill under review** — entries in the skill's plugin `hooks/hooks.json` (and the scripts they invoke) whose payload names this skill, advertises it, injects context for it, or gates the domain it owns. This category asks two questions:

1. **Is a hook the right tool here at all?** — or is the hook's payload just static words for the model that belong in CLAUDE.md, a directory-level CLAUDE.md, or the skill's own trigger description?
2. **If a hook is warranted, is it built to the deterministic-gate contract?** — narrow matcher, cheap short-circuit, correct block convention, no heavy synchronous work, no duplication. (Secrets in hook source are a **Security** finding, not a Hooks one — see the boundary note.)

This category evaluates **hooks that already exist**. Whether a *hookless* skill should gain a hook to fire more reliably is a different question owned by Convention ([`convention.md`](./convention.md) § Hook Integration) — see the boundary note below. A skill can trip Convention (no hook, but a deterministic trigger would help) and Hooks (ships an always-on advertisement hook that should be migrated) independently.

## The Decision Test

A hook is justified only when it is **deterministic** AND does something instructions physically cannot:

1. **Enforce** — block / ask / allow a specific tool call (`PreToolUse` gate).
2. **Mutate environment** — settings, worktrees, marker state, config.
3. **Observe silently** — telemetry at zero context cost (`async: true`).
4. **React to events the model can't see** — compaction, session end, config change, notifications.

If the payload is **static words aimed at the model** ("remember to use skill X", "you MUST invoke Y"), it belongs in CLAUDE.md / a directory-level CLAUDE.md (which autoloads when Claude works in that directory) / the skill's own trigger description — **not** a hook. That is the root antipattern this category exists to catch.

## ⚠️ Be Very Careful With `UserPromptSubmit`, `Stop`, and `PostToolUse` Hooks

These events fire on **every** turn (`UserPromptSubmit`, `Stop`) or **every** tool call (`PostToolUse`) — the most expensive place in the session to hang a hook. Even a cheap script here runs constantly, and every byte it injects is re-paid on each fire. Before registering a hook on one of these events, push hard on two questions:

- **Does it actually need to fire every time?** Most don't. A hook that cares about a specific action almost always belongs on a narrower event — `PreToolUse` with a tight matcher (a specific tool / command / file path), `SessionStart`, `PreCompact`, `SessionEnd` — that fires only when the thing it reacts to happens.
- **If it genuinely must live on a hot event, can it fire once per session?** A once-per-session dedup marker (invalidated on `PreCompact` if it gates in-context knowledge) turns "every turn" into "once", which is usually all the payload needed.

This is a **caution, not an automatic block** — a hot-event hook that is genuinely justified, cheap, and deduped is fine. But the burden of proof is on the hook: an unexamined `UserPromptSubmit`/`Stop`/`PostToolUse` registration is the single most common source of the antipatterns below.

## When This Applies

Severity tiers in scope: **Major**, **Minor**.

- **Major** — heavy synchronous work on a hot event (full test suite / build as a commit gate, `git diff` on every prompt, synchronous package-manager install at session start, a detached `claude -p` child per event); an advertisement/keyword-nudge hook that fires on a hot event or does network/subprocess work before its short-circuit; a hook duplicating a shared/base-plugin hook.
- **Minor** — a well-scoped-but-unjustified advertisement hook (static payload, fires cheaply); a hook on a hot event (`UserPromptSubmit`/`Stop`/`PostToolUse`) that doesn't need to fire every time; a matcher broader than needed; raw-JSON grep instead of `jq` parse; non-standard block convention (`exit 1` + stdout); an uncleaned `/tmp` marker; an oversized advisory injection.
- **Critical** — not in scope here. A hardcoded secret in a hook script is a **Security** finding (credential exposure), not a Hooks finding — see the boundary note. File it once, under Security.

## Determinism

Mixed. Mechanically detectable (deterministic: true): raw-JSON grep vs `jq` parse, `exit 1`+stdout vs `exit 2`+stderr, an injection over the ~2KB byte cap. Judgment-bound (deterministic: false): whether a payload is "static words" (advertisement) vs a real side effect, whether work is "heavy", whether a matcher is "broader than needed", whether another plugin's hook is a true duplicate.

---

## Finding Types

### `skill-advertisement-hook` (Major / Minor)

**Pattern.** A hook whose entire payload is "invoke / use skill X" or a keyword-matched nudge to load the skill — e.g. a `UserPromptSubmit` hook that greps the prompt for a keyword and injects "🚨 MUST use the Skill tool", or a `PostToolUse` hook that re-injects the same nudge on every file touch. The tell: remove the hook and the only thing lost is a reminder the model could have gotten from the skill's own description.

**Severity.** Minor by default (cheap, fires on an unmatched short-circuit, fail-open, and deduped to once per session). **Major** when it re-fires on **every** hot-event occurrence (every prompt / turn / `PostToolUse` tool call) instead of once per session, does network/subprocess work before the short-circuit, or injects large static context. The every-time-vs-once-per-session distinction is the main escalation: a nudge the user sees on every single turn is both far more expensive and far more annoying than the same nudge fired once and deduped.

**Deterministic.** No — distinguishing "static advertisement" from "a real deterministic side effect" is judgment.

**Fix — the migration protocol (do NOT reflexively delete).** This is the category's signature nuance, and it is load-bearing: naive fixes of this shape ("delete the hook, move the nudge to the description / directory CLAUDE.md") have a real failure history — a prior migration of exactly this kind was reverted because the description/CLAUDE.md substitute did not fire the skill as reliably as the hook did, and the engineers who relied on it pushed back. So the fix is conditional:

- **Migrate away** (delete the hook; fold the trigger into the skill's description and/or a directory-level CLAUDE.md) **only when both hold:** (a) there is *evidence* the description path actually fires — eval recall / trigger-evals data, not an assumption; and (b) the hook's actual users are consulted, because they are the ones who will feel a regression.
- **Otherwise keep-and-harden:** if the evidence isn't there, the hook stays, but make it well-behaved — a once-per-session dedup marker (so the nudge fires at most once), a **one-line pointer** (never inlined skill content), a narrow matcher, and fail-open. A hardened, deduped, evidence-justified nudge is acceptable (see the FP guardrails).

Describe this in prose on the finding — do not emit a delete-the-hook rewrite as if it were the only option.

### `heavy-work-in-hook` (Major)

**Pattern.** A hook runs expensive work synchronously on a frequent event: a full test/build suite as a `git commit` gate, `git diff` on every prompt, a synchronous package install at session start, or a detached `claude -p` child spawned per compaction/prompt. The hook blocks the session (or burns wall-clock / tokens) on every fire.

**Severity.** Major.

**Deterministic.** No — "heavy" is a judgment about the invoked command's cost.

**Fix.** Move the heavy work off the hot path: a full test suite belongs in CI or a git `pre-commit` hook, not a Claude commit gate (keep the fast checks — a linter/type-checker — if a fast gate is wanted); installs belong in a documented setup step, not `SessionStart`; per-event `claude -p` children are almost never worth it. For side-effect-only hooks (telemetry, state writes) set `async: true` so the hook never blocks the turn.

### `unnarrowed-matcher` (Minor / Major)

**Pattern.** The hook's matcher is broader than the event it actually cares about, or it runs an expensive check (`jq`, `git`, a network call) *before* the cheap short-circuit that would have let it exit early. A network call on the unmatched path is the worst case.

**Severity.** Minor; **Major** if the un-short-circuited path makes a network call or spawns a subprocess on every fire.

**Deterministic.** No — requires reading the script's control flow.

**Fix.** Narrow the matcher to the specific tool / command / path. Order checks cheapest-first: a pure-string test on the payload before any `jq`/`git`/network subprocess. No network calls on the unmatched path. Produce a rewrite showing the reordered short-circuit.

### `hot-event-hook` (Minor)

**Pattern.** The hook is registered on `UserPromptSubmit`, `Stop`, or `PostToolUse` — events that fire on every turn or every tool call — but nothing about it needs that frequency: it reacts to a specific action that a narrower event would catch, and it has no once-per-session dedup. Even when cheap, it runs constantly. (See the caution above.)

**Severity.** Minor — a caution, not a block. Do not escalate on frequency alone; if the hook *also* does heavy work or injects large static content on the hot event, that's the Major `heavy-work-in-hook` / `oversized-injection` finding instead.

**Deterministic.** No — the event is a mechanical read, but judging whether it *needs* to fire every time is judgment.

**Fix.** Move it to a narrower event that fires only when the thing it reacts to happens (`PreToolUse` with a tight matcher, `SessionStart`, `PreCompact`, `SessionEnd`); or, if it genuinely must live on the hot event, add a once-per-session dedup marker (invalidated on `PreCompact` if it gates in-context knowledge). Describe in prose.

### `raw-payload-grep` (Minor)

**Pattern.** The hook greps the **raw hook JSON** (stdin / `$CLAUDE_*` blob) instead of parsing the specific field (`prompt`, `tool_input`, …) with `jq`. Because it matches against the whole payload, unrelated fields trigger it — e.g. a `cwd` that happens to contain the keyword fires a prompt-keyword hook.

**Severity.** Minor.

**Deterministic.** Yes — detectable by a grep/`=~` over the raw stdin blob with no intervening `jq` parse of the intended field.

**Fix.** Parse the payload with `jq` and match only the intended field: `prompt="$(jq -r '.prompt' <<<"$payload")"` then test `$prompt`. Produce the corrected snippet as a rewrite.

### `nonstandard-block-convention` (Minor)

**Pattern.** A blocking hook signals the block with `exit 1` + a message on **stdout** instead of the convention `exit 2` + **stderr**; or the script does not declare, in a header comment, whether it fails **open** (advice — a failure lets the action through) or **closed** (policy — a failure blocks). Advice hooks should fail open; policy/guardrail hooks should deliberately fail closed.

**Severity.** Minor.

**Deterministic.** Yes — `exit 1`/stdout vs `exit 2`/stderr is a mechanical read.

**Fix.** Use `exit 2` + `stderr` for a block; add a one-line header comment stating the failure posture and why. Produce the corrected snippet as a rewrite.

### `uncleaned-marker` (Minor)

**Pattern.** The hook writes a `/tmp` (or session) marker file with no TTL or cleanup story, so stale markers accumulate and can suppress the hook in a later session; or a once-per-session dedup marker that gates on **in-context** knowledge is not invalidated on `PreCompact` (after compaction the model has lost the context the marker assumed it had, but the marker still suppresses the re-injection).

**Severity.** Minor.

**Deterministic.** No — requires reasoning about the marker's lifecycle.

**Fix.** Give the marker a TTL / cleanup path; invalidate a context-gating dedup marker on `PreCompact` so the hook re-fires after compaction. Describe in prose.

### `duplicate-hook` (Minor / Major)

**Pattern.** The skill's plugin ships a hook that duplicates one already provided by a shared/base plugin — e.g. a third copy of a migration-create gate, a fourth near-identical chat-message auto-approve hook, a parallel marker-file system. The best copy is usually the one already installed fleet-wide (marker-aware, generically repo-detecting).

**Severity.** Minor; **Major** if the divergent copy is a guardrail whose drift weakens enforcement.

**Deterministic.** No — establishing "same job" across two scripts is judgment.

**Fix.** Reuse the shared hook (or the shared marker/approve library) and delete the copy. Name the canonical one. Describe in prose.

### `oversized-injection` (Minor / Major)

**Pattern.** An advisory `UserPromptSubmit`/`SessionStart` hook injects a large static block (several KB or more every session) or injects static context on *every* session — content that, being static, belongs in CLAUDE.md rather than a hook that re-pays the token cost each fire.

**Severity.** Minor; **Major** past a few KB or when injected unconditionally every session.

**Deterministic.** Partly — the byte size over the ~2KB reference cap is measurable; whether the content is "static" is judgment.

**Fix.** Cap advisory injection (~2KB is the reference bar) and add a dedup marker; move genuinely static context to CLAUDE.md / a directory CLAUDE.md.

---

## Correct Patterns to Recognise as Safe

These are the **exemplars** — never findings:

- **Deterministic tool gates** — `PreToolUse` hooks that block/ask/allow a specific tool call: a Terraform-apply gate, a marker-aware migration-create gate, a PR-create intercept, a cloud-resource guard. This is the hook doing exactly what instructions cannot.
- **Worktree / environment provisioning** — a hook that sets up a worktree or mutates settings.
- **Once-per-session dedup nudges with a one-line pointer, fail-open, and `PreCompact` invalidation** — the *hardened* form of a context-injection hook.
- **`async: true` side-effect-only hooks** — telemetry, state writes that never block the turn.
- **Observe-before-block rollouts** — a hook that logs what it *would* block before it starts blocking.
- **Kill switches, opt-out tombstones, env-gated no-ops** — a hook that can be disabled per-user/per-repo without editing it.
- **A repo's track / gate / clear marker-file convention** — an exemplary marker system; do not flag it as a "parallel marker system".

## Out of Scope / False-Positive Guardrails

- **A well-built deterministic gate is not a finding.** Do not flag a Terraform-apply gate, a migration gate, or a PR-create intercept as "hooks that should be instructions" — their payload *is* enforcement, which instructions cannot do.
- **A hardened, evidence-justified advertisement hook is acceptable.** If a context-injection hook already has once-per-session dedup + a one-line pointer + fail-open, AND there is documented evidence the description path under-fires (e.g. eval-recall data), it is doing a real job the description can't yet do — do not flag it. The antipattern is the *unjustified, always-on, heavy, or duplicated* nudge, not every context-injection hook.
- **Secrets in hook source go to Security, not here.** A hardcoded bearer token / fallback token / API key in a hook script is credential exposure — file it under **Security** (credential exposure patterns) and do not duplicate it as a Hooks finding. If a defect is both, file the more severe (Security).
- **"This skill has no hook" is Convention's concern, not a Hooks finding.** Hooks only fires when a hook associated with the skill *exists*. Do not manufacture a Hooks finding for a hookless skill — if a deterministic trigger would help, that's Convention § Hook Integration.
- **A hook reacting to an event the model can't see is correct.** `PreCompact`, `SessionEnd`, `SessionStart` (for real environment setup), config-change, and notification hooks are doing (4) on the decision test — do not flag them as advertisement just because they inject text.

## Boundary With Convention and Security

- **Convention § Hook Integration** asks *"should this hookless skill gain a hook to fire more reliably?"* — a triggering/placement-fit opportunity, verdict usually "no hook needed". **Hooks** asks *"is the hook this skill already has justified and well-built?"* — a hook-quality judgment. When Convention would recommend adding a *context-injection* hook to improve triggering, defer to this category's migration protocol first: prefer a deterministic gate or a hardened, evidence-justified nudge over an unconditional advertisement hook.
- **Security** owns any credential in hook source. **Hooks** owns everything else about the hook's shape, cost, and justification.

## Rewrite Policy

**Produce a suggested rewrite for the mechanical script defects** — `raw-payload-grep` (show the `jq` field parse), `nonstandard-block-convention` (show `exit 2` + stderr + the failure-posture header comment), and `unnarrowed-matcher` (show the reordered cheap-first short-circuit). Fixed snippet inside the finding's collapsible details block per [`suggested-rewrites.md`](./suggested-rewrites.md).

**Describe the fix in prose for the judgment findings** — `skill-advertisement-hook` (state the migration protocol: the evidence gate for delete-vs-keep-and-harden; do not emit a delete-only rewrite), `heavy-work-in-hook` (name where the heavy work belongs), `hot-event-hook` (name the narrower event, or the once-per-session dedup), `duplicate-hook` (name the canonical shared hook), `uncleaned-marker` (describe the TTL / `PreCompact` invalidation), `oversized-injection` (name the cap + where static content belongs).

## Notes for Implementers

- The unit of review is still the skill. Reach the plugin's hooks by reading `hooks/hooks.json` at the plugin root and the scripts it references — the same way this skill already reads plugin-root scripts a skill invokes. Only evaluate hooks tied to the skill under review (they name it, advertise it, or gate its domain); a plugin's unrelated hooks are out of scope for that skill's review.
- The `skill-advertisement-hook` migration protocol is deliberately conservative because a naive "delete the hook and move the nudge to CLAUDE.md" migration has a real failure history: the description/CLAUDE.md substitute did not fire the skill as reliably as the hook, and the change was reverted once users noticed the regression. Require the evidence gate before recommending deletion.
