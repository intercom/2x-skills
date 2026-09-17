---
name: audit-memory
description: |
  Audit Claude's saved memories for claims that no longer hold true — verify each against current code, PRs and tickets, then archive the stale ones with your approval, and name the MCPs needed for anything unverifiable.
disable-model-invocation: true
allowed-tools: Bash Read Grep Glob Edit Write AskUserQuestion Agent
metadata:
  user-invocable: true
  argument-hint: "[project name to audit] [--root <memory-root>]"
---

# Audit Memory

Saved memories are point-in-time observations. Code moves, PRs merge, projects finish — and a memory that was true when written silently becomes a confidently wrong instruction to every future session. This skill verifies memories against reality and archives what no longer holds.

**Never auto-fires** — it archives user data, so it runs only when someone types `/audit-memory`.

## Core guarantees

These are load-bearing. Violating any of them makes the skill untrustworthy:

1. **Absence of evidence is never evidence of staleness.** A claim you cannot check is `NEEDS-<tool>`, `NOT-ATTEMPTED` or `NOT-CHECKABLE` — never stale, never offered for removal. A disconnected MCP must never turn valid memories into deletion candidates. Two mirrors of this also hold. Never report a check you skipped as a tool that was missing. And never over-apply it: a newer memory stating the old fact was removed **is** positive evidence, sufficient alone — an unreachable repo cannot demote it, because the evidence was never in the repo.
2. **Archive before you touch anything, so nothing is unrecoverable.** Memory files are not version-controlled and have no trash. Snapshot the original into the archive before *any* write or removal — claim removals, whole-file archiving, `MEMORY.md` pointer sync, and `lastReviewed` stamps alike. Removal does mean deleting the file; it is safe only because the verified snapshot precedes it.
3. **Preferences are not claims.** `type: feedback` and `type: user` memories are standing instructions. Never argue they are false — the user is the only authority on whether a preference still applies.
4. **No writes outside the resolved roots.** Only the memory root and archive root are ever written to.
5. **Name the root you actually audited**, before showing findings, and never claim you honoured `CLAUDE_MEMORY_ROOT` unless you read it. Auditing a different corpus than the caller meant is the worst failure here.

## Step 1 — Resolve roots and discover projects

Run this **exactly as written, as a single call**. It resolves both roots and lists every project in one step.

The memory root resolves in this order: an explicit `--root <path>` argument, then `CLAUDE_MEMORY_ROOT`, then `~/.claude/projects`. If the caller passed `--root <path>`, prefix the block with `CLAUDE_MEMORY_ROOT='<path>' ` so both routes land in the same variable.

**Single-quote it, and escape any single quote inside it** by replacing each `'` with `'\''`. Unquoted, a space or metacharacter splits the path; naively quoted, an apostrophe closes the quote early and the rest runs as shell. A path you cannot quote safely is one you refuse, not one you guess at.

Shell variables do not survive between Bash calls, so never split root resolution from the work that uses it, and never pass a root in as `"$MEM_ROOT"` from an earlier call — it will be empty, which is why this block reads the environment directly.

**If this block runs and fails, stop and report the error** — a nonexistent root, a permission error, a traceback. Never retry against `$HOME/.claude/projects` instead (guarantee 5).

`Bash` being unavailable is different — the block never runs, so `CLAUDE_MEMORY_ROOT` is unreadable and you cannot know whether the default root is the intended corpus. That run is **read-only until the root is confirmed**: report findings against `~/.claude/projects`, say which root you used and that the environment was invisible, and make **no write at all** — no archive, no edit, no stamp — until the user confirms it. Findings can be discarded; an archive written against the wrong corpus cannot.

**Never decode project directory names into filesystem paths.** The encoding is lossy: `-Users-me-src-claude-plugins` could be `src/claude-plugins` or `src/claude/plugins`, because path separators and literal hyphens both become `-`. The authoritative `cwd` comes from the project's session transcripts, which is what this block reads.

**If `Bash` is unavailable, do not stop** — fall back to the tool-only path below. Sandboxes and eval harnesses routinely deny `Bash`, and a discovery step with no fallback turns that into a dead end.

