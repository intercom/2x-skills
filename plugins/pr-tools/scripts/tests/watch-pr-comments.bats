#!/usr/bin/env bats
# Tests for ../watch-pr-comments.sh
#
# Runs the whole script end-to-end against a mock `gh` on PATH. The mock
# dispatches on the requested endpoint (issue comments / reviews / review
# comments, page 1 vs page 2) and returns fixture JSON. When called with -i
# it wraps the body in an HTTP-response shape (status line, etag header,
# blank line, body) matching what fetch_with_etag expects; without -i it
# returns the bare body, matching the pagination fetches.
# WATCH_INTERVAL/WATCH_MAX_WAIT are zeroed so the suite runs in well under a
# second.

setup() {
  SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/watch-pr-comments.sh"

  MOCK_BIN="$(mktemp -d)"
  FIXTURES="$(mktemp -d)"
  export FIXTURES

  export WATCH_INTERVAL=0
  export WATCH_MAX_WAIT=2

  PR_URL="https://github.com/acme/widgets/pull/42"
  SINCE="2025-01-01T00:00:00Z"

  printf '[]' > "$FIXTURES/issue_comments.json"
  printf '[]' > "$FIXTURES/issue_comments_page2.json"
  printf '[]' > "$FIXTURES/reviews.json"
  printf '[]' > "$FIXTURES/review_comments.json"
  printf '[]' > "$FIXTURES/review_comments_page2.json"

  _write_mock_gh
  export PATH="$MOCK_BIN:$PATH"
}

teardown() {
  rm -rf "$MOCK_BIN" "$FIXTURES"
}

_write_mock_gh() {
  cat > "$MOCK_BIN/gh" <<'MOCK'
#!/usr/bin/env bash
# Mock gh. Dispatches on the api endpoint; reads fixtures from $FIXTURES.
set -uo pipefail
F="$FIXTURES"

sub="${1:-}"; shift || true
if [[ "$sub" != "api" ]]; then
  echo "gh: unexpected subcommand: $sub" >&2
  exit 1
fi

endpoint=""
with_headers=false
for a in "$@"; do
  case "$a" in
    -i) with_headers=true ;;
    -*) ;;
    *) [[ -z "$endpoint" ]] && endpoint="$a" ;;
  esac
done

