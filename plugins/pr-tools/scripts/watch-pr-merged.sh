#!/bin/bash
# watch-pr-merged.sh - ETag-based polling for a GitHub PR's merged state
#
# Uses conditional HTTP requests (If-None-Match) to poll the PR resource with
# zero rate-limit cost for unchanged responses. Only 200 responses (where
# something actually changed) get reprocessed; 304 just means "keep waiting".
#
# Usage:
#   watch-pr-merged.sh <pr-url> [resume-etag]
#
# Arguments:
#   pr-url      - Full GitHub PR URL (e.g., https://github.com/org/repo/pull/123)
#   resume-etag - Optional ETag from a previous run, to resume without re-fetching
#
# Environment (overridable so tests run near-instantly):
#   WATCH_INTERVAL - poll interval in seconds (default 15)
#   WATCH_MAX_WAIT - max wait in seconds before giving up (default 570)
#
# Exit codes:
#   0 - PR merged; prints "MERGED <merge_commit_sha>"
#   1 - PR closed without merging; prints "CLOSED_UNMERGED"
#   2 - Usage error or unrecoverable API error
#   3 - Timed out; prints last known state, then "RESUME_ETAG=<etag>" to resume
set -euo pipefail

pr_url="${1:-}"
etag="${2:-}"

if [[ -z "$pr_url" ]]; then
    echo "Usage: watch-pr-merged.sh <pr-url> [resume-etag]" >&2
    exit 2
fi

if [[ "$pr_url" =~ github\.com/([^/]+)/([^/]+)/pull/([0-9]+) ]]; then
    owner="${BASH_REMATCH[1]}"
    repo="${BASH_REMATCH[2]}"
    pr_number="${BASH_REMATCH[3]}"
else
    echo "Error: Invalid PR URL: $pr_url" >&2
    exit 2
fi

endpoint="repos/$owner/$repo/pulls/$pr_number"
poll_interval="${WATCH_INTERVAL:-15}"
max_wait="${WATCH_MAX_WAIT:-570}"
start_time=$(date +%s)
last_summary=""
last_body=""
error_streak=0

# Helper: fetch the PR endpoint with optional ETag, sets $fetch_code, $fetch_etag, $fetch_body
fetch_with_etag() {
    local response
    if [[ -n "$etag" ]]; then
        response=$(gh api "$endpoint" -i -H "If-None-Match: $etag" 2>&1) || true
    else
        response=$(gh api "$endpoint" -i 2>&1) || true
    fi
    # `|| true` keeps set -e/pipefail from killing the script when a failed
    # gh call has no status line or etag header — the caller's error-streak
    # handling must see the empty value instead.
    fetch_code=$(echo "$response" | head -1 | grep -oE '[0-9]{3}' | head -1 || true)
    fetch_etag=$(echo "$response" | grep -i '^etag:' | sed 's/^[Ee][Tt][Aa][Gg]: *//' | tr -d '\r' || true)
    fetch_body=$(echo "$response" | sed '1,/^\r*$/d')
}

echo "Watching PR #$pr_number ($owner/$repo) for merge..."

# Deadline check runs AFTER each poll, not before: a terminal state landing in
# the final interval is still caught, at least one poll always happens (even
# with WATCH_MAX_WAIT < WATCH_INTERVAL), and the exit stays ~max_wait because
# the check runs before the sleep that would overshoot it.
deadline_then_sleep() {
    local elapsed=$(( $(date +%s) - start_time ))
    if (( elapsed + poll_interval > max_wait )); then
        echo ""
        echo "Polling window expired after ${max_wait}s. Last status: $last_summary"
        echo "RESUME_ETAG=${etag}"
        exit 3
    fi
    sleep "$poll_interval"
}

while true; do
    fetch_with_etag

    if [[ "$fetch_code" == "304" ]]; then
        error_streak=0
        deadline_then_sleep
        continue
    elif [[ "$fetch_code" == "200" ]]; then
        error_streak=0
        [[ -n "$fetch_etag" ]] && etag="$fetch_etag"
        last_body="$fetch_body"
    else
        error_streak=$(( error_streak + 1 ))
        echo "Warning: PR fetch returned HTTP ${fetch_code:-unknown}, retrying..." >&2
        # A handful of consecutive non-200/304 responses means something is
        # broken (auth, network), not a transient blip — stop retrying forever.
        if (( error_streak >= 5 )); then
            echo "Error: repeated failures fetching PR state" >&2
            exit 2
        fi
        deadline_then_sleep
        continue
    fi

    merged=$(echo "$last_body" | jq -r '.merged // false')
    state=$(echo "$last_body" | jq -r '.state // "unknown"')
    merge_sha=$(echo "$last_body" | jq -r '.merge_commit_sha // ""')

    summary="merged=$merged state=$state"
    if [[ "$summary" != "$last_summary" ]]; then
        echo "[$(( $(date +%s) - start_time ))s] state=$state merged=$merged"
        last_summary="$summary"
    fi

    if [[ "$merged" == "true" ]]; then
        echo "MERGED $merge_sha"
        exit 0
    fi

    if [[ "$state" == "closed" ]]; then
        echo "CLOSED_UNMERGED"
        exit 1
    fi

    deadline_then_sleep
done