```bash
python3 <<'PY'
import glob, json, os, re, subprocess, time

root = os.environ.get("CLAUDE_MEMORY_ROOT") or os.path.expanduser("~/.claude/projects")
# expanduser before resolving: --root is single-quoted, so a leading ~ reaches
# Python literally and would otherwise resolve against the cwd. realpath, not
# abspath, so a symlinked root cannot place the archive outside the resolved
# roots the no-external-writes guarantee is stated against.
root = os.path.realpath(os.path.expanduser(root))
archive = os.path.join(os.path.dirname(root), "memory-archive",
                       time.strftime("%Y-%m-%d"))
print("MEMORY_ROOT=" + root)
print("ARCHIVE_ROOT=" + archive)
print("SOURCE=" + ("CLAUDE_MEMORY_ROOT" if os.environ.get("CLAUDE_MEMORY_ROOT") else "default"))
if not os.path.isdir(root):
    raise SystemExit("memory root does not exist: " + root)

for d in sorted(os.listdir(root)):
    mem = os.path.join(root, d, "memory")
    if not os.path.isdir(mem):
        continue
    # glob.escape the directory: a project dir holding [ ] * or ? would otherwise be
    # read as a pattern and match the wrong memories, or none.
    files = [f for f in glob.glob(glob.escape(mem) + "/*.md")
             if os.path.basename(f) != "MEMORY.md"]
    if not files and not os.path.exists(os.path.join(mem, "MEMORY.md")):
        continue
    cwd = None
    for j in sorted(glob.glob(glob.escape(os.path.join(root, d)) + "/*.jsonl"),
                    key=os.path.getmtime, reverse=True)[:3]:
        try:
            for line in open(j):
                o = json.loads(line)
                if o.get("cwd"):
                    cwd = o["cwd"]
                    break
        except Exception:
            pass
        if cwd:
            break
    # Skip harness debris only where it lives (a temp dir) and only on its actual
    # shape: a name plus a "-" plus a generated suffix, e.g. skill-eval-4rscfuzs.
    # Requiring that hyphen is what keeps a real repo named "skill-evaluator".
    if cwd and re.match(r"(/private)?(/tmp|/var/folders/[^/]+/[^/]+/T)/", cwd) \
           and re.search(r"/(trigger-eval|skill-eval|skill-eval-origin|pytest)-[A-Za-z0-9_]+/",
                         cwd + "/"):
        continue
    # Fall back to cwd itself: a readable working tree that is not a git repo (or a
    # machine with no git) still lets file-path and grep claims be checked, and
    # reporting repo: null there wrongly downgrades every one of them.
    repo = None
    if cwd and os.path.isdir(cwd):
        try:
            r = subprocess.run(["git", "-C", cwd, "rev-parse", "--show-toplevel"],
                               capture_output=True, text=True)
            repo = r.stdout.strip() or cwd
        except (OSError, subprocess.SubprocessError):
            repo = cwd
    # An index-only project is kept above on purpose, so files can be empty; a
    # project with memories but no MEMORY.md is equally valid. Age off whatever
    # exists rather than assuming either is present.
    dated = list(files) + [f for f in [os.path.join(mem, "MEMORY.md")] if os.path.exists(f)]
    newest = max((os.path.getmtime(f) for f in dated), default=None)
    age = int((time.time() - newest) / 86400) if newest else None
    print(json.dumps({"dir": d, "cwd": cwd, "repo": repo,
                      "files": len(files), "newest_age_days": age}))
PY
```

### Fallback when `Bash` is denied

**Read `references/no-bash-fallback.md` and follow it.** It gives the tool-only equivalent of every discovery step, and the rule that a run which could not confirm its root stays read-only.

Then ask which projects to audit. List every project with its file count and newest-memory age; up to 16 fit in one `AskUserQuestion` call (4 questions × 4 options, `multiSelect: true`). Mark projects with `repo: null` as *code claims not checkable* so the choice is informed.

**Skip the picker when there is nothing to choose** — exactly one project discovered, or the user named one as an argument. Audit it and continue to Step 2.

It is also the *only* question asked before findings exist. Everything up to the first proposal is read-only, so never pause to ask whether to begin, to read the memories, or to proceed after discovery — that is how a run ends having audited nothing. Ask once you have something to decide on.

## Step 2 — Fan out one subagent per selected project

Spawn one `Agent` per project, `model: sonnet`, concurrently, giving each the project's memory directory and its resolved repo path.

