# Subagent brief

Hand this to every project subagent verbatim, alongside its memory directory and resolved repo path. The return shape is defined in SKILL.md Step 2.

- **Route by `type` frontmatter.** `feedback`/`user` → `preferences` (no truth-checking; only report whether the *mechanism* they cite still exists, e.g. a script, hook or flag that is now gone). `project`/`reference`/untyped → `claims`.
- **Verify free things first**, at no MCP cost: cited file paths and `file:line` refs via Read/Glob; flag and env-var names via Grep; branch state via `git`.
- **PR and issue refs** — `gh pr view <n> --json state,title,mergedAt`. The field is `mergedAt`, **not `merged`**: `gh` rejects an unknown field and fails the whole command, so one wrong name leaves every PR claim unverified rather than partly answered. A bare `#123` may be an issue, and `gh pr view` errors on an issue number — `gh issue view <n> --json state,title` resolves both (GitHub treats PRs as issues), so reach for it when `pr view` refuses.
- **Scope every repo lookup to the project's own repo.** Pass `-R <owner>/<repo>` to `gh` and `-C <repo-path>` to `git`, derived from the resolved repo — never rely on the invoking session's cwd. PR numbers collide across repositories, so an unscoped `gh pr view 3557` can confirm a claim against an entirely different project and report a false `CONFIRMED`. If you cannot determine the owner/repo for a memory, the claim is `NOT-CHECKABLE`, not confirmed.
- **Use MCPs when connected** — an issue-tracker MCP for ticket state, a warehouse or observability MCP for metric claims. This skill declares none of them, so whichever ones the session happens to have are best-effort: use them when present, and name them in the verdict when absent.
- **Require positive evidence for `STALE`.** A reverted PR, a deleted file, a removed flag, a closed-as-wontfix ticket, a superseding memory. "I could not find it" is `NOT-CHECKABLE`, not stale.
- **`NEEDS-<tool>` whenever *some* tool would settle it, and name that tool** in the verdict itself (`NEEDS-jira`, `NEEDS-datadog` — whatever the session would actually need). Metric claims need a warehouse or observability tool; ticket state needs the issue tracker; PR and branch state needs `gh`/`git`. Reserve `NOT-CHECKABLE` for what no tool could settle — a subjective judgment, a decision made in conversation, external state that is simply gone. Defaulting to `NOT-CHECKABLE` reads as "nothing can be done", so the user is never told which MCP to connect and the claim rots forever.
**Worked verdicts.** Match the claim to the closest row before reaching for a verdict of your own:

| Claim | Verdict | Why |
|---|---|---|
| "the checkout endpoint serves ~40 req/s at p99 180ms" | `NEEDS-<telemetry>` | Telemetry would settle it. Not `NOT-CHECKABLE`: a named tool exists |
| "ABC-1234 tracks the fix" | `NEEDS-<tracker>` | Ticket state is an issue-tracker lookup |
| "PR #3557 is still open" | `NEEDS-gh` if `gh` is absent, else check it | Scope with `-R owner/repo` |
| "the parser is at `lib/parse.rb`" | `CONFIRMED`/`STALE` via Read/Glob | Needs no MCP at all — check it |
| "we agreed Postgres was the wrong call" | `NOT-CHECKABLE` | No tool can settle a past conversation |
| "the repo has 120 migrations" with the repo absent | `NOT-CHECKABLE` | Nothing readable to count |

A missing repo makes *that repo's* claims uncheckable. It does not make a telemetry or ticket claim uncheckable — those are settled by a different tool, so they stay `NEEDS-<tool>`.

**You do not need to know which tracker to know a tracker would settle it.** An unfamiliar key like `ABC-1234` is still `NEEDS-<tracker>` (name your best guess at the system) — never `NOT-CHECKABLE`. The user knows which system they use; your job is to say a lookup would answer it. Applying `NEEDS-<tool>` to the cost claim and `NOT-CHECKABLE` to the ticket claim in the same report is the specific inconsistency to avoid: both are external state a tool can read.

- **Choose between the two tool verdicts with these questions, in order:**
  1. Is the tool I need listed among the tools I was given? **No → `NEEDS-<tool>`.** Stop. This is the usual case for MCPs, and it is a decision, not a hedge.
  2. It is listed — did I call it? **No → `NOT-ATTEMPTED`.** Yes → report what it returned.

  Naming the tool in your evidence text does not count; it has to be in the verdict. `NOT-ATTEMPTED` tells the orchestrator "it was available and I skipped it", so it offers a re-run that cannot possibly work, while `NEEDS-<tool>` tells the user which MCP to connect. Getting these backwards wastes the single action that would fix the claim. Never ask whether to attempt a tool you do not have — that hands back a question you can answer yourself. `NEEDS-<tool>` also covers unauthenticated and permission-denied; quote the error where there is one.
- **List every occurrence, including `description:` and the `MEMORY.md` line.** Before returning a `STALE` claim, grep the whole file for every other place the same fact is asserted, and put each exact string in `occurrences`. Two hide reliably: the frontmatter `description:`, and the file's one-line hook in `MEMORY.md`. Both are surfaced at recall time, so a stale one misleads every future session even after the body is fixed — scan them by name rather than trusting a body-only pass.
- **Quote occurrences in full — never elide.** No `…`, no `...`, no "[snip]". An abbreviated quote cannot be matched verbatim against the file, so it fails the validation below and cannot be reviewed by the user. A count or line-ref usually appears more than once; removing one instance and leaving the others makes the file self-contradictory, which is worse than leaving it uniformly stale.
- **Classify the file's archetype**: `LIVING` (open work, forward-looking), `JOURNAL` (history of finished work), `SNAPSHOT` (counts/metrics true only at capture time), `NOTE` (anything else).
- Never write, edit or delete anything. Subagents report only.
