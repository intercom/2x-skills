#!/bin/bash
# UserPromptSubmit hook that auto-injects the fix-flaky-tests skill instruction
# when user asks about flaky tests, CI-only failures, test reproduction, or browser-crash noise.
#
# The skill description triggers reliably for investigation prompts ("investigate this
# flaky test") but misses advisory questions ("should I run more locally?", "did my fix
# make things worse?", "how do I verify this CI-only flake?"). This hook catches those
# edge cases by keyword-matching the user's prompt.

# Read hook event data from stdin
hook_data=$(cat)

# Extract user message from the JSON
user_message=$(echo "$hook_data" | jq -r '.prompt // empty' 2>/dev/null)

# Trigger paths (case-insensitive), evaluated in PRIORITY ORDER. The order matters: a
# dispute of a wrongly-closed issue can be phrased as "review #123 ... wrongly closed <url>",
# so the dispute path must win BEFORE the PR-review exclusion, or the exclusion would
# swallow a flow the skill advertises.
#
# Path A — disputing the closure/diagnosis of a tracker issue. The skill description triggers
#   on "reopen / dispute a wrongly-closed flaky-test issue", but such prompts usually carry
#   NO flaky keyword — the flaky-ness lives in the issue's title/label, not the prompt text
#   (e.g. "Address this issue, I think it was wrongly closed <url>"). Require BOTH dispute
#   language AND an explicit issue URL to stay specific; the skill opens the issue and bows
#   out if it turns out not to be a flaky-test issue.
dispute_re='(wrongly|incorrectly|mis-?) ?(closed|identified|diagnos)|re-?investigate|reopen|wrong root cause|dispute(d)?.{0,25}(closure|diagnosis|root cause)'
issue_url_re='https?://[^[:space:]]+/issues/[0-9]+'
#
# Path B exclusion — a request to *review a pull request* is a code-review task, not a
#   flaky-test investigation, even when it mentions a flaky spec ("review this PR that
#   fixes a flaky spec ..."). Matches only explicit PR / code-review phrasing —
#   deliberately NOT a bare "review #123", which can be an issue dispute handled by Path A.
review_re='\breview (this |the )?(pull request|pr)\b|\bcode review\b'
#
# Path C — flaky-test SIGNAL phrasing. Framework-agnostic — matches "flaky test", "fails in
#   CI", "passes on retry", "xit/skipped test" etc., not bare framework names (matching
#   "jest" or "pytest" alone false-fires on ordinary "set up jest" / "run pytest" prompts).
flaky_signal_re='\b(flaky|intermittent(ly)?|fail(s|ing)? in ci|passes locally|passes on retry|ci.only|flake|browser crash|xit|skipped (spec|test))\b'

if echo "$user_message" | grep -qiE "$dispute_re" \
   && echo "$user_message" | grep -qiE "$issue_url_re"; then
    : # Path A — dispute of a closed issue: fire
elif echo "$user_message" | grep -qiE "$review_re"; then
    exit 0  # Path B — PR-review request: not an investigation
elif echo "$user_message" | grep -qiE "$flaky_signal_re"; then
    : # Path C — flaky signal: fire
else
    exit 0  # No match - no additional context
fi

# Create auto-inject marker for telemetry
session_id=$(echo "$hook_data" | jq -r '.session_id // empty' 2>/dev/null)
if [[ -n "$session_id" ]]; then
    marker_dir="/tmp/auto-injected-skills/${session_id}"
    mkdir -p "$marker_dir"
    touch "${marker_dir}/fix-flaky-tests"
fi

# Inject instruction to use fix-flaky-tests skill
cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "FLAKY TESTS: Before investigating or advising on a flaky test, load the fix-flaky-tests skill. It runs progressive discovery of the test framework, CI provider, and app profile, then applies the matching classification table, CI-only reproduction guidance, browser-crash noise interpretation, and infrastructure fast-exit logic. Use: Skill(skill: \"test-tools:fix-flaky-tests\")"
  }
}
EOF