If a single project is selected and it holds fewer than ~10 memories, verify inline instead — at that size a subagent costs more than it saves. **Read the brief and follow it yourself when you do.** Its rules are about how to verify, not about being a subagent: skipping it is how an inline run reaches for `NOT-CHECKABLE` instead of naming the tool it needed.

Require this exact return shape:

```json
{
  "project": "<dir>",
  "repo": "<path or null>",
  "preferences": [
    {"file": "feedback_x.md", "summary": "<one line, ≤90 chars>",
     "age_days": 42, "mechanism": "ok" | "missing" | "unknown",
     "mechanism_note": "<what is gone, if missing>"}
  ],
  "claims": [
    {"file": "project_y.md", "claim": "<the specific assertion>",
     "verdict": "CONFIRMED" | "STALE" | "NEEDS-<tool>" | "NOT-ATTEMPTED" | "NOT-CHECKABLE",
     "evidence": "<what was checked and found>",
     "occurrences": ["<every exact line/substring in the file asserting this same fact>"],
     "proposed_edit": "<exact text to remove — REQUIRED when verdict is STALE>"}
  ],
  "archetype": {"project_y.md": "LIVING" | "JOURNAL" | "SNAPSHOT" | "NOTE"},
  "index_issues": ["<MEMORY.md pointer with no file, or file with no pointer>"]
}
```

Instruct each subagent to:

Their brief lives in `references/subagent-brief.md` — **read it and pass it to each subagent**. It defines how to route by `type`, which checks are free, how to scope repo lookups, and when each verdict applies. Validate every report against it.

**Validate every report before using it.** Reject and re-ask any subagent that returns a `STALE` claim with a null or missing `proposed_edit`, or whose `proposed_edit` does not appear verbatim in the file. A stale claim with no removable text is a finding that will otherwise be silently dropped — the memory stays wrong and the summary implies it was handled. Also sanity-check `age_days` against the file's own mtime and prefer your own measurement; subagents have reported `0` for every file.

Where a needed MCP is not connected, offer once to connect it and re-run the affected subagents, rather than re-running the whole audit. Where verdicts are `NOT-ATTEMPTED`, offer to re-run those specific checks — the tool was there.

## Step 3 — Preference pass

Merge preferences across projects and dedupe near-identical ones (the same rule often lives in several project directories) — show it once, apply the decision to every copy.

Skip anything already stamped `metadata.lastReviewed` unless its file changed since that date or its `mechanism` is now `missing`.

Present **10 per round** as check-to-drop, using 3 `multiSelect` groups in a single `AskUserQuestion` call (4 + 3 + 3):

- Frame it as **"check the ones to DROP"**. Options always start unselected, so an untouched round removes nothing — deletion must be a deliberate act.
- One line each: name, the ≤90-char summary, age, and `⚠ mechanism gone: <note>` when applicable.
- Never sort by age. Age does not predict staleness for preferences — the oldest rules are typically the most durable.

After each round, ask whether to continue.

On stopping, offer to stamp `metadata.lastReviewed: <today>` on every preference the user *kept and saw*, so the next run resumes instead of restarting. **Ask first** — once, naming the count and files. Stamping writes to files the user just chose to keep, and a file whose only instruction was "leave this alone" is the last place to spring a surprise write. Declining is fine; the next run simply re-asks. Snapshot stamped files like any other write.

## Step 4 — Stale-claim pass

Report `CONFIRMED` and `NOT-CHECKABLE` counts as a summary only. Report the two tool buckets **separately and never merged** — they mean opposite things:

> 9 claims need an issue-tracker MCP (absent) — run `/mcp`, then re-run.
> 4 claims went unchecked though the telemetry MCP was available — re-run those?

Offer **only `STALE` claims** for removal, 10 per round, same check-to-drop batching. One decision covers **all** of a claim's `occurrences` — never present the same fact twice, and never apply to one occurrence while leaving another. This holds even when the occurrences need *different* actions: correcting the body figure while removing a sentence elsewhere is still one approval that spells out what happens to each occurrence, never one approval per occurrence. Splitting it lets the user accept half and leave the file contradicting itself.

For a claim whose text is only *partly* wrong — a drifted count, a moved line number, a renamed file — offer **correct** alongside **remove**, and default to correct. Deleting a whole sentence because one number inside it aged throws away a still-valid pointer, and it is exactly these claims whose text is interleaved with verified content, making removal the most destructive option available.

