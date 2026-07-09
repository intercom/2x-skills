#!/usr/bin/env bash
# Returns JSON with repo context needed for PR creation in a single call.
# Usage: bash "${CLAUDE_PLUGIN_ROOT}/skills/create-pr/scripts/check-pr-context.sh"
# Output: {"repo":"...","visibility":"PUBLIC|PRIVATE|INTERNAL|UNKNOWN","branch":"...","already_pushed":bool,"default_branch":"..."}

# `git config --get remote.origin.url` is read-only — it reads the remote without
# any chance of mutating it (unlike `git remote ...`, which can rewrite remotes).
REPO_FULL=$(git config --get remote.origin.url 2>/dev/null | sed -E 's|^.*github\.com[:/]||; s|\.git$||') || REPO_FULL=""

VISIBILITY=$(gh repo view --json visibility -q '.visibility' 2>/dev/null || echo "UNKNOWN")

BRANCH=$(git branch --show-current 2>/dev/null || echo "")

ALREADY_PUSHED="false"
if [ -n "$BRANCH" ] && git ls-remote --heads origin "$BRANCH" 2>/dev/null | grep -q .; then
  ALREADY_PUSHED="true"
fi

DEFAULT_BRANCH=$(gh repo view --json defaultBranchRef -q '.defaultBranchRef.name' 2>/dev/null || echo "main")

jq -nc \
  --arg repo "$REPO_FULL" \
  --arg visibility "$VISIBILITY" \
  --arg branch "$BRANCH" \
  --argjson already_pushed "$ALREADY_PUSHED" \
  --arg default_branch "$DEFAULT_BRANCH" \
  '{repo:$repo,visibility:$visibility,branch:$branch,already_pushed:$already_pushed,default_branch:$default_branch}'
