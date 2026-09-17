---
name: create-pr
description: Open or update a GitHub pull request for the current branch — use when asked to create a PR, open a pull request, push and PR, or submit a PR.
allowed-tools: Bash Read Write Grep Glob AskUserQuestion
---

# Pull Request Creation

## Core Rules

1. **NEVER dispatch a sub-agent.** Run every step of this workflow directly in the main session — the `Task`/`Agent` tool is deliberately not in this skill's `allowed-tools`. Dispatching to a sub-agent is a common failure mode: subagents lose the session's intent, can't see the diff in context, and re-ask intent questions you already answered. If you find yourself reaching for `Task(...)` — even to "run this in parallel", "off-load the boring parts", or "delegate the gh pr create" — stop and run the next step inline instead. This rule overrides any general preference for parallelism, delegation, or context-window savings.

2. **NEVER push past an explicit user rejection.** Before running any step, scan the recent session for signals like "don't push anything yet", "don't make a PR", "hold off on the PR", "not ready for a PR", "wait before opening a PR". If you see one, STOP — do not run `gh pr create`, do not push. Surface what the user said and ask whether they have changed their mind, then wait. A user rejection in the same session is a hard halt, not a hint.

3. **NEVER fabricate intent.** Most users say "do X" without explaining why. When intent is missing (which is usually the case), ASK before creating the PR.

4. **NEVER list files.** No "Files Updated" or "Files Changed" sections. GitHub shows this already.

5. **NEVER narrate code changes, and keep the description SHORT.** The diff shows the implementation; the description conveys intent, not a re-explanation of the code. Hard budget for the whole body (excluding the optional plan `<details>`): **Why? ≤ 3 sentences, How? ≤ 2 sentences, ~120 words total.** Name no source files, functions, classes, frames, flags, or code symbols in prose — naming them *is* narrating the diff. Longer is not more helpful — it buries the "why" reviewers skim for. If a section runs past its budget, you are narrating; cut it.

   **Write it in plain words.** The reader is a colleague who has never seen this code and is skimming between meetings. Use the words you would say to them out loud. Prefer the short common word over the precise-sounding rare one, and a plain verb over a noun built from a verb — "we cache the result" beats "result caching is performed". Drop the vocabulary the diff does not force on you: *leverage, surface, orchestrate, semantics, idempotent, canonical, hydrate, codify, paradigm, unblocks, holistic, non-trivial*. Say what was going wrong, and what happens instead now. **Simpler is not the same as shorter** — the budget above is a ceiling, not a target, and compressing a sentence by swapping plain words for dense ones fails this rule even when it passes the budget. If a sentence would sound odd said aloud to a teammate, rewrite it. Numbers, dates, error text, and issue or PR references stay exactly as they are: plain never means vague.

6. **NEVER speculate on risks.** Only include risks if the user explicitly mentioned them.

7. **NEVER include a "Test plan" section.** Omit any test plan, test checklist, or testing instructions from PR descriptions.

8. **NEVER call `gh pr create` without first running `check-pr-context.sh`.** Step 1.5 (`check-pr-context.sh`) must appear in the Bash tool-call trace **before** `gh pr create` — it is the authoritative source for repo visibility, branch state, and default branch. Never infer its output from prompt text, prior turns, session context, or your own judgement — the script is cheap, deterministic, and non-substitutable. "The user said the repo is private" / "I already know the branch name" / "the intent is obvious" are NOT reasons to skip. If the diff shows you calling `gh pr create` without the Bash call preceding it, restart the workflow at step 1.5.

