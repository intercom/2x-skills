---
name: skill-review
description: >
  Review Claude Code skills against substantive quality standards — a 7-category
  rubric with JSON output, single-pass full-rubric review, and a determinism contract.
  Complements Anthropic's `plugin-dev:skill-reviewer` (structural checks).
  Use for: "review a skill", "check skill quality", "does this skill need evals",
  "review skill quality".
version: 0.1.0
---

# Skill Review

## Purpose

Review skills for substantive quality signals that Anthropic's `plugin-dev:skill-reviewer` does not cover. That agent handles structural concerns (frontmatter format, word count, writing style, progressive disclosure). This skill focuses on **substance** — whether the skill gives Claude the right kind of content, has appropriate test coverage, uses hooks effectively, and lives in the right location.

The rubric is **authoritative and closed.** Every finding type the reviewer can surface is enumerated in the per-category reference files. Reviewers match against the rubric; they do not invent new buckets. If a concern doesn't fit any enumerated finding type, it belongs in the out-of-rubric channel — never inline as Critical/Major/Minor.

**Closed does not mean conservative.** "Closed" constrains the *set* of finding types you may emit — it does **not** mean you should hesitate to apply the ones that exist. The two are independent: never invent a new finding type, AND never withhold a defined one when its predicate plausibly matches. The judgment-bound finding types — `operational-guardrail-untested` (Test Coverage), `contradictory-instructions` and the three Behaviour sub-checks (Integrity), `procedure-smell-with-consequence` (Content Quality), the orchestration pair (Cost/Convention) — are the ones a reviewer most often *under*-fires, because the defect is buried in an otherwise-sound skill and nothing jumps out on a first read. For these types, **`pass` is a claim that must be earned, not a default**: a category may be marked `pass` only after you have positively checked the predicate (enumerated every guardrail and cross-checked it against the evals, read every referenced script, compared every same-condition instruction pair) and found it does not hold — not merely because no red flag was salient. When a defined predicate plausibly matches, fire it; absence of an obvious problem is not evidence of absence.

## How a Review Runs

A review is a **single pass**: load every category reference, evaluate all seven categories against the skill, and emit the full JSON. There is no triage gate — no category is skipped for looking clean, so a finding can never be missed because its category's deep-dive reference was never opened. This trades token spend for recall by construction.

