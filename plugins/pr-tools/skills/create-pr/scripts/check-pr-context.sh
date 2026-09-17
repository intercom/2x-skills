#!/usr/bin/env bash
# Returns JSON with repo context needed for PR creation in a single call.
# Usage: bash "${CLAUDE_PLUGIN_ROOT}/skills/create-pr/scripts/check-pr-context.sh"
# Output: {"repo":"...","visibility":"PUBLIC|PRIVATE|INTERNAL|UNKNOWN","branch":"...","already_pushed":bool,"default_branch":"..."}

# `git config --get remote.origin.url` is read-only — it reads the remote without
# any chance of mutating it (unlike `git remote ...`, which can rewrite remotes).
REPO_FULL=$(git config --get remote.origin.url 2>/dev/null | sed -E 's|^.*github\.com[:/]||; s|\.git$||') || REPO_FULL=""

# Name the repo explicitly: gh can't infer it from a remote that isn't a plain github.com URL.
GH_REPO=()
if [[ "$REPO_FULL" =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ ]]; then
  GH_REPO=("$REPO_FULL")
fi

VISIBILITY=$(gh repo view "${GH_REPO[@]}" --json visibility -q '.visibility' 2>/dev/null || echo "UNKNOWN")

BRANCH=$(git branch --show-current 2>/dev/null || echo "")

ALREADY_PUSHED="false"
if [ -n "$BRANCH" ] && git ls-remote --heads origin "$BRANCH" 2>/dev/null | grep -q .; then
  ALREADY_PUSHED="true"
fi

# Fall back to the local clone before hardcoding "main" — avoids the wrong base on a master-default repo.
DEFAULT_BRANCH=$(gh repo view "${GH_REPO[@]}" --json defaultBranchRef -q '.defaultBranchRef.name' 2>/dev/null)
if [ -z "$DEFAULT_BRANCH" ] || [ "$DEFAULT_BRANCH" = "null" ]; then
  DEFAULT_BRANCH=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')
fi
: "${DEFAULT_BRANCH:=main}"

jq -nc \
  --arg repo "$REPO_FULL" \
  --arg visibility "$VISIBILITY" \
  --arg branch "$BRANCH" \
  --argjson already_pushed "$ALREADY_PUSHED" \
  --arg default_branch "$DEFAULT_BRANCH" \
  '{repo:$repo,visibility:$visibility,branch:$branch,already_pushed:$already_pushed,default_branch:$default_branch}'