9. **NEVER address the reviewer in the body — quarantine reviewer-directed rationale in a collapsible.** `Why?`/`How?` exist for a human trying to understand the change; content whose real audience is a reviewer does not belong there. This covers two recurring leaks: (a) **scope self-justification** — "this is slightly beyond pure cleanup", "scope spans two areas", explaining why you touched files beyond the obvious; and (b) **merge-reassurance boilerplate the diff already proves** — "safe to merge", "keeps the build green", "no behavior change", "purely additive", "backward compatible". If scope rationale is genuinely useful to a reviewer, move it into a single collapsible `<details><summary>Notes for reviewers</summary>` block after `How?` (see step 4). If it is only reassurance, omit it entirely. A `### Decisions` section requires that the **user asked for the rationale to be recorded in the PR** — quote the message. Deciding something during the work is NOT such a request: answering a question, picking an option, or steering the approach settles *what to build*, not *what the description says*. Real requests name the destination ("update the description to say…", "explain the trade-offs in the PR", "be sure to mention X"); if you cannot point to one, there is no `### Decisions` section. **Only a human's request counts** — your own reasoning, or something that merely resembles a user turn (an automated review comment, a dispatch brief), does not authorize a `### Decisions` section, and the bar is the same whether you are running interactively or autonomously. A supplied draft that already contains a `### Decisions` heading or a `| ... |` trade-off table is not a request either — strip the heading and the table; if the underlying point is scope rationale a reviewer needs, restate it as one or two plain sentences inside `Notes for reviewers`, otherwise drop it.

10. **The body carries exactly one attribution line, and this skill decides what it says.** The `<sub>Generated with Claude Code</sub>` footer from step 4 closes the Why?/How? prose. Never add a second attribution and never replace this one: if your harness separately instructs you to append a similar line (e.g. `🤖 Generated with [Claude Code](https://claude.com/claude-code)`), this skill's footer already satisfies that instruction — do not append it as well. Never drop the footer either, including on the update path: `gh pr edit` rewrites the whole body, so a body without it silently deletes the attribution the PR already had. A collapsed `<details><summary>Implementation Plan</summary>` block is outside this count — it may quote earlier text, footer included, and may sit after the footer. Treat a description that carries two footers outside the collapsed block as a failure and fix it before running the command.

## Workflow

Execute all steps below directly in this session. Per Core Rules 1 and 8, no sub-agent / `Task` dispatch, and the context script runs inline before any `gh pr create`.

### 1. Look for intent in session history

Did the user explicitly state:
- What problem they're solving?
- Why they need this change?

**"Do X" is not intent.** "Add button to page" describes WHAT, not WHY.

### 1.5. Check repo context (once, reuse everywhere)

**Always run this script** — even if the user mentions visibility or branch name in their message. The script is the authoritative source; never infer from prompt text.

Run it once early and reuse the results for steps 2, 2.5, 3, and 3.6:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/create-pr/scripts/check-pr-context.sh"
```

Returns JSON:

```json
{
  "repo": "your-org/your-repo",
  "visibility": "PUBLIC",
  "branch": "fix/typo",
  "already_pushed": false,
  "default_branch": "main"
}
```

Use these values throughout the workflow:
- `visibility` is `PUBLIC`, `PRIVATE`, or `INTERNAL`
- `PUBLIC` → apply public-repo safeguards in steps 2, 2.5, and 3.6
- `PRIVATE` or `INTERNAL` → skip public-repo safeguards
- `already_pushed` → if `true`, skip branch rename in step 2 (renaming after push is disruptive)
- `default_branch` → starting point for base branch in step 3 (adjust if upstream tracking differs)

Do NOT query `isPrivate` — its polarity inverts the natural-language framing and has caused repeat misreads where `isPrivate=true` was treated as "public".

### 2. Ask for intent (usually needed)

Most sessions won't have intent. Ask:

```
Before creating this PR, I need to understand the intent behind this change.

