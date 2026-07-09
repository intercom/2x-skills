# Cost Analysis Honeycomb Queries

Example query shapes for analyzing Claude Code OpenTelemetry data in Honeycomb. The `environment_slug` / `dataset_slug` values below (`claude-code` / `claude-code-telemetry`) are **placeholders** — substitute the environment and dataset where you export Claude Code telemetry.

A few field names depend on your pipeline and Claude Code version — verify against your own schema first:
- `cost_usd_float` — a numeric cost column. Claude Code's raw `cost_usd` is sometimes stored as a string; this assumes a pre-cast float column. If yours is a string, declare a calculated field `FLOAT($cost_usd)` and use that instead.
- `user.email`, `speed`, `skill.name`, `normalized_file_path` — enrichment attributes that may or may not be present in your export.

Default time range: `14d`. Adjust as needed.

---

## Section 1: Model Cost Breakdown

### 1a. Cost, calls, and tokens by model

```json
{
  "environment_slug": "claude-code",
  "dataset_slug": "claude-code-telemetry",
  "query_spec": {
    "time_range": "14d",
    "calculated_fields": [
      {"name": "input_f", "expression": "FLOAT($input_tokens)"},
      {"name": "output_f", "expression": "FLOAT($output_tokens)"},
      {"name": "cache_r_f", "expression": "FLOAT($cache_read_tokens)"},
      {"name": "cache_c_f", "expression": "FLOAT($cache_creation_tokens)"}
    ],
    "calculations": [
      {"op": "COUNT", "name": "api_calls"},
      {"op": "SUM", "column": "cost_usd_float", "name": "total_cost"},
      {"op": "SUM", "column": "input_f", "name": "total_input"},
      {"op": "SUM", "column": "output_f", "name": "total_output"},
      {"op": "SUM", "column": "cache_r_f", "name": "total_cache_read"},
      {"op": "SUM", "column": "cache_c_f", "name": "total_cache_creation"},
      {"op": "AVG", "column": "cost_usd_float", "name": "avg_cost_per_call"}
    ],
    "breakdowns": ["model"],
    "filters": [
      {"column": "event.name", "op": "=", "value": "api_request"}
    ],
    "orders": [{"op": "SUM", "column": "cost_usd_float", "order": "descending"}],
    "limit": 20
  }
}
```

### 1b. Cost by speed mode (normal vs fast)

```json
{
  "environment_slug": "claude-code",
  "dataset_slug": "claude-code-telemetry",
  "query_spec": {
    "time_range": "14d",
    "calculations": [
      {"op": "COUNT", "name": "api_calls"},
      {"op": "SUM", "column": "cost_usd_float", "name": "total_cost"},
      {"op": "COUNT_DISTINCT", "column": "session.id", "name": "sessions"},
      {"op": "AVG", "column": "cost_usd_float", "name": "avg_cost"}
    ],
    "breakdowns": ["speed"],
    "filters": [
      {"column": "event.name", "op": "=", "value": "api_request"}
    ],
    "orders": [{"op": "SUM", "column": "cost_usd_float", "order": "descending"}]
  }
}
```

---

## Section 2: Session Turn Economics

### 2a. Cost curve by event.sequence (Opus only)

Shows how cost evolves as sessions progress through turns. Filter to the dominant model.

```json
{
  "environment_slug": "claude-code",
  "dataset_slug": "claude-code-telemetry",
  "query_spec": {
    "time_range": "14d",
    "calculated_fields": [
      {"name": "cache_r_f", "expression": "FLOAT($cache_read_tokens)"},
      {"name": "cache_c_f", "expression": "FLOAT($cache_creation_tokens)"},
      {"name": "output_f", "expression": "FLOAT($output_tokens)"}
    ],
    "calculations": [
      {"op": "COUNT", "name": "api_calls"},
      {"op": "SUM", "column": "cost_usd_float", "name": "total_cost"},
      {"op": "COUNT_DISTINCT", "column": "session.id", "name": "sessions"},
      {"op": "AVG", "column": "cache_r_f", "name": "avg_cache_read"},
      {"op": "AVG", "column": "cache_c_f", "name": "avg_cache_write"},
      {"op": "AVG", "column": "output_f", "name": "avg_output"},
      {"op": "AVG", "column": "cost_usd_float", "name": "avg_cost"}
    ],
    "breakdowns": ["event.sequence"],
    "filters": [
      {"column": "event.name", "op": "=", "value": "api_request"},
      {"column": "event.sequence", "op": "exists"},
      {"column": "model", "op": "=", "value": "claude-opus-4-6"}
    ],
    "orders": [{"column": "event.sequence", "order": "ascending"}],
    "limit": 100
  },
  "results_limit": 100
}
```

