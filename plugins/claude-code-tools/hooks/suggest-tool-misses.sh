#!/bin/bash
# suggest-tool-misses.sh - PostToolUse hook for Bash
#
# Detects genuine "command not found" errors and BSD/GNU incompatibilities in
# Bash tool output, then suggests the /tool-misses skill once per session.
#
# Opt-out: create ~/.claude/.disable-tool-misses-hook (or run `/tool-misses off`)
# to silence this hook for good. Remove it (or run `/tool-misses on`) to re-enable.

input=$(cat)

# --- Opt-out kill switch --------------------------------------------------
# Presence of the marker silences the hook entirely. Path is overridable for tests.
opt_out_file="${TOOL_MISSES_OPT_OUT_FILE:-${HOME}/.claude/.disable-tool-misses-hook}"
if [ -f "$opt_out_file" ]; then
    exit 0
fi

# Extract tool response output (may be an object with .stdout/.stderr or a plain string)
# Concatenate stdout+stderr so we catch errors regardless of which stream they appear in
tool_output=$(echo "$input" | jq -r '
  if (.tool_response | type) == "object" then
    [.tool_response.stdout // "", .tool_response.stderr // ""] | map(select(. != "")) | join("\n")
  else
    (.tool_response // "")
  end
' 2>/dev/null || echo "")

if [ -z "$tool_output" ]; then
    exit 0
fi

# Only look at FAILED commands. A genuine "command not found" / BSD-GNU error
# comes from a non-zero exit; a successful command that merely prints the phrase
# (cat-ing a log, grepping a file, or shell-init noise riding on stderr) is not a
# real miss. This is the primary guard against the file-content false-positive class.
is_error=$(echo "$input" | jq -r '
  if (.tool_response | type) == "string" then
    (.tool_response | test("Exit code [1-9]"))
  else
    ((.tool_response.exit_code // 0) != 0)
  end
' 2>/dev/null || echo "false")

if [ "$is_error" != "true" ]; then
    exit 0
fi

# Drop lines emitted by Claude Code plugin hook scripts — e.g. another plugin's
# shell-init function leaking
# "…/.claude/plugins/cache/foo/hooks/download-harness.sh: line 9: init_hook: command not found"
# onto stderr. Scope the filter to the plugin install path
# (".claude/plugins/.../hooks/") rather than any "/hooks/" path, so a miss inside
# the user's OWN repo ("/workspace/app/hooks/setup.sh: line 12: jq: command not
# found") is left intact: jq is exactly the kind of installable tool this hook
# should surface. (The exit-code gate above already drops the original
# successful-command noise; this is belt-and-suspenders for the rare hook error
# that rides on a genuinely failed command.)
signal=$(printf '%s\n' "$tool_output" | grep -Ev '\.claude/plugins/.*/hooks/')

if [ -z "$signal" ]; then
    exit 0
fi

found_issue=false

# 1) "command not found" — match only a structured shell diagnostic carrying a
#    valid command name, mirroring detect-tool-misses.py's MISSING_CMD_PATTERNS
#    plus its is_false_positive_missing() name validation. The patterns are
#    LINE-ANCHORED: the command name must sit at the start of the line or behind
#    a colon-delimited shell prefix ("bash: ", "setup.sh: line 12: "), and the
#    line must END at "command not found". This rejects prose / test output that
#    merely contains the phrase mid-sentence (e.g. "docs say hammer: command not
#    found" or "expected command not found: gsed"), which the old unanchored
#    pattern let through.
#      bash/sh form: "[<prefix>: ]*<name>: command not found"
#      zsh form:     "[<prefix>: ]command not found: <name>"
#    where <prefix> is a shell/script token ("bash", "setup.sh", "line 12", a
#    full path) and <name> is a valid command name (letters/digits/._- , no
#    slashes, colons, or spaces — same charset detect-tool-misses.py accepts).
bash_form='^[[:space:]]*(([a-zA-Z0-9._/-]+|line [0-9]+): )*[a-zA-Z_][a-zA-Z0-9._-]*: command not found[[:space:]]*$'
zsh_form='^[[:space:]]*([a-zA-Z0-9._/-]+:?[0-9]*: )?command not found: [a-zA-Z_][a-zA-Z0-9._-]*[[:space:]]*$'
if printf '%s\n' "$signal" | grep -Eq "$bash_form"; then
    found_issue=true
elif printf '%s\n' "$signal" | grep -Eq "$zsh_form"; then
    found_issue=true
fi

# 2) BSD/GNU incompatibility patterns (e.g. `grep -P`, `sed -i`, `find -printf`)
if [ "$found_issue" = false ]; then
    for pattern in \
        "invalid option -- P" \
        "invalid option -- 'P'" \
        "invalid command code" \
        "extra characters at the end of .* command" \
        "unknown primary" \
        "illegal option" \
        "invalid option -- V" \
        "unrecognized option" \
        "function .* is not defined" \
        "Option --.*is not supported" \
        "illegal line count" \
        "illegal offset"; do
        if printf '%s\n' "$signal" | grep -Eqi "$pattern"; then
            found_issue=true
            break
        fi
    done
fi

if [ "$found_issue" = false ]; then
    exit 0
fi

# Only suggest once per session
session_id=$(echo "$input" | jq -r '.session_id // "unknown"')
marker="/tmp/tool-misses-suggested-${session_id}"

if [ -f "$marker" ]; then
    exit 0
fi

touch "$marker"

cat << 'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "A genuine 'command not found' or BSD/GNU tool incompatibility was detected in command output. Mention to the user — naturally, in one sentence, and do NOT auto-invoke the skill — that they can run /tool-misses to scan recent sessions and install missing CLI tools via Homebrew, and that they can silence these suggestions with /tool-misses off (re-enable later with /tool-misses on)."
  }
}
EOF