1. **Read the skill folder and the scripts it invokes.** SKILL.md body and frontmatter, `references/` listing, `evals/` listing, and any scripts the skill ships **or invokes** — both scripts under the skill's own `scripts/` and shared scripts at the plugin root (e.g. `${CLAUDE_PLUGIN_ROOT}/scripts/...`) that the SKILL.md references and tells Claude to run. A skill whose scripts live at the plugin level is the common case, not the exception — Glob for the referenced script paths and read them; do not treat "no `scripts/` dir inside the skill folder" as "no scripts to review". Every check in this skill is performed by reading — Read, Grep, and Glob are the only tools needed. Note the skill's **reach** (a widely-shared skill published in a plugin/marketplace vs a personal or project-local skill) and its diff status (`M` if it's being modified in this PR) — Test Coverage and the stale-eval checks depend on both.
2. **Load all seven category references.** Read every deep-dive listed in [Reference Files](#reference-files) before evaluating. Load `suggested-rewrites.md` too if any finding will need a rewrite. Each reference owns the finding types, severity tiers, false-positive guardrails, and rewrite policy for its category — applying a category without its reference loaded is not permitted.
3. **Evaluate every category.** Apply each reference's rubric to the skill by reading it directly. A category with no matching finding emits `{"status": "pass", "findings": []}`; otherwise it emits its findings with `finding_type`, `severity`, `deterministic`, `location`, `explanation`, `fix`, and optionally `suggested_rewrite`. A skill that is mostly deterministic glue (pinned queries, fixed tool/MCP call sequences, output templates) — counting body **and** `references/` — is the `script-extractable-orchestration` (Cost) / `orchestration-shaped-skill` (Convention) pair; single-pass already loads both references every run, so no triage hint is needed to reach it.
4. **Emit structured JSON.** Output the full JSON — all seven categories, including the ones that passed clean — per the [Output Contract](#output-contract) below. This skill's contract ends at the JSON.

## Categories

| Category | Scope | Deep dive |
|----------|-------|-----------|
| **Structural Discipline** | Body shape and progressive-disclosure hygiene | [`structural.md`](./references/structural.md) |
| **Integrity** | Claims resolve: cross-plugin / MCP / command references resolve, instructed tools are declared in `allowed-tools`, paired files match, prose counts agree, instructions don't contradict each other, bundled scripts work | [`integrity.md`](./references/integrity.md) |
| **Test Coverage** | Evals exist for skills with broad reach; operational guardrails are exercised; evals actually test what they claim (no stale or false-coverage evals) | [`test-coverage.md`](./references/test-coverage.md) |
| **Security** | No credential exposure, no plaintext-secret instructions, safe shell idioms, transport security not disabled | [`security.md`](./references/security.md) |
| **Content Quality** | Context vs instructions, procedure smell, weak completion criteria, no-op instructions — does the body teach Claude something it couldn't derive, without restating defaults | [`content-quality.md`](./references/content-quality.md) |
| **Convention** | Placement + triggering: where the skill lives (personal / project / plugin), similar-skill duplication, hook integration, invocation mode (a skill that can't usefully auto-fire — slash-command-only or a sealed-input sub-routine — still shaped for auto-fire), repo-convention adherence (frontmatter fields — e.g. an agent's `model:` — vs the repo's documented conventions) | [`convention.md`](./references/convention.md) |
| **Cost** | Runtime token-spending patterns: bash chains, MCP result-size, field projection, response style | [`cost.md`](./references/cost.md) |

**Category boundaries worth calling out:**
- **Structural vs Cost** — both touch token waste, but Structural owns *body shape* (length, body↔references duplication, flat reference lists) and Cost owns *runtime spending patterns* (script-extractable chains, MCP defaults, response narration). Body↔references duplication is Structural even though it also wastes tokens.
- **Content Quality vs Convention** — Content Quality is about what's *in* the body (context vs instructions). Convention is about where the skill *lives* and how it *fires* (placement, similar skills, hooks). A skill can have perfect content but a missing hook, or vice versa.
- **Integrity vs Security** — both read the skill's bundled scripts, but they ask different questions. Integrity asks *do the skill's claims hold?* — both that named things resolve (file/skill/command/MCP tool exists) and that the code it ships actually works (no crash, no hardcoded-environment break, no silently-wrong output). Security asks *is it safe?* (credential exposure, injection, path traversal). A `rm -rf "$unvalidated"` is Security; a `KeyError` on a documented input or a call to a non-existent MCP tool is Integrity. A defect that is both → file the more severe.
- **Cost ⊕ Convention for deterministic orchestration** — the one *intentional* two-finding case. A skill that is mostly deterministic glue end-to-end (pinned queries + fixed call sequences + output templating, often hiding in `references/`) is filed in BOTH Cost (`script-extractable-orchestration`, the per-session token-cost lens) AND Convention (`orchestration-shaped-skill`, the marketplace-shape lens). Both are **Major by default** with a strict firing bar (fire on *dominance* of glue, never mere presence) and share one extract-glue fix — move the pipeline into a bundled `scripts/` file, keep a thin skill over the judgment kernel; never recommend deleting the skill. A *single* extractable chain in an otherwise-sound skill is Cost-only (`scriptable-bash-chain`), not this pair.

Each category reference is self-contained. It defines the scope, the finding types in its rubric, the severity tier each one carries, the false-positive guardrails, the non-obvious constraints reviewers must apply, and the rewrite policy for its category. To find out what a Major finding in Integrity looks like, read `integrity.md` — no other file owns that information.

If a candidate finding doesn't clearly belong to any category, it's an out-of-rubric concern — log it in the JSON `out_of_rubric[]` channel (see [Output Contract](#output-contract)). Do not invent a new category to fit it.

## Output Contract

**The reviewer's final message MUST be a single fenced ```json``` code block matching the schema below — and nothing else.** No preceding markdown headings, no trailing prose, no "## Skill Review" wrapper, no narration. The JSON is the artifact. Downstream consumers (a CI action's markdown renderer, dashboards, anyone running the skill locally) parse this JSON; whatever decoration the LLM might add is wasted tokens and breaks the parser.

```json
{
  "skill": "<skill-name-and-path>",
  "categories": [
    {
      "name": "Structural Discipline",
      "status": "pass",
      "findings": []
    },
    {
      "name": "Integrity",
      "status": "findings",
      "findings": [
        {
          "finding_type": "broken-cross-plugin-reference",
          "severity": "major",
          "deterministic": true,
          "location": "SKILL.md:42",
          "explanation": "Reference `acme-tools:nonexistent-skill` does not resolve in the repo.",
          "fix": "Create the skill, fix the reference, or remove the claim.",
          "suggested_rewrite": null
        }
      ]
    },
    {
      "name": "Content Quality",
      "status": "findings",
      "findings": [
        {
          "finding_type": "procedure-smell-with-consequence",
          "severity": "major",
          "deterministic": false,
          "location": "SKILL.md:22-38",
          "explanation": "Section `## Checking Deployments` is a 6-step numbered procedure teaching generic deploy-tool usage Claude already knows. Concrete behavior caused: in a sample review fixture, Claude followed the steps verbatim instead of adapting to the user's actual question about a stuck stage.",
          "fix": "Replace the numbered procedure with declarative context (which stages tend to get stuck, what locked stages mean, common quirks).",
          "suggested_rewrite": "## Deployment Context\n\n- **Stuck stages**: The `asset-compile` stage is the most common bottleneck — it can take 15-20 minutes. If longer, check the sub-deployment logs for OOM kills.\n- **Locked stages**: A locked production stage usually means an active incident — check the incident channel before unlocking. Only on-call can unlock production.\n- **Approval flow**: Production stages need the PR author's team lead approval. Staging auto-approves. Missing approval often means the author merged from a fork.\n- **Rollback signals**: >2 rollbacks in the last hour for the same app may indicate an active incident — check the incident thread before re-deploying."
        }
      ]
    }
  ],
  "out_of_rubric": [
    {
      "location": "SKILL.md:54",
      "explanation": "Skill body declares an unusual prompt-caching strategy that doesn't fit any current finding type.",
      "rationale": "Cost concern, but not the bash-chain, MCP-result-size, field-projection, or response-style pattern. Logged for monthly rubric review."
    }
  ]
}
```

Field rules:

- `categories[]` includes all seven categories in rubric order, even when empty. Status is `pass` when `findings: []`, `findings` otherwise.
- `finding_type` is a kebab-case identifier defined in the per-category reference. Reviewers do not invent new identifiers.
- `severity` is `critical | major | minor` — the value the category reference assigns to that finding type, including any explicit escalation predicate.
- `deterministic: true` indicates the finding follows mechanically from reading the file (e.g. cross-plugin reference resolution, prose-vs-table count, a documented-convention frontmatter-field check) and so must be stable across reruns. `false` indicates judgment-bound (rerun variance is expected). The determinism eval filters on this flag.
- `location`, `explanation`, `fix` are required on every finding. `suggested_rewrite` is the rewrite block content per the per-category rewrite policy; `null` when the policy is "describe in prose only".
- `out_of_rubric[]` uses the same shape as a finding (minus `finding_type`, `severity`, `deterministic`) — `location`, `explanation`, and `rationale` are required. These never appear in the PR comment; they're logged for monthly rubric review (a maintainer promotes a finding type with ≥3 instances or a security implication via a follow-up PR).

## Determinism Contract

Same skill + same rubric → same findings. The contract is *not* "byte-identical output" — LLM prose varies. The contract is:

- **Severity stability** — every deterministic finding type produces the same severity across runs.
- **Finding-set stability** — the set of deterministic finding types reported as present is identical across runs.
- **Order stability** — categories appear in rubric order; findings within a category appear in rubric order.
- **Not promised** — prose `explanation` wording, prose `fix` wording, prose inside `suggested_rewrite`. LLM variance is allowed there by construction.

The `deterministic` field on each finding sets its testing contract:

| `deterministic` | Meaning | Determinism-eval scope |
|---|---|---|
| `true` | Follows mechanically from reading the file — cross-plugin / MCP / command reference resolution, paired-file byte-diff, prose-vs-table count, documented-convention frontmatter-field check | In scope — assert finding presence + severity across reruns, allow prose variance |
| `false` | Judgment-bound (procedure smell, similar-skill verdict, behaviour bugs, stale evals, etc.) | Out of scope — filtered out of the determinism eval |

Mark a finding `deterministic: true` only when its presence and severity follow mechanically from the file — never on a judgment call. A deterministic finding that flickers between runs is a bug in the reviewer, not acceptable LLM variance.

## Reference Files

Load all seven category references at the start of every review — each category is evaluated every run. Load `suggested-rewrites.md` as well whenever a finding will carry a rewrite.

- [`references/structural.md`](./references/structural.md) — Structural Discipline (body↔references duplication, conditional reference loading). Load when assessing structural findings.
- [`references/integrity.md`](./references/integrity.md) — Integrity (existence + equivalence; cross-plugin reference blast-radius rules). Load when assessing integrity findings.
- [`references/test-coverage.md`](./references/test-coverage.md) — Test Coverage (eval-requirement by reach, operational-guardrail-untested predicate, eval-quality minors). Load when assessing eval coverage.
- [`references/security.md`](./references/security.md) — Security (credential paste, plaintext secrets, executable-script bugs). Load when assessing security findings.
- [`references/content-quality.md`](./references/content-quality.md) — Content Quality (procedure smell, context-vs-instructions, the rewrite method). Load when assessing what's in the skill body. Hook integration is NOT here — see `convention.md`.
- [`references/convention.md`](./references/convention.md) — Convention (placement, similar-skill duplication, hook integration, repo-convention adherence like an agent's `model:` field). Load when assessing placement and triggering findings.
- [`references/cost.md`](./references/cost.md) — Cost (bash chains, MCP result-size nudges, field projection, response-style discipline). Load when assessing token-efficiency findings.
- [`references/suggested-rewrites.md`](./references/suggested-rewrites.md) — Cross-cutting **format** spec for the rewrite block (details block, placement, authoring constraints). The decision *whether* to rewrite for a given finding lives in that finding's category reference. Load when producing a rewrite.
