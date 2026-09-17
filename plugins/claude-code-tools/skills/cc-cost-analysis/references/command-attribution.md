# Attributing Cost to Specific Commands (Waste vs Real Work)

Aggregate telemetry (calls/cost by model, by user, by session) tells you *how much* was spent, not *which commands* were wasteful. To attribute cost to a specific command pattern — polling, re-authentication, a bare `sleep`, a no-op retry — and separate genuine waste from work that happened to be bundled alongside it, you need the actual command text, not just aggregated metrics. Most metrics backends (Honeycomb-style event stores, dashboards) don't carry full tool-call parameters; you may need a separate raw session/transcript log or a richer event export that does.

## Core rule: count actual commands, not turns

A turn (one assistant API request) bills cache-read for its **entire** context regardless of what any individual command in it does. So "turns containing pattern X × per-turn cost" massively overcounts, because pattern X is usually **bundled with real work the turn had to do anyway**. Classify every candidate-waste pattern into three buckets:

1. **Bundled with real work** — e.g. an auth-refresh-then-real-command chain, a `sleep` immediately followed by reading a log, a status echo followed by a real check. Cache-read is billed for the real command; it runs regardless. **Marginal waste ≈ 0** (only the few prefix tokens the wasteful part added). *One exception:* a **long** sleep or wait (longer than your cache's TTL) bundled with real work is not zero-cost — the delay can make the *next* request miss cache and re-pay a write instead of a read; attribute that write-premium delta to the wait (see the cache-TTL caveat in `cost-model.md`).
2. **Standalone / repeated** — **every** part of the turn exists *only* to poll, wait, or no-op: a bare status re-check re-run with nothing else, a `sleep` followed only by an echo, a no-op retry. **This is the real waste** — the whole context re-read buys nothing. If the turn *also* carries a real-work action anywhere in it (even a second, parallel tool call), it's bucket 1, not waste — its cost rides on that work.
3. **Efficient patterns that look wasteful at a glance** — an in-shell polling loop that blocks until a condition is met is *one* turn; a tool or CLI's own built-in "watch until done" command is a blocking waiter. These are the *correct* fix, not waste — never count them as such.

Waste = the marginal cost of turns that exist *only* to poll/wait, minus a legitimate baseline (e.g. one first status check per task, one auth per session). Distinguish a first check (legitimate) from a repeated status re-check of the same thing (waste), and a status re-check from reading a different facet of the same thing (legitimate investigation, not a repeat).

## Extraction gotchas (silently corrupt classification)

Command text usually lives inside a structured tool-call block (e.g. a `tool_use` block with an `input.command` field), not as a flat string. The robust way to read it is to parse that structure — treat each tool call as its own JSON object and read its command field directly. Regex or substring extraction over a raw serialized-message string is only a rough peek and has failure modes that quietly break classification:

1. **Quote truncation.** A naive `"command":"(.*?)"` pattern stops at the first escaped quote inside the value, so a command containing a double-quoted argument gets truncated and misread as something else entirely.
2. **Window bleed.** A fixed-size substring window anchored on a field's start doesn't reliably stop at that field's end — it can spill into the next field or a different tool call entirely, making a standalone command look bundled (or vice versa) purely because of what happens to sit inside the window.
3. **Multiple calls per turn.** One turn can hold several tool calls; a "find the first match" approach silently drops every call after the first.

So: to *count* occurrences of a pattern, a simple text search is fine. To *classify* each command (bundled vs standalone vs efficient), parse the structured call data and read each one's command field individually — don't rely on a raw-string window. And attribute **cost per turn, not per command**: usage/cache-read tokens are billed once for the whole turn, so never multiply a turn's cost by the number of commands it contains. A turn is waste only if **every** action in it is waste — a single real-work action anywhere in the turn makes the whole turn bundled (bucket 1). When tallying waste across multiple patterns, **dedupe by turn**: a turn matching two waste patterns at once is one turn's cost, assigned to a single bucket, never summed into both.

## Prove your work (required before quoting any $)

Cost analysis built on aggregates alone has a habit of producing confident-but-wrong figures. Before reporting a number:

1. **Show the atoms.** Dump the raw usage fields (cache-read tokens, input tokens, output tokens) for a handful of turns to confirm the field is real, populated, and you're reading the right one.
2. **Show example command strings** for each bucket *before* labelling anything waste. If you can't show ~10 real examples of the waste, you don't have the number yet.
3. **One reproducible query.** Compute the dollar figure inline (rates in a `CASE`/lookup) so the query emits the number directly and anyone can re-run it — it should be deterministic, or close to it, on re-run.
4. **Cross-check against an independent source, like with like.** Two checks help: (a) compute cost-weighted shares using the ratio weights from `cost-model.md` (input 1×, cache-write 1.25×, cache-read 0.1×, output 5×) — don't confuse this dollar-weighted share with the raw *token* share; cache-read tokens are usually the majority of token *volume* but a much smaller fraction of *cost*, and the two numbers shouldn't be reconciled against each other. (b) For absolute dollars, price your tokens at current rates and compare against your actual billing statement, which is authoritative over any self-reported cost field. One sanity check holds regardless of rates: no single token-type component can exceed the turn's true total cost — if your math says it does, the rate is wrong.
5. **State your assumptions.** The two that move everything: the cache-read multiplier and where you drew the waste-classification boundary. Name them and note how sensitive the final number is to each.

## Pricing: always re-derive from current rates

Absolute price-per-token drifts over time and a remembered rate may be stale, silently skewing every downstream figure. Look up current per-token prices before converting anything to dollars — the *ratios* between token types (cache-read ≈ 0.1× input, cache-write ≈ 1.25× input) are stable even when absolute prices change; the absolute prices are not.
