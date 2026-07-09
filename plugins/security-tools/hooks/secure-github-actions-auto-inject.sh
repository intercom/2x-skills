#!/bin/bash
# PostToolUse hook that auto-injects the secure-github-actions skill
# when editing GitHub Actions workflow files

hook_data=$(cat)

# Fast path: this hook only acts on files under .github/workflows/ or
# .github/workflows-disabled/ (the latter contains the former as a substring).
# Claude Code matchers key on tool name, not path, so the harness fires this on
# every Read/Edit/Write — gate on a cheap string compare before paying for jq.
[[ "$hook_data" != *".github/workflows"* ]] && exit 0

file_path=$(echo "$hook_data" | jq -r '.tool_input.file_path // .tool_input.filePath // ""')

[[ -z "$file_path" ]] && exit 0

if [[ "$file_path" == *".github/workflows/"*".yml" ]] || [[ "$file_path" == *".github/workflows/"*".yaml" ]] || [[ "$file_path" == *".github/workflows-disabled/"*".yml" ]] || [[ "$file_path" == *".github/workflows-disabled/"*".yaml" ]]; then
    cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "You are editing a GitHub Actions workflow file. You MUST use the Skill tool to invoke security-tools:secure-github-actions to ensure this workflow follows supply-chain and injection-attack hardening rules. Use: Skill(skill: \"security-tools:secure-github-actions\") if not already loaded."
  }
}
EOF
fi

exit 0