### 2b. Cost from turns 100+ by model

Quantifies how much of the bill comes from long-running sessions.

```json
{
  "environment_slug": "claude-code",
  "dataset_slug": "claude-code-telemetry",
  "query_spec": {
    "time_range": "14d",
    "calculations": [
      {"op": "COUNT", "name": "api_calls"},
      {"op": "SUM", "column": "cost_usd_float", "name": "total_cost"},
      {"op": "COUNT_DISTINCT", "column": "session.id", "name": "sessions"}
    ],
    "breakdowns": ["model"],
    "filters": [
      {"column": "event.name", "op": "=", "value": "api_request"},
      {"column": "event.sequence", "op": ">=", "value": 100}
    ],
    "orders": [{"op": "SUM", "column": "cost_usd_float", "order": "descending"}]
  }
}
```

---

## Section 3: Token Type Analysis

### 3a. Context size distribution by model

```json
{
  "environment_slug": "claude-code",
  "dataset_slug": "claude-code-telemetry",
  "query_spec": {
    "time_range": "14d",
    "calculated_fields": [
      {"name": "cache_r_f", "expression": "FLOAT($cache_read_tokens)"},
      {"name": "cache_c_f", "expression": "FLOAT($cache_creation_tokens)"},
      {"name": "all_input_f", "expression": "FLOAT($cache_read_tokens) + FLOAT($cache_creation_tokens) + FLOAT($input_tokens)"}
    ],
    "calculations": [
      {"op": "COUNT", "name": "api_calls"},
      {"op": "AVG", "column": "all_input_f", "name": "avg_total_context"},
      {"op": "P50", "column": "all_input_f", "name": "p50_context"},
      {"op": "P90", "column": "all_input_f", "name": "p90_context"},
      {"op": "P99", "column": "all_input_f", "name": "p99_context"},
      {"op": "AVG", "column": "cost_usd_float", "name": "avg_cost"}
    ],
    "breakdowns": ["model"],
    "filters": [
      {"column": "event.name", "op": "=", "value": "api_request"},
      {"column": "model", "op": "in", "value": ["claude-opus-4-6", "claude-sonnet-4-6", "claude-haiku-4-5-20251001"]}
    ],
    "orders": [{"op": "COUNT", "order": "descending"}]
  }
}
```

### 3b. Per-call cost percentiles

```json
{
  "environment_slug": "claude-code",
  "dataset_slug": "claude-code-telemetry",
  "query_spec": {
    "time_range": "14d",
    "calculations": [
      {"op": "COUNT", "name": "api_calls"},
      {"op": "P50", "column": "cost_usd_float", "name": "p50_cost"},
      {"op": "P90", "column": "cost_usd_float", "name": "p90_cost"},
      {"op": "P99", "column": "cost_usd_float", "name": "p99_cost"},
      {"op": "AVG", "column": "cost_usd_float", "name": "avg_cost"},
      {"op": "SUM", "column": "cost_usd_float", "name": "total_cost"}
    ],
    "filters": [
      {"column": "event.name", "op": "=", "value": "api_request"}
    ]
  }
}
```

---

## Section 4: Tool Result Size Analysis

### 4a. All tools by total bytes injected

```json
{
  "environment_slug": "claude-code",
  "dataset_slug": "claude-code-telemetry",
  "query_spec": {
    "time_range": "14d",
    "calculated_fields": [
      {"name": "result_size_f", "expression": "FLOAT($tool_result_size_bytes)"}
    ],
    "calculations": [
      {"op": "SUM", "column": "result_size_f", "name": "total_bytes"},
      {"op": "AVG", "column": "result_size_f", "name": "avg_bytes"},
      {"op": "P50", "column": "result_size_f", "name": "p50_bytes"},
      {"op": "P90", "column": "result_size_f", "name": "p90_bytes"},
      {"op": "P99", "column": "result_size_f", "name": "p99_bytes"},
      {"op": "COUNT", "name": "calls"},
      {"op": "COUNT_DISTINCT", "column": "user.email", "name": "users"}
    ],
    "breakdowns": ["tool_name"],
    "filters": [
      {"column": "event.name", "op": "=", "value": "tool_result"},
      {"column": "tool_result_size_bytes", "op": "exists"}
    ],
    "orders": [{"op": "SUM", "column": "result_size_f", "order": "descending"}],
    "limit": 30
  }
}
```

### 4b. MCP servers by total bytes

