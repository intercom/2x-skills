#!/bin/bash
# PostToolUse hook that auto-injects the secure-github-actions skill
# when editing GitHub Actions workflow files. Fails open — any error here
# skips the nudge rather than blocking the write.

hook_data=$(cat)

# Fast path: this hook only acts on files under .github/workflows/ or
# .github/workflows-disabled/ (the latter contains the former as a substring).
# Claude Code matchers key on tool name, not path, so the harness fires this on
# every Read/Edit/Write — gate on a cheap string compare before paying for jq.
[[ "$hook_data" != *".github/workflows"* ]] && exit 0

file_path=$(echo "$hook_data" | jq -r '.tool_input.file_path // .tool_input.filePath // ""')

[[ -z "$file_path" ]] && exit 0

if [[ "$file_path" == *".github/workflows/"*".yml" ]] || [[ "$file_path" == *".github/workflows/"*".yaml" ]] || [[ "$file_path" == *".github/workflows-disabled/"*".yml" ]] || [[ "$file_path" == *".github/workflows-disabled/"*".yaml" ]]; then
    # Once-per-session dedup marker, cleared by clear-skill-markers-on-compact.sh.
    session_id=$(echo "$hook_data" | jq -r '.session_id // empty' 2>/dev/null)
    if [[ -n "$session_id" ]]; then
        marker_dir="/tmp/activated-skills/${session_id}"
        marker="${marker_dir}/secure-github-actions-injected"
        if [[ -f "$marker" ]]; then
            exit 0
        fi
        mkdir -p "$marker_dir" 2>/dev/null
        touch "$marker" 2>/dev/null
    fi

    cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "Editing a GitHub Actions workflow — load security-tools:secure-github-actions for supply-chain and injection-attack hardening rules."
  }
}
EOF
fi

exit 0
