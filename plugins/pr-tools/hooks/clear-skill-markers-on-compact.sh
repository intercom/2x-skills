#!/bin/bash
# PreCompact hook that clears skill activation markers.
#
# After context compaction, the agent loses awareness of previously loaded
# skills. Without clearing markers, the intercept-gh-pr-create hook would
# still find a stale marker and allow gh pr create through — even though
# the agent no longer has the create-pr skill instructions in context.

hook_data=$(cat)

if [[ "$hook_data" =~ \"session_id\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
    session_id="${BASH_REMATCH[1]}"
else
    exit 0
fi

# Clear both session-scoped and agent-scoped markers
marker_dir="/tmp/activated-skills/${session_id}"
if [[ -d "$marker_dir" ]]; then
    rm -rf "$marker_dir"
fi

exit 0