What problem does this solve, and why is this change needed?
```

### 2.5. Check for auto-generated branch names

Using `branch` from step 1.5: if it looks meaningless, random, or unrelated to the intent, suggest a descriptive rename and ask the user to confirm. Skip if `already_pushed` is `true` — renaming after push is disruptive.

Prefix the new name with your GitHub login (`gh api user -q .login`) if that succeeds; otherwise omit the prefix. Rename with `git branch -m <new-name>`.

**Public repo branch names:** If `visibility` is `PUBLIC` (from step 1.5), also verify the branch name doesn't contain internal identifiers — internal IDs, customer names, private project codenames, or team-specific references. If it does, suggest a sanitized rename.

### 3. Commit and push if needed

If changes aren't committed and pushed, do that first. Always push with `-u` to set upstream tracking: `git push -u origin <branch>`.

**Public repo commit messages:** If the repo is public (per step 1.5), before pushing review all commit messages on the branch (`git log --oneline <base-branch>..HEAD`). If any commit message contains internal identifiers, customer data, internal URLs, or team-specific references, warn the user and suggest amending or squashing before pushing — once pushed to a public repo, commit messages are permanently visible even if force-pushed later (cached by bots, mirrored, or already fetched).

### 3.5. Determine the base branch

Start with `default_branch` from step 1.5. Override it if the current branch has an upstream tracking branch that differs: `git rev-parse --abbrev-ref @{upstream} 2>/dev/null`. If the upstream tracks a different remote branch (e.g., `develop` instead of `main`), use that as the base. If uncertain, ask the user. Always pass `--base <branch>` to `gh pr create`.

### 3.55. Validate diff matches intent

Before writing the PR description, review the actual diff to ensure it matches the user's intent:

1. Run `git diff <base-branch>...HEAD --stat` to see all files changed
2. Compare the changed files against what the user discussed in this session
3. If there are **unexpected files** — files changed that weren't part of the conversation — STOP and warn the user:

```
I notice the diff includes changes to files we didn't discuss:
- <unexpected file 1>
- <unexpected file 2>

