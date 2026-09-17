# Usefulness pass — the per-archetype offers

Read this before running Step 4b. Correcting a stale number inside a `SNAPSHOT` only resets a timer — the same line will be wrong again next month. Fixing counts is the most expensive, most collateral-prone editing this skill does, and on a `SNAPSHOT` it buys nothing durable. So each file gets one of these offers instead:

- **`SNAPSHOT`** → *replace the captured numbers with the query or command that regenerates them.* A memory holding "412 specs across 23 modules" should hold the `glob` that counts them instead. **Write the command out in full**, ready to run — `ls -d spec/*/*_spec.rb | wc -l`, the actual SQL, the actual `gh` invocation. Never a placeholder, a "this is stale" marker, or a bare archive-or-leave choice: a placeholder drops the information without replacing its value, which is worse than the stale number. If the repo is absent, still write your best command and label it unverified.
- **`JOURNAL`** → *compress to outcome.* A 1,700-word PR-by-PR history of finished work is worth two sentences: what shipped, and the one non-obvious thing worth remembering.
- Either → **archive whole**, but *only* after confirming the file holds **no forward-looking item** — no open decision, no pending step, nothing still blocked. Check before offering it, not at the diff stage. A file can be 95% finished history and still be the only record of one live question, and archiving it whole buries that where nobody will look for it. If you find one, offer *compress to the open item* instead.

An approved compression is applied in Step 5 item 3, which keeps the file and rewrites `description` to match the new body.