```json
{
  "environment_slug": "claude-code",
  "dataset_slug": "claude-code-telemetry",
  "query_spec": {
    "time_range": "14d",
    "calculated_fields": [
      {"name": "result_size_f", "expression": "FLOAT($tool_result_size_bytes)"}
    ],
    "calculations": [
      {"op": "SUM", "column": "result_size_f", "name": "total_bytes"},
      {"op": "AVG", "column": "result_size_f", "name": "avg_bytes"},
      {"op": "P90", "column": "result_size_f", "name": "p90_bytes"},
      {"op": "P99", "column": "result_size_f", "name": "p99_bytes"},
      {"op": "COUNT", "name": "calls"},
      {"op": "COUNT_DISTINCT", "column": "user.email", "name": "users"}
    ],
    "breakdowns": ["tool_parameters.mcp_server_name"],
    "filters": [
      {"column": "event.name", "op": "=", "value": "tool_result"},
      {"column": "tool_parameters.mcp_server_name", "op": "exists"},
      {"column": "tool_result_size_bytes", "op": "exists"}
    ],
    "orders": [{"op": "SUM", "column": "result_size_f", "order": "descending"}],
    "limit": 30
  }
}
```

### 4c. MCP server + tool combos by total bytes

```json
{
  "environment_slug": "claude-code",
  "dataset_slug": "claude-code-telemetry",
  "query_spec": {
    "time_range": "14d",
    "calculated_fields": [
      {"name": "result_size_f", "expression": "FLOAT($tool_result_size_bytes)"}
    ],
    "calculations": [
      {"op": "SUM", "column": "result_size_f", "name": "total_bytes"},
      {"op": "AVG", "column": "result_size_f", "name": "avg_bytes"},
      {"op": "P90", "column": "result_size_f", "name": "p90_bytes"},
      {"op": "P99", "column": "result_size_f", "name": "p99_bytes"},
      {"op": "COUNT", "name": "calls"},
      {"op": "COUNT_DISTINCT", "column": "user.email", "name": "users"}
    ],
    "breakdowns": ["tool_parameters.mcp_server_name", "tool_parameters.mcp_tool_name"],
    "filters": [
      {"column": "event.name", "op": "=", "value": "tool_result"},
      {"column": "tool_parameters.mcp_server_name", "op": "exists"},
      {"column": "tool_result_size_bytes", "op": "exists"}
    ],
    "orders": [{"op": "SUM", "column": "result_size_f", "order": "descending"}],
    "limit": 40
  },
  "results_limit": 100
}
```

---

## Section 5: Compaction Analysis

### 5a. Compaction events by trigger type

```json
{
  "environment_slug": "claude-code",
  "dataset_slug": "claude-code-telemetry",
  "query_spec": {
    "time_range": "14d",
    "calculations": [
      {"op": "COUNT", "name": "compactions"},
      {"op": "COUNT_DISTINCT", "column": "session.id", "name": "sessions"},
      {"op": "COUNT_DISTINCT", "column": "user.email", "name": "users"}
    ],
    "breakdowns": ["trigger"],
    "filters": [
      {"column": "event.name", "op": "=", "value": "hook.PreCompact"}
    ],
    "orders": [{"op": "COUNT", "order": "descending"}]
  }
}
```

### 5b. Top compacting sessions

```json
{
  "environment_slug": "claude-code",
  "dataset_slug": "claude-code-telemetry",
  "query_spec": {
    "time_range": "14d",
    "calculations": [
      {"op": "COUNT", "name": "compactions"}
    ],
    "breakdowns": ["session.id"],
    "filters": [
      {"column": "event.name", "op": "=", "value": "hook.PreCompact"},
      {"column": "trigger", "op": "=", "value": "auto"}
    ],
    "orders": [{"op": "COUNT", "order": "descending"}],
    "limit": 50
  },
  "results_limit": 50
}
```

### 5c. Session-level cache read + compaction overlay

To visualize the sawtooth compaction pattern for a specific session, run two queries and view side-by-side in Honeycomb:

**Cache reads (use 600s or 1800s granularity):**
```json
{
  "environment_slug": "claude-code",
  "dataset_slug": "claude-code-telemetry",
  "query_spec": {
    "time_range": "14d",
    "calculated_fields": [
      {"name": "cache_r_f", "expression": "FLOAT($cache_read_tokens)"}
    ],
    "calculations": [
      {"op": "AVG", "column": "cache_r_f", "name": "avg_cache_read"},
      {"op": "MAX", "column": "cache_r_f", "name": "max_cache_read"},
      {"op": "AVG", "column": "cost_usd_float", "name": "avg_cost"},
      {"op": "COUNT", "name": "calls"}
    ],
    "filters": [
      {"column": "session.id", "op": "=", "value": "SESSION_ID_HERE"},
      {"column": "event.name", "op": "=", "value": "api_request"}
    ],
    "granularity": 1800
  }
}
```