Then, before writing anything, show the actual diffs for every checked claim and confirm once. **If the caller already authorised the changes in the invocation** ("archive anything stale, don't ask me"), that *is* the confirmation — still print the diffs, since they are the only record of what you changed, but do not stop for a second approval. Asking again after being told not to is how a pre-authorised run ends having done nothing. These are surgical edits inside files that run to thousands of words: removing a sentence can orphan a "see above", break a list, or strip the only context a neighbouring claim depended on. A checkbox cannot show that; a diff can. If a proposed removal would take verified content with it, say so and offer a narrower correction instead of the deletion.

## Step 4b — Usefulness pass

Truth and usefulness are independent: a memory can be perfectly accurate and still be pure context tax. **Read `references/usefulness-pass.md` before this pass** — it holds the per-archetype offer for `SNAPSHOT` and `JOURNAL`, and the one condition on archiving a file whole. Then present the `JOURNAL` and `SNAPSHOT` files, 10 per round, check-to-act.

Open this pass with the corpus cost as a literal measured line, in this exact shape and even when the corpus is tiny:

> Corpus: 125 memories, 41,800 words, ~60K tokens loaded every session.

A file count is **not** a size — words and an approximate token count are both required, and "2 memory files" answers a different question. Measure it; do not estimate from the file count alone. Every other number here is about one file; this is the only one that says what the whole corpus charges each session, and it is the reason the pass exists. Never act on a `LIVING` file here — open work is the one thing worth its context.

Leave `RULE` files to Step 3; usefulness of a preference is the user's call, not an archetype's.

## Step 5 — Apply

**Snapshot before every write, without exception** — not just removals; a `lastReviewed` stamp counts too.

**First, if `MEMORY.md` exists, snapshot it** into the archive before the loop below, with step 1's command (it suffixes `.<n>` rather than overwriting, so a second same-day audit cannot destroy the true baseline). Do it even if you are not sure yet that you will edit it: the loop is per-memory-file, so it never covers the index, and that gap is the one snapshot runs actually miss. **Check it exists** — a project with memory files and no index is valid and step 1 admits it, so an unconditional snapshot aborts the apply phase on a missing source, after approval and before any real snapshot. With no index, say so and skip both this snapshot and step 4's sync; never create one, since this skill audits memories rather than authoring them.

Then, for every approved change, in this order:

1. **Snapshot** the current file to `$ARCHIVE_ROOT/<project-dir>/<filename>` before touching it, **with this command and not `Write`**:

    ```bash
    python3 - '<source file>' '<archive path>' <<'PY'
    import os, shutil, sys
    src, dst = sys.argv[1], sys.argv[2]
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    for n in range(100):
        cand = dst if n == 0 else "%s.%d" % (dst, n)
        try:
            fd = os.open(cand, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        except FileExistsError:
            continue
        with os.fdopen(fd, "wb") as out, open(src, "rb") as f:
            shutil.copyfileobj(f, out)
        print("SNAPSHOT=" + cand)
        break
    else:
        raise SystemExit("no free archive path for " + dst)
    PY
    ```

    **Substitute both paths literally** (single-quoted, `'\''`-escaped) — never a shell variable: they do not survive between `Bash` calls, and empty arguments fail the archive before any approved mutation.

    `O_EXCL` is why this is a command and not a `Write`: it creates or fails, with no window between the two, so a snapshot can never land on an existing one. A `Glob`-then-`Write` cannot: two same-day audits can both see the path free, and the second overwrites the first's original with an already-edited copy. Use the path it prints; **that copy is the snapshot**, the only thing counted as one in the closing count. Without `Bash` this atomicity is unavailable: `Read` the path first, `Write` only if absent, and say in the report that a concurrent audit could have raced it.