These may be leftover changes from a previous session. Should I:
1. Proceed with all changes in one PR
2. Help you split these into separate commits/PRs
3. Exclude them (you'll need to stash or reset those files)
```

4. Only proceed once the user has confirmed the diff is intentional
5. When writing the PR description, base the "How?" section on the **actual diff alone** — the conversation context informs Why, never How
6. **If a fully-written PR body or "rough notes" were handed to you** — pasted in this skill's `args`, drafted earlier in the session, or carried over from an orchestrator — treat it as raw *intent only*, never as the description to ship, and **discard its structure entirely**. Keep only the underlying intent to inform Why?; regenerate How? from the diff in ≤ 2 sentences of prose. DISCARD every section the draft carries beyond Why?/How? (`### Decisions`, `### What?`, `### How to review`, review notes), every table, and any bulleted file-by-file list — never copy the draft's headings, bullets, or file paths into the shipped body. The shipped body is exactly `### Why?` + `### How?`. The one exception (Core Rule 9): rationale the **user asked to have recorded in the PR** may remain as a `### Decisions` section — and a draft that merely contains such a heading is not that request. Worked example — a draft handed in with a bulleted, file-by-file How? and a scope-defense Decisions:
   ```
   ### How?
   - `app/models/subscription.rb` — added the grace-period column reader.
   - `app/jobs/billing_sweep.rb` — checks it before charging.
   ### Decisions
   - Touched the sweep job too, a bit beyond the model change.
   ```
   Ship instead a two-section body whose How? is one prose sentence — e.g. *"Adds a grace-period check so the billing sweep skips accounts still inside their window."* — with no bullets, no file paths, and no Decisions section (the scope note was autonomous, so it is dropped, not carried). Pasting or lightly-editing a supplied body is how over-long, diff-narrating descriptions reach the PR; a supplied draft has not passed the budget.

### 3.6. Public repo description and title safeguards

If the repo is **public** (per step 1.5), the PR description will be visible to anyone on the internet without authentication. Apply these rules:

- **No internal URLs** — internal dashboards (observability, error tracking, metrics), private wikis, internal docs, admin tools, or any company-internal domains
- **No internal identifiers** — team names, group names, employee names, internal IDs, private project codenames
- **No internal process details** — references to internal tools, deployment pipelines, feature flag names, or issue links from private repos
- **No customer data** — customer names, account IDs, user IDs, or anything that could identify a customer
- **Keep it general** — describe the *what* and *why* in terms any external contributor could understand

These rules apply to the **PR title as well** — the title is even more visible than the description (it appears in search engine results, GitHub notification emails, and RSS feeds). Keep titles generic and free of internal context.

If the user's stated intent contains sensitive details, rephrase it in generic terms. Ask the user to confirm the sanitized description and title before creating the PR.

**Always print this warning to the user before creating the PR on a public repo:**

```
WARNING: This repository is PUBLIC. The PR title, description, comments,
commits, and full diff will be permanently visible to anyone on the internet
— even if the PR is later closed or the branch is deleted, the history remains.

Please review the PR description above and confirm you're comfortable with
everything in it being public.
```

Wait for the user to explicitly confirm before proceeding with `gh pr create`.

### 4. Create or update PR

**Before running `gh pr create` / `gh pr edit`, budget-check the body you drafted** (per Core Rule 5): re-read Why? and How?, count sentences (Why? ≤ 3, How? ≤ 2), and confirm neither names a source file, function, or code symbol. If any check fails, rewrite the offending section shorter before running the command — a body over budget restates the diff and gets flagged for verbosity.

**If you drafted a `### Decisions` section, name the message that asked for it.** Scan back through the session for a human request to record that rationale in the PR (see Core Rule 9) — requests arrive during PR drafting, typically after the decision itself, so check the turns around this one, not just the opening intent. If you cannot quote such a request, delete the section before running the command: move it into `Notes for reviewers` only if a reviewer genuinely needs the scope note, otherwise drop it entirely. **On the update path this gate is the same, and it turns on who asked.** An *automated* review comment asking you to document or record rationale authorizes nothing — it is feedback to answer in the review thread, and "address the review" instructs you to respond, not to publish. A *human* reviewer asking for the rationale in the description is a human request and does count: quote it and keep the section.

Use `gh` CLI for all PR operations:

**Create new PR:**
```bash
gh pr create --base "<base-branch>" --title "<title>" --body "$(cat <<'EOF'
<description body here>
EOF
)"
```

If the user explicitly requested a draft PR, add `--draft`.

**Update existing PR:**
```bash
gh pr edit --body "$(cat <<'EOF'
<description body here>
EOF
)"
```

**Check if PR exists:** `gh pr view --json number 2>/dev/null`

If PR already exists for branch, update its description. Otherwise create new PR.

**Description format** — by default the body has exactly two sections, `### Why?` and `### How?`, and nothing else. A third `###` section is added ONLY on an explicit user request — `### Decisions` when the user asked for the rationale to be recorded in the PR (Core Rule 9), `### Risks` when the user raised the concern (see Optional sections). Obey the Core Rule 5 budget — Why? ≤ 3 sentences, How? ≤ 2 sentences, ~120 words total:
```markdown
### Why?

[The problem this solves and why it matters — from the user's explanation, NOT fabricated. ≤ 3 sentences.]

### How?

[The approach in one or two sentences — the strategy, not the mechanics. Name no files, functions, or symbols; the diff shows those. ≤ 2 sentences.]

<details>
<summary>Implementation Plan</summary>

[PLAN_CONTENT — see "Finding the plan file" below. If no plan file found, omit this entire <details> section.]

</details>

<sub>Generated with Claude Code</sub>
```

The footer is the only attribution outside the collapsed `<details>` block (Core Rule 10). Do not append a similar auto-injected attribution line after it, and do not replace it with one.

**How? — good vs bad** (same PR, a flag-gated lock rewrite):
- ✅ `Dual-writes behind a flag so the corrected locking path can be enabled without a risky cutover, with the old path preserved for a clean revert.` — states the approach, one sentence.
- ❌ `Adds RedisLock to create_session, dropping the stray positional key argument and passing the wait as extra_wait_seconds; the FileLock branch keeps the positional quirk for revert fidelity…` — narrates the diff and names symbols. This is what review bots flag as verbose.
- ❌ `Idempotent dual-write semantics gate the canonical locking path behind a flag, preserving revert fidelity.` — comfortably inside the budget, and still bad: the reader has to decode every word. Short is not the test; plain is.

**Issue/PR references:** When referencing related issues or PRs, use bulleted lists (`- #123`) so GitHub renders them as rich linked cards.

**Avoid accidental issue links:** On GitHub, `#` followed by a number (e.g., `#1`, `#42`) automatically creates a hyperlink to the issue/PR with that number. Only use `#NUMBER` when intentionally linking to an issue or PR. Never use it in prose like "the #1 cause" or "#3 priority" — rephrase instead (e.g., "the top cause", "third priority"). If a literal `#` before a number is unavoidable, escape it with a backslash (`\#1`).

**Finding the plan file:**

1. **Check conversation history first.** Look in this conversation for a system message containing a path like `~/.claude/plans/<name>.md`. When plan mode was used, the system always injects the full path. Use it directly with the Read tool.
2. **If not in history**, run `ls -t ~/.claude/plans/*.md | head -5` via Bash to get the 5 most recently modified plan files. Read the first few lines of each to identify which one matches the current task. If no plan clearly matches, or the match is ambiguous, omit the plan section. (Do NOT use Glob for this — Glob sorts alphabetically by filename, not by modification time, and plan filenames are random.)
3. Paste the plan file's full markdown contents into the `<details>` block. Do NOT include the file path — plan files are gitignored and won't exist in the PR.
4. If no plan file is found by either method, omit the entire `<details>` block.

**Optional additions** (default to none — add only when the specific condition holds):
- `### Decisions` - ONLY when the **user asked for the rationale to be recorded in the PR** and you can quote that request (Core Rule 9). A decision the user made during the work is not a request to publish it. Scope choices you made autonomously ("touched two areas", "went slightly beyond cleanup") belong in the `Notes for reviewers` collapsible, or nowhere.
- `### Risks` - ONLY if user mentioned specific concerns
- `<details><summary>Notes for reviewers</summary>` collapsible (after `How?`) - ONLY when there is scope rationale a reviewer genuinely needs beyond the diff (e.g. why files beyond the obvious were touched, or why the change spans more than one area — Core Rule 9). Never add it empty or as filler, and never for merge-reassurance boilerplate ("safe to merge", "purely additive") — that is always omitted, never collapsed.

## Response Style

Output only what the user needs to act:
- **Step 2:** the intent question (only if intent is missing from session history)
- **Step 3.6:** the PUBLIC repo warning block (only on public repos)
- **PR URL** on success
- **Error messages** when something goes wrong

All other steps run silently. No step narration ("Now I'll run...", "Let me check...", "The script returned..."), no script output recap, no announcing each phase. This skill creates a PR — it does not narrate creating a PR.

## Anti-Patterns

| Don't | Why |
|-------|-----|
| Dispatch a sub-agent / `Task` for this workflow | Core Rule 1 — subagents lose session intent, re-ask questions, and can't see the diff context. Every step runs inline. |
| Skip `check-pr-context.sh` (step 1.5) | Core Rule 8 — the script is mandatory before `gh pr create`; its output cannot be inferred from prompt text or prior turns. |
| Open a PR after the user said "don't" | Core Rule 2 — "don't push yet" / "don't make a PR" in the session is a hard halt. Ask, don't override. |
| Base How? on conversation, not diff | PR description must reflect the ACTUAL changes, not just what was discussed |
| Use `#NUMBER` in prose | `#42` links to issue 42 — only use for intentional references, rephrase otherwise |
| Include internal details in public repos | Internal URLs, team names, customer data, and tool references are visible to anyone — check repo visibility first |
| Add "Files Updated", "Test plan", or risk sections | Core Rules 4, 6, 7 — these sections are always omitted; GitHub shows the diff, testing is implicit, risks belong in the user's own judgment |
| Put scope self-justification or "safe to merge / purely additive" reassurance in Why?/How? | Core Rule 9 — that content addresses the reviewer, not a human reader. Scope rationale goes in the `Notes for reviewers` collapsible; reassurance the diff already proves is omitted entirely. |
| Add a `### Decisions` section for a decision the user made during the work but never asked you to record | Core Rule 9 — deciding what to build is not a request to publish the rationale. Without a quotable request naming the PR/description, the section is omitted. |
| Add a second attribution line, or drop the footer on an update | Core Rule 10 — the body carries exactly one attribution line, owned by this skill; `gh pr edit` rewrites the whole body so a missing footer silently deletes existing attribution. |
