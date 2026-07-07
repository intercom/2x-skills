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

5. **NEVER narrate code changes.** Don't explain what the code does in human language. The diff shows the implementation.

6. **NEVER speculate on risks.** Only include risks if the user explicitly mentioned them.

7. **NEVER include a "Test plan" section.** Omit any test plan, test checklist, or testing instructions from PR descriptions.

8. **NEVER call `gh pr create` without first running `check-pr-context.sh`.** Step 1.5 (`check-pr-context.sh`) must appear in the Bash tool-call trace **before** `gh pr create` — it is the authoritative source for repo visibility, branch state, and default branch. Never infer its output from prompt text, prior turns, session context, or your own judgement — the script is cheap, deterministic, and non-substitutable. "The user said the repo is private" / "I already know the branch name" / "the intent is obvious" are NOT reasons to skip. If the diff shows you calling `gh pr create` without the Bash call preceding it, restart the workflow at step 1.5.

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

**Description format:**
```markdown
### Why?

[The problem we're solving - from user's explanation, NOT fabricated]

### How?

[High-level approach - 1-2 sentences. Do NOT list changes or files. The diff shows the implementation.]

<details>
<summary>Implementation Plan</summary>

[PLAN_CONTENT — see "Finding the plan file" below. If no plan file found, omit this entire <details> section.]

</details>

<sub>Generated with Claude Code</sub>
```

**Issue/PR references:** When referencing related issues or PRs, use bulleted lists (`- #123`) so GitHub renders them as rich linked cards.

**Avoid accidental issue links:** On GitHub, `#` followed by a number (e.g., `#1`, `#42`) automatically creates a hyperlink to the issue/PR with that number. Only use `#NUMBER` when intentionally linking to an issue or PR. Never use it in prose like "the #1 cause" or "#3 priority" — rephrase instead (e.g., "the top cause", "third priority"). If a literal `#` before a number is unavoidable, escape it with a backslash (`\#1`).

**Finding the plan file:**

1. **Check conversation history first.** Look in this conversation for a system message containing a path like `~/.claude/plans/<name>.md`. When plan mode was used, the system always injects the full path. Use it directly with the Read tool.
2. **If not in history**, run `ls -t ~/.claude/plans/*.md | head -5` via Bash to get the 5 most recently modified plan files. Read the first few lines of each to identify which one matches the current task. If no plan clearly matches, or the match is ambiguous, omit the plan section. (Do NOT use Glob for this — Glob sorts alphabetically by filename, not by modification time, and plan filenames are random.)
3. Paste the plan file's full markdown contents into the `<details>` block. Do NOT include the file path — plan files are gitignored and won't exist in the PR.
4. If no plan file is found by either method, omit the entire `<details>` block.

**Optional sections** (only if user explicitly discussed):
- `### Decisions` - if user explained trade-offs or choices made
- `### Risks` - ONLY if user mentioned specific concerns

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
