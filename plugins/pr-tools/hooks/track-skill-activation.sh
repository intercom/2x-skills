#!/bin/bash
# Synchronous PreToolUse:Skill hook that records skill activations.
#
# Writes a marker file per session+skill so other hooks can deterministically
# check whether a given skill has been loaded in this session.
#
# Marker location: /tmp/activated-skills/{session_id}/{skill_name}
#                  /tmp/activated-skills/{session_id}/{agent_id}/{skill_name}  (inside subagents)
#
# Markers are cleared on context compaction (by clear-skill-markers-on-compact.sh)
# so the agent must re-invoke skills after compaction.
#
# This replaces the old approach of grepping the transcript for skill names,
# which caused false positives when file contents happened to mention a skill.

hook_data=$(cat)

# Pure bash JSON extraction — avoids jq overhead on every Skill call
# Regex handles both minified ("key":"val") and pretty-printed ("key": "val") JSON
if [[ "$hook_data" =~ \"session_id\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
    session_id="${BASH_REMATCH[1]}"
else
    exit 0
fi

if [[ "$hook_data" =~ \"skill\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
    skill_name="${BASH_REMATCH[1]}"
else
    exit 0
fi

# Scope markers to agent_id when running inside a subagent, so that a skill
# activated in one agent doesn't unlock guarded commands for other agents.
if [[ "$hook_data" =~ \"agent_id\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
    marker_dir="/tmp/activated-skills/${session_id}/${BASH_REMATCH[1]}"
else
    marker_dir="/tmp/activated-skills/${session_id}"
fi
mkdir -p "$marker_dir"
touch "${marker_dir}/${skill_name}"

# Clean up stale session dirs older than 24h
find /tmp/activated-skills -mindepth 1 -maxdepth 1 -type d -mtime +1 -exec rm -rf {} + 2>/dev/null &

exit 0