**Compaction events overlay:**
```json
{
  "environment_slug": "claude-code",
  "dataset_slug": "claude-code-telemetry",
  "query_spec": {
    "time_range": "14d",
    "calculations": [
      {"op": "COUNT", "name": "compactions"}
    ],
    "filters": [
      {"column": "session.id", "op": "=", "value": "SESSION_ID_HERE"},
      {"column": "event.name", "op": "=", "value": "hook.PreCompact"}
    ],
    "granularity": 1800
  }
}
```

---

## Section 6: Per-User Deep Dives

### 6a. Per-user Opus profile (cost, context size, % calls >200K)

```json
{
  "environment_slug": "claude-code",
  "dataset_slug": "claude-code-telemetry",
  "query_spec": {
    "time_range": "14d",
    "calculated_fields": [
      {"name": "cache_r_f", "expression": "FLOAT($cache_read_tokens)"},
      {"name": "is_large_context", "expression": "IF(GT(FLOAT($cache_read_tokens), 200000), 1, 0)"}
    ],
    "calculations": [
      {"op": "COUNT", "name": "api_calls"},
      {"op": "SUM", "column": "cost_usd_float", "name": "total_cost"},
      {"op": "AVG", "column": "cache_r_f", "name": "avg_cache_read"},
      {"op": "MAX", "column": "cache_r_f", "name": "max_cache_read"},
      {"op": "P90", "column": "cache_r_f", "name": "p90_cache_read"},
      {"op": "COUNT_DISTINCT", "column": "session.id", "name": "sessions"},
      {"op": "SUM", "column": "is_large_context", "name": "calls_over_200k"}
    ],
    "breakdowns": ["user.email"],
    "filters": [
      {"column": "event.name", "op": "=", "value": "api_request"},
      {"column": "model", "op": "=", "value": "claude-opus-4-6"}
    ],
    "orders": [{"op": "SUM", "column": "cost_usd_float", "order": "descending"}],
    "limit": 100
  },
  "results_limit": 100
}
```

### 6b. Tool result breakdown for specific users

Replace the email list with target users.

```json
{
  "environment_slug": "claude-code",
  "dataset_slug": "claude-code-telemetry",
  "query_spec": {
    "time_range": "14d",
    "calculated_fields": [
      {"name": "result_size_f", "expression": "FLOAT($tool_result_size_bytes)"}
    ],
    "calculations": [
      {"op": "SUM", "column": "result_size_f", "name": "total_bytes"},
      {"op": "AVG", "column": "result_size_f", "name": "avg_bytes"},
      {"op": "COUNT", "name": "calls"}
    ],
    "breakdowns": ["user.email", "tool_name"],
    "filters": [
      {"column": "event.name", "op": "=", "value": "tool_result"},
      {"column": "user.email", "op": "in", "value": ["user1@example.com", "user2@example.com"]},
      {"column": "tool_result_size_bytes", "op": "exists"}
    ],
    "orders": [{"op": "SUM", "column": "result_size_f", "order": "descending"}],
    "limit": 40
  }
}
```

---

## Section 7: Instruction & Skill Costs

### 7a. InstructionsLoaded by file (CLAUDE.md, rules)

```json
{
  "environment_slug": "claude-code",
  "dataset_slug": "claude-code-telemetry",
  "query_spec": {
    "time_range": "14d",
    "calculations": [
      {"op": "COUNT", "name": "loads"},
      {"op": "COUNT_DISTINCT", "column": "user.email", "name": "users"},
      {"op": "COUNT_DISTINCT", "column": "session.id", "name": "sessions"}
    ],
    "breakdowns": ["normalized_file_path"],
    "filters": [
      {"column": "event.name", "op": "=", "value": "hook.InstructionsLoaded"},
      {"column": "normalized_file_path", "op": "exists"}
    ],
    "orders": [{"op": "COUNT", "order": "descending"}],
    "limit": 100
  },
  "results_limit": 500
}
```

### 7b. Skill invocations by name

Use `skill.name` (not `tool_parameters.skill_name`) to capture slash commands and auto-injected skills.

```json
{
  "environment_slug": "claude-code",
  "dataset_slug": "claude-code-telemetry",
  "query_spec": {
    "time_range": "14d",
    "calculations": [
      {"op": "COUNT", "name": "invocations"},
      {"op": "COUNT_DISTINCT", "column": "user.email", "name": "users"},
      {"op": "COUNT_DISTINCT", "column": "session.id", "name": "sessions"}
    ],
    "breakdowns": ["skill.name"],
    "filters": [
      {"column": "skill.name", "op": "exists"},
      {"column": "event.name", "op": "=", "value": "skill_invocation"}
    ],
    "orders": [{"op": "COUNT", "order": "descending"}],
    "limit": 100
  },
  "results_limit": 500
}
```