case "$endpoint" in
  *issues/*/comments\?*page=2*)
    body="$(cat "$F/issue_comments_page2.json")"
    ;;
  *issues/*/comments\?*)
    body="$(cat "$F/issue_comments.json")"
    ;;
  *pulls/*/reviews\?*)
    body="$(cat "$F/reviews.json")"
    ;;
  *pulls/*/comments\?*page=2*)
    body="$(cat "$F/review_comments_page2.json")"
    ;;
  *pulls/*/comments\?*)
    body="$(cat "$F/review_comments.json")"
    ;;
  *)
    echo "gh: unexpected endpoint: $endpoint" >&2
    exit 1
    ;;
esac

if [[ "$with_headers" == "true" ]]; then
  printf 'HTTP/2.0 200\n'
  printf 'etag: "mock-etag"\n'
  printf '\n'
fi
printf '%s\n' "$body"
MOCK
  chmod +x "$MOCK_BIN/gh"
}

run_watch() {
  run "$SCRIPT" "$@"
}

# The cursor for the next run is the poll-round start time (see the script
# header), so tests assert its ISO-8601 shape rather than an exact value.
assert_next_since_is_timestamp() {
  [[ "$output" =~ NEXT_SINCE=2[0-9]{3}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z ]]
}

# ============================================================
# Usage
# ============================================================

@test "invalid PR URL exits 2" {
  run_watch "not-a-pr-url"
  [ "$status" -eq 2 ]
  [[ "$output" == *"Usage: watch-pr-comments.sh"* || "$output" == *"Invalid PR or issue URL"* ]]
}

@test "issue URL is accepted and PR-only endpoints are skipped" {
  printf '[{"id":1,"user":{"login":"octocat"},"created_at":"2025-01-02T00:00:00Z","updated_at":"2025-01-02T00:00:00Z","body":"issue-hello"}]' > "$FIXTURES/issue_comments.json"
  # A review that WOULD emit if reviews were polled — in issue mode the pulls/*
  # endpoints must be skipped, so this sentinel must not appear in the output.
  printf '[{"id":9,"user":{"login":"reviewer"},"submitted_at":"2025-01-02T00:00:00Z","state":"APPROVED","body":"SHOULD-NOT-APPEAR"}]' > "$FIXTURES/reviews.json"

  run_watch "https://github.com/acme/widgets/issues/42" "$SINCE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"issue-hello"* ]]
  [[ "$output" != *"SHOULD-NOT-APPEAR"* ]]
}

# ============================================================
# New issue comment
# ============================================================

@test "a new issue comment is printed and NEXT_SINCE advances" {
  printf '[{"id":101,"user":{"login":"alice"},"created_at":"2025-06-01T12:00:00Z","updated_at":"2025-06-01T12:00:00Z","body":"Looks good, one nit: fix the typo"}]' > "$FIXTURES/issue_comments.json"

  run_watch "$PR_URL" "$SINCE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"comment alice 2025-06-01T12:00:00Z: Looks good, one nit: fix the typo"* ]]
  assert_next_since_is_timestamp
}

@test "an edited old comment is reported with its edit time" {
  # `since=` filters on updated_at, so an old comment edited after the cursor
  # comes back — it must be reported under its edit time, not silently
  # re-served on every subsequent run under its (pre-cursor) creation time.
  printf '[{"id":102,"user":{"login":"alice"},"created_at":"2024-06-01T00:00:00Z","updated_at":"2025-06-02T09:00:00Z","body":"edited: actually use the other helper"}]' > "$FIXTURES/issue_comments.json"

  run_watch "$PR_URL" "$SINCE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"comment alice 2025-06-02T09:00:00Z: edited: actually use the other helper"* ]]
}

@test "an empty-body comment keeps its columns aligned" {
  # Comments carry an empty state column; the delimiter must not collapse
  # around empty fields (tab-IFS would shift the body into state).
  printf '[{"id":103,"user":{"login":"carol"},"created_at":"2025-06-03T00:00:00Z","updated_at":"2025-06-03T00:00:00Z","body":""}]' > "$FIXTURES/issue_comments.json"

  run_watch "$PR_URL" "$SINCE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"comment carol 2025-06-03T00:00:00Z:"* ]]
}

# ============================================================
# Pagination — a full first page means there is more to fetch
# ============================================================

@test "a full 100-item first page triggers a page-2 fetch" {
  jq -n '[range(100) | {id: ., user: {login: "gen"}, created_at: "2025-06-01T00:00:00Z", updated_at: "2025-06-01T00:00:00Z", body: ("c" + (. | tostring))}]' > "$FIXTURES/issue_comments.json"
  printf '[{"id":200,"user":{"login":"dave"},"created_at":"2025-06-01T00:01:00Z","updated_at":"2025-06-01T00:01:00Z","body":"second page comment"}]' > "$FIXTURES/issue_comments_page2.json"

  run_watch "$PR_URL" "$SINCE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"c99"* ]]
  [[ "$output" == *"second page comment"* ]]
}

# ============================================================
# Reviews — client-side cursor filtering (no since= support)
# ============================================================

@test "an older review is not emitted while a newer one is" {
  cat > "$FIXTURES/reviews.json" <<JSON
[
  {"id":1,"user":{"login":"old-reviewer"},"submitted_at":"2024-01-01T00:00:00Z","state":"COMMENTED","body":"stale review, predates cursor"},
  {"id":2,"user":{"login":"bob"},"submitted_at":"2025-06-01T12:00:00Z","state":"APPROVED","body":"ship it"}
]
JSON

  run_watch "$PR_URL" "$SINCE"
  [ "$status" -eq 0 ]
  [[ "$output" != *"old-reviewer"* ]]
  [[ "$output" != *"stale review"* ]]
  [[ "$output" == *"review(APPROVED) bob 2025-06-01T12:00:00Z: ship it"* ]]
  assert_next_since_is_timestamp
}

# ============================================================
# Timeout — nothing new ever appears
# ============================================================

@test "timeout with no new activity exits 3 with NEXT_SINCE unchanged" {
  export WATCH_MAX_WAIT=1

  run_watch "$PR_URL" "$SINCE"
  [ "$status" -eq 3 ]
  [[ "$output" == *"NEXT_SINCE=$SINCE"* ]]
  [[ "$output" != *"comment "* ]]
  [[ "$output" != *"review("* ]]
  [[ "$output" != *"review-comment "* ]]
}

# ============================================================
# API failure
# ============================================================

@test "a gh api failure exits 2 with a diagnostic, not a silent 1" {
  cat > "$MOCK_BIN/gh" <<'BROKEN'
#!/usr/bin/env bash
echo "gh: Could not resolve host: api.github.com" >&2
exit 1
BROKEN
  chmod +x "$MOCK_BIN/gh"

  run_watch "$PR_URL" "$SINCE"
  [ "$status" -eq 2 ]
  [[ "$output" == *"Error: gh api"* ]]
}