2. **Append to `$ARCHIVE_ROOT/manifest.json`**: source path, project, intended action (`file-archived` or `claim-removed`), the removed text, the verdict, the evidence that justified it, and `outcome: "pending"`. **Set `outcome` to `applied` or `refused` once step 3 resolves.** The entry precedes the mutation, so one left at `pending` records an intention, and a manifest read as a change log would report work that never happened.
3. **Apply** — `Edit` to remove or correct an individual claim, covering every one of its `occurrences`. Remove the file from the corpus in exactly three cases, by this procedure and no other: **confirm the step 1 snapshot exists and its contents match the file, then `rm` the file.** That order is the whole safety property, so never `rm` before confirming, and never re-write the file to the base archive name to "make sure" — that is the overwrite step 1 avoided, landing on an earlier run's original. Verify the snapshot step 1 wrote, at the suffixed path if it resolved a collision. Without `Bash` you cannot `rm` at all — follow `references/no-bash-fallback.md`, which stubs the file and reports what remains. The three cases: every claim in it is stale, the user dropped the whole preference, or the user approved **archive whole** in the usefulness pass. For an approved **compress to outcome**, overwrite the body and keep the file, preserving `name` and the whole `metadata:` block exactly — that is what the memory system parses. **Rewrite `description` to match the new body** and show it in the diff: it is the line recall surfaces, so carrying the old one forward leaves the file describing content it no longer holds — the rot the compression was meant to end. Where a compression supersedes queued edits on the same file, fold those corrected facts in so nothing regresses.
4. **Sync `MEMORY.md`** (already snapshotted above) — remove the pointer line for any archived file, and **correct the hook line for any file whose claim you changed**, whenever that hook was among the claim's `occurrences`. Archiving is not the only edit that dates the index: correcting a figure in the body while its hook still asserts the old one leaves the index contradicting the file it points at, and the hook is what recall surfaces first. A pointer to a missing file is worse still than the stale memory was.
5. **Re-scan each edited file** for the fact you just removed — whole file, frontmatter included. A surviving copy means the file now contradicts itself, which is worse than the original staleness. Fix it in the same pass, or report it explicitly as unresolved; never leave it silent.

Leave dangling `[[wiki-links]]` alone — an unmatched link is valid, marking something worth writing later. Report them; do not repair them.

**Count what happened, not what you attempted.** Check the result of every write, and **never skip one because you expect it to be refused** — a predicted refusal is not a result, and an environment that blocked the last write may allow this one. Attempt it, then report what actually happened. One refusal does not mean the next was refused too — a later `Write` can succeed after an `Edit` was blocked, and treating the first denial as final reports the corpus untouched when it is not. List exactly which writes landed and which were refused. Reporting `Files touched: 0` after a write succeeded is worse than the staleness you set out to fix: the user will trust the corpus is unchanged and never look again.

Finally, **verify the archive is a complete restore source**: every file this run modified or removed must have a snapshot. **Count step 1's memory-file copies and nothing else.** `manifest.json` is not a snapshot — counting it lets a run that changed two files report "2 snapshots" and look 1:1 covered while one has no restore point, exactly the failure this check exists to catch. Print both numbers on one line — `Corpus files changed: 3 / Snapshots written: 3` — never as narrative prose, and name the first one *corpus* so it is unambiguous whether archive writes count. **When they differ, give the reason on the same line** — `Corpus files changed: 0 / Snapshots written: 2 (both source edits refused)`. A mismatch is not automatically a fault — snapshotting then failing to edit leaves exactly this shape — but say so loudly: a partial archive invites a restore that silently leaves edits in place.

Close with counts: verified, archived, claims removed, claims corrected, files compressed, the two tool buckets kept apart (absent vs unchecked), the archive path, and the one-line restore command. State plainly anything you could not complete — a dropped finding is worse than one never made, because the summary implies it was handled.

## Response Style

Narration compounds in a workflow this long. Present the picker, batches, diffs and counts directly — skip "Now I will…", "Let me…", and restating a step before doing it. While subagents run, say nothing until something is actionable or a report contradicts itself.

## Guardrails

- Never write outside `$MEM_ROOT` and `$ARCHIVE_ROOT`, and never write *through* a symlink: resolve each target to its real path first, and if that lands outside either root, skip the file and report the skip. Resolving the roots does not resolve a symlinked file inside them.
- Never `rm` a memory file until its archive snapshot exists and its contents match — the snapshot is what makes the removal reversible, so no snapshot means no removal.
- Never mark a claim stale on absent evidence.
- Never truth-check a `feedback` or `user` memory.
- Never edit `CLAUDE.md`, `.claude/rules/`, or any repo file — this skill audits saved memories only.
- Never act on a `STALE` claim whose `proposed_edit` you could not match verbatim in the file.
- Never remove one occurrence of a fact while leaving another standing.
- Never report an unattempted check as a missing tool.
- If zero projects have memories, say so and stop.
