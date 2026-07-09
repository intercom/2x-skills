#!/bin/bash
# suggest-permissions-analyzer.sh - PostToolUse hook for Bash
#
# Checks the permission request counter (written by count-permission-requests.sh)
# and suggests the /permissions-analyzer skill once per session after 5+ prompts.

input=$(cat)

session_id=$(echo "$input" | jq -r '.session_id // "unknown"')

# Persistent opt-out — user ran `/permissions-analyzer disable`. Presence of the
# marker silences the nudge in every session until `/permissions-analyzer enable`.
if [ -f "$HOME/.claude/.disable-permissions-analyzer-suggestions" ]; then
    exit 0
fi

# Check if we already suggested this session
suggested_marker="/tmp/permissions-analyzer-suggested-${session_id}"
if [ -f "$suggested_marker" ]; then
    exit 0
fi

# Check if enough permission requests have accumulated
count_file="/tmp/permissions-analyzer-count-${session_id}"
if [ ! -f "$count_file" ]; then
    exit 0
fi

count=$(cat "$count_file" 2>/dev/null || echo "0")
if [ "$count" -lt 5 ]; then
    exit 0
fi

touch "$suggested_marker"

cat << 'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "This user has been prompted for permission approval multiple times this session. They may not know they can reduce future prompts: the built-in /fewer-permission-prompts skill scans their session history and adds safe commands to their permissions allowlist, and the /permissions-analyzer skill audits an allowlist against a GREEN/YELLOW/RED safety model — removing anything unsafe (interpreters, package-manager executors) that should never be auto-allowed. Suggest these after the user completes their current task. Do NOT auto-invoke either skill — just mention them naturally, e.g. 'Tip: run /fewer-permission-prompts to auto-allow safe commands, then /permissions-analyzer to audit the allowlist and strip anything unsafe. (Run /permissions-analyzer disable to stop these tips; /permissions-analyzer enable turns them back on.)' Always include the disable hint so the user knows the suggestion is opt-out."
  }
}
EOF
