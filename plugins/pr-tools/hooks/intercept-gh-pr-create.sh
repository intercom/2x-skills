#!/bin/bash
# PreToolUse hook that intercepts gh pr create and redirects to create-pr skill
#
# Blocks direct `gh pr create` unless the create-pr skill has already been
# activated in this session. Activation is tracked via marker files written
# by track-skill-activation.sh (deterministic, no transcript grepping).
#
# Markers are cleared on context compaction (by clear-skill-markers-on-compact.sh)
# so the agent must re-invoke the skill after compaction.
#
# `/rewind`, however, fires NO hook, so a marker is NOT cleared when the user
# rewinds the conversation back past the create-pr load — leaving the guard
# permanently satisfied even though the skill is no longer in context. To close
# that gap, when a session-scoped marker is found we re-validate it against the
# current branch of the transcript (skill-active-in-transcript.py): the marker
# only counts if the create-pr Skill tool_use is still an ancestor of the latest
# leaf. We fail OPEN (honour the marker) whenever validation is inconclusive, so
# this can only ever re-block a load that was provably rewound away — never a
# legitimate in-context activation.

# Read hook event data from stdin
hook_data=$(cat)

# Extract tool name and command from the JSON
tool_name=$(echo "$hook_data" | jq -r '.tool_name // empty' 2>/dev/null)
command=$(echo "$hook_data" | jq -r '.tool_input.command // empty' 2>/dev/null)

# Only intercept Bash tool calls
if [[ "$tool_name" != "Bash" ]]; then
    exit 0
fi

# Strip single-quoted, double-quoted, and heredoc-delimited content before
# matching so that the phrase inside a quoted flag value or heredoc body
# isn't treated as a real invocation. Logic lives in a sibling helper so
# it can be tested (and reused) on its own.
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STRIP_HELPER="${HOOK_DIR}/../scripts/strip-quoted-and-heredocs.py"
SKILL_ACTIVE_HELPER="${HOOK_DIR}/../scripts/skill-active-in-transcript.py"

cleaned_command=$(printf '%s' "$command" | python3 "$STRIP_HELPER")

# Check if the cleaned command contains "gh pr create"
if [[ "$cleaned_command" =~ gh[[:space:]]+pr[[:space:]]+create ]]; then
    # Allow if the create-pr skill has been activated in this session
    # Pure bash JSON extraction — matches track-skill-activation.sh approach
    # Regex handles both minified and pretty-printed JSON
    if [[ "$hook_data" =~ \"session_id\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
        session_id="${BASH_REMATCH[1]}"
    else
        # Can't determine session — don't block
        exit 0
    fi

    # Check agent-scoped markers first (subagent context), then session-scoped
    if [[ "$hook_data" =~ \"agent_id\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
        agent_marker_dir="/tmp/activated-skills/${session_id}/${BASH_REMATCH[1]}"
        if [[ -f "${agent_marker_dir}/create-pr" || -f "${agent_marker_dir}/pr-tools:create-pr" ]]; then
            exit 0
        fi
    else
        marker_dir="/tmp/activated-skills/${session_id}"
        if [[ -f "${marker_dir}/create-pr" || -f "${marker_dir}/pr-tools:create-pr" ]]; then
            # Marker present. Re-validate it against the current transcript branch
            # so a marker left behind by a /rewind (which fires no hook, so it is
            # never cleared) doesn't keep the guard satisfied after the create-pr
            # load was rewound out of context. Fail OPEN unless the load is
            # provably absent from the active branch (helper exit code 1).
            if [[ "$hook_data" =~ \"transcript_path\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
                transcript_path="${BASH_REMATCH[1]}"
            else
                transcript_path=""
            fi

            if [[ -n "$transcript_path" && -f "$transcript_path" ]] && command -v python3 >/dev/null 2>&1; then
                python3 "$SKILL_ACTIVE_HELPER" "$transcript_path" create-pr
                if [[ "$?" -ne 1 ]]; then
                    # 0 = create-pr still active in this branch; 2 = undetermined.
                    # Either way, honour the marker.
                    exit 0
                fi
                # Exit 1: create-pr was rewound away — fall through and re-block.
            else
                # No transcript available to validate — preserve prior behaviour.
                exit 0
            fi
        fi
    fi

    echo "❌ Direct gh pr create detected - use the create-pr skill instead.

Use: Skill(skill: \"pr-tools:create-pr\")

The create-pr skill ensures proper PR descriptions by:
- Extracting intent from the session (asks if missing)
- Following the Why?/How? format standard
- Creating meaningful documentation" >&2
    exit 2
fi

# Command is allowed
exit 0
