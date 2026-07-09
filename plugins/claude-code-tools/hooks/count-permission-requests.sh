#!/bin/bash
# count-permission-requests.sh - async PermissionRequest hook
#
# Increments a per-session counter each time a permission prompt fires.
# The counter is read by suggest-permissions-analyzer.sh (a PostToolUse hook)
# to suggest the /permissions-analyzer skill after enough prompts accumulate.

input=$(cat)

session_id=$(echo "$input" | jq -r '.session_id // "unknown"')

count_file="/tmp/permissions-analyzer-count-${session_id}"
count=0
if [ -f "$count_file" ]; then
    count=$(cat "$count_file" 2>/dev/null || echo "0")
fi
count=$((count + 1))
echo "$count" > "$count_file"
