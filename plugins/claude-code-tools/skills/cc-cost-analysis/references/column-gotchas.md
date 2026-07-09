# Column Gotchas — Cost Analysis Specific

Data-quality gotchas specific to analyzing Claude Code cost telemetry. Field names vary by export pipeline and Claude Code version — verify against your own schema.

## String-stored numerics

Token counts and cost are sometimes exported as strings. Aggregating a string column with `SUM`/`AVG` returns null. Cast first with a calculated field, e.g. `{"name": "cost_f", "expression": "FLOAT($cost_usd)"}`, then aggregate `cost_f`. The example queries use a pre-cast `cost_usd_float` column; adapt to your schema.

## Cost is only meaningful on API-request events

A per-call cost value is only populated on the event that represents an API request (`event.name = "api_request"` in the examples). On hook events, tool events, etc. it is typically 0 or null. Always filter to the API-request event when summing cost.

## event.sequence interpretation

`event.sequence` (where present) is the sequence number across ALL events in a session, not just API requests — sequence 0 might be a hook event, not the first API call. When analyzing the cost curve by turn number, filter to the API-request event and `event.sequence exists` first.

The "OTHER" bucket in `event.sequence` queries (sequence beyond the limit) contains the long-tail turns that typically dominate cost.

## Skill-name fields

Depending on your telemetry, skill invocations may appear under more than one field — one that captures only explicit `Skill` tool calls, and a broader one that also captures `/slash` commands and auto-injected skills. Prefer the broadest field for skill cost analysis, and note that skills can appear under both bare names (`create-pr`) and prefixed names (`some-plugin:create-pr`) — consolidate when aggregating.

## Model identifiers

Model IDs include version dates and change with new releases. Verify current identifiers with a `GROUP BY model` query before hardcoding them in filters.
