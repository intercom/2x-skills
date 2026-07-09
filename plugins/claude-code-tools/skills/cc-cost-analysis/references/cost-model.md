# Cost Model Reference

Exact per-token prices change over time and by model. Use the **price ratios** below to compute cost shares from token-count data — the ratios between token types are stable even when absolute prices shift. Check current per-token prices in the Claude pricing docs before converting to dollars.

## Token Pricing Ratios (per model)

For a given model, the four token types price roughly in this proportion:

| Token Type | Price Ratio | Relative to Input |
|------------|-------------|-------------------|
| Input (uncached) | 1x | baseline |
| Cache write | 1.25x | 25% premium |
| Cache read | 0.10x | **90% discount** |
| Output | 5x | 5x input |

The absolute price scales by model tier: a mid-tier model is typically several times cheaper per token than the top-tier model, and a small/fast model an order of magnitude cheaper again. The *ratios above hold within each model.*

## Computing Cost Shares from Token Volumes

Given per-model token volumes (from query 1a), compute the **weighted cost contribution** of each token type:

```
weighted_cache_read   = total_cache_read_tokens     × 0.10
weighted_cache_write  = total_cache_creation_tokens × 1.25
weighted_input        = total_input_tokens          × 1.00
weighted_output       = total_output_tokens         × 5.00

total_weighted = sum of above

cache_read_share  = weighted_cache_read  / total_weighted
cache_write_share = weighted_cache_write / total_weighted
output_share      = weighted_output      / total_weighted
```

Apply these shares to the actual total cost to get dollar amounts per token type.

### Illustrative share breakdown

From one large deployment — verify against your own data:

| Token Type | Share of weighted cost |
|------------|-------|
| Cache write | ~47% |
| Cache read | ~44% |
| Output | ~9% |
| Input (uncached) | <1% |

## Caching Savings Estimate

To estimate what the bill WOULD be without caching:

```
without_caching = total_cache_read_tokens × 1.0 (full input price)
with_caching    = total_cache_read_tokens × 0.1 (cache read price)
savings         = without_caching - with_caching

# Cache writes cost 25% more than uncached input:
write_premium = total_cache_creation_tokens × 0.25

net_savings = savings - write_premium
```

Because cache reads typically dominate token volume by an order of magnitude over cache writes, net savings tend to land around **80% of what the bill would be without caching**.

## Per-Call and Per-Session Cost Formulas

Substitute your model's current `$cache_write_price` / `$cache_read_price` (per token) into these. The example dollar figures use a top-tier-model price point purely to illustrate the shape — recompute with live prices.

### Instructions (CLAUDE.md, rules) — loaded at session start

```
per_session_cost = tokens × ($cache_write_price + (avg_turns - 1) × $cache_read_price)
```

### Skills — loaded mid-session

```
per_invocation_cost = tokens × ($cache_write_price + remaining_turns × $cache_read_price)
```

### Tool results — injected at point of call

```
context_cost = (result_bytes / 4) × ($cache_write_price + remaining_turns × $cache_read_price)
```

(The `/ 4` approximates ~4 bytes per token for markdown/text.)

## Key Ratios for Quick Estimates

| Metric | Top-tier | Mid-tier | Small/fast |
|--------|------|--------|-------|
| Relative $/call | ~2x mid | 1x | ~1/4 mid |
| Tokens per byte (markdown) | ~0.25 | ~0.25 | ~0.25 |

The single most useful quick estimate: a large accumulated context re-read every turn is what makes long sessions expensive — cost per call climbs with cache-read volume, not with the work being done that turn.
