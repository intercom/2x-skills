---
name: cc-cost-analysis
description: >
  Analyze Claude Code usage costs from OpenTelemetry data — per-user spend,
  expensive sessions, context bloat, and model/token cost breakdowns — with a
  structured framework, ready-to-use query shapes, and cost-model formulas.
  Triggers on "analyze Claude Code costs", "break down the Claude Code bill",
  "find expensive sessions", "identify context bloat".
---

# Claude Code Cost Analysis

A framework and ready-to-use query shapes for analyzing Claude Code usage costs across a team or org.

## Prerequisites: you need Claude Code telemetry

Claude Code can export usage as OpenTelemetry metrics and events (`CLAUDE_CODE_ENABLE_TELEMETRY=1` plus an OTLP endpoint — see the Claude Code monitoring docs). Point that export at an observability backend (Honeycomb, Datadog, an OTLP collector into a warehouse, etc.). This skill analyzes that data.

The example queries in `references/queries.md` are written for **Honeycomb** (environment/dataset names are placeholders — substitute wherever you send telemetry). The **analysis dimensions and cost formulas are backend-agnostic** — the same shapes translate to any store that has per-`api_request` rows with token counts, `cost_usd`, `model`, and `session.id`.

A few attribute names in the examples (`user.email`, `speed`, `skill.name`, `normalized_file_path`) are enrichments that depend on your telemetry pipeline and Claude Code version — verify column names against your own data (`get_dataset_columns` or the equivalent) before relying on them. Numeric fields are sometimes stored as strings; cast with `FLOAT(...)` before aggregating (see the query examples).

## Analysis Dimensions

Each dimension answers a different question. Run whichever are relevant — there is no required order, though broader dimensions provide context for narrower ones.

| Dimension | Question Answered | Query Section |
|-----------|------------------|---------------|
| Model mix | Which models account for what cost? | `references/queries.md` Section 1 |
| Session economics | Where in sessions does cost accumulate? | Section 2 |
| Token types | Cache writes vs reads vs output share? | Section 3 |
| Tool result sizes | Which tools bloat the context? | Section 4 |
| Compaction | Are sessions hitting context limits? | Section 5 |
| Per-user profiles | Who are the heaviest users and why? | Section 6 |
| Instructions & skills | How much do CLAUDE.md/rules/skills cost? | Section 7 |

Apply cost formulas from `references/cost-model.md` when computing dollar estimates from token counts.

## Illustrative Findings

These are shape-of-the-problem findings from one large deployment — useful to calibrate expectations, **not** ground truth for your org. Always verify against fresh queries against your own data.

### Cost distribution

| Dimension | Typical finding |
|-----------|---------|
| Model dominance | The most capable model tends to dominate cost far out of proportion to its share of calls |
| Session length | A minority of long sessions (turns 100+) can account for the majority of that model's cost |
| Token type shares | Cache write ~47%, cache read ~44%, output ~9% of weighted cost |
| Caching savings | Prompt caching typically cuts the bill ~80% vs fully uncached input |
| Instruction overhead | CLAUDE.md, rules, and skills are collectively a small fraction (~1%) of total spend |

### Session turn phases

| Phase | Turns | Driver |
|-------|-------|--------|
| Cache creation | 0-3 | System prompt + instructions written to cache |
| Steady state | 4-50 | Caching working well — lowest per-call cost |
| Context growth | 50-99 | Cache reads climbing as context accumulates |
| Long-session tail | 100+ | Large accumulated context re-read every turn |

### Tool result sizes (typical ranges)

| Category | Avg/call | Examples |
|----------|---------|---------|
| Screenshots | 100-500 KB | browser/screenshot tools |
| Search results | 10-30 KB | search MCP tools |
| Database results | 5-10 KB | SQL / log query tools |
| File reads | 3-7 KB | Read tool (very high volume) |

### Context window behavior

- A small fraction of sessions trigger auto compaction.
- The most expensive sessions rarely compact — they grow to a large context and stay just below the window limit.
- Sessions on smaller context windows compact more often and cost far less per call than sessions on the largest window with equivalent workloads.

## Key Analysis Patterns

### Matched session comparison

The most compelling way to demonstrate context-size impact on cost is finding two sessions with similar API-call counts but different context behaviors — one with high average cache_read (bloated, likely on the largest window) and one low (lean, compacting or on a smaller window). The per-session query (Section 6a adapted to break down by `session.id`) surfaces these pairs.

### User segmentation by context usage

Classify users by what % of their calls exceed a large cache_read threshold (Section 6a, `calls_over_200k` field):
- **0% over threshold** — never needs the largest context, would work on a smaller window
- **1-10%** — rarely needs it, benefits most from proactive compaction
- **60%+** — genuinely needs the largest context (investigate what tools drive it via Section 6b)

## Important Caveats

**Quality vs cost tradeoff:** Cost optimizations (model downshift, aggressive compaction, smaller context windows) may degrade output quality. Measure quality objectively before changing configuration. Cost savings mean nothing if the tool becomes less useful.

**Caching IS helping:** Prompt caching reduces the bill substantially vs uncached input. The remaining cost is driven by the volume of cached tokens, not by caching being inefficient.

**Instructions are a small share:** CLAUDE.md files, rules, and skills are a small fraction of total spend. The real cost drivers are session length and context accumulation from tool results.

## Generating Reports

Capture findings in markdown reports. See `references/report-templates.md` for standard structures. Name files `{report-type}-{YYYY-MM-DD}.md`.

## Reference Files

- **`references/queries.md`** — Example Honeycomb queries organized by analysis dimension
- **`references/cost-model.md`** — Token pricing ratios, per-call/per-session cost formulas, caching economics
- **`references/report-templates.md`** — Standard report structures for each analysis type
- **`references/column-gotchas.md`** — Data-quality gotchas specific to cost analysis

## Scripts

- **`scripts/compute_percentiles.py`** — Compute p10/p25/p50/p75/p90/p99 from per-user query result sets
