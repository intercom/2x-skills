# Report Templates

Standard markdown report structures for each analysis type. Generate as `.md` files in the working directory.

## Executive Summary Template

```markdown
# Claude Code Cost Analysis: Executive Summary

**Date:** YYYY-MM-DD
**Period:** Last 14 days
**Total spend:** $X
**Active users:** N across M sessions

## Where the Money Goes

[ASCII chart showing model split, token type split, session length split, context source split]

## Key Findings

1. [Model dominance finding]
2. [Session length finding]
3. [Tool results finding]
4. [Compaction finding]
5. [Instructions finding]

## Optimization Opportunities, Ranked

| # | Lever | Estimated Savings | % of Bill | Difficulty |
|---|-------|------------------|----------|------------|
| 1 | ... | ... | ... | ... |

## Top Specific Actions

| # | Action | Where | Annual Impact |
|---|--------|-------|--------------|

## Quick Reference Numbers

[Table of key metrics: calls, sessions, avg cost, context sizes, etc.]
```

## Cost Structure Report Template

```markdown
# Claude Code Cost Structure Analysis

## How Caching Works (and why it's helping)
[Cache write vs read mechanics, savings estimate]

## Session Economics: Turn-by-Turn Cost Curve
[Phase 1-4 breakdown table from event.sequence data]

## The $XK Bill, Decomposed
[By session length, by model, by token type tables]

## Context Size Distribution
[P50/P90/P99 by model]

## Ranked Optimization Levers
[Detailed recommendations with savings estimates]
```

## Tool Result Size Report Template

```markdown
# Tool Result Size Analysis

## The Full Context Injection Landscape
[All tools ranked by total bytes: Read, MCP, Bash, etc.]
[Estimated context cost by tool type]

## MCP Servers Ranked
[Server-level table with bytes, calls, avg, P90, P99, users]

## MCP Tools Ranked
[Tool-level table: top 25 endpoints]

## The Screenshot Problem
[Combined screenshot stats if applicable]

## High-Volume Workhorses
[Tools with moderate per-call size but high frequency]

## P99 Outliers
[Tools with occasional massive results]

## Recommendations by category
```

## Compaction Analysis Report Template

```markdown
# Context Window & Compaction Analysis

## Compaction Overview
[auto vs manual counts, session counts, user counts]

## Most-Compacting Sessions vs Their Cost
[Table cross-referencing compaction count with session cost]
[Two patterns: "context bombs" vs "marathon runners"]

## The Counter-Intuitive Finding
[Compacting sessions are NOT the most expensive]
[Most expensive sessions rarely compact -- they sit below the limit]

## Case Study: Matched Session Comparison
[Two sessions with similar calls but different context sizes]

## Per-User Compaction Patterns
[Top compacting users]

## What This Means for Cost Optimization
[Proactive compaction proposal with savings estimate]
```

## Naming Convention

Save reports as: `{report-type}-{YYYY-MM-DD}.md`

Examples:
- `cost-analysis-executive-summary-2026-04-07.md`
- `cost-structure-analysis-2026-04-07.md`
- `tool-result-size-analysis-2026-04-07.md`
- `context-compaction-analysis-2026-04-07.md`
- `instruction-cost-analysis-2026-04-07.md`
```
