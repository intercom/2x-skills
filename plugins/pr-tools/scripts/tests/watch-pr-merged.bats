#!/usr/bin/env bats
# Tests for ../watch-pr-merged.sh
#
# Runs the whole script end-to-end against a mock `gh` on PATH. The mock
# serves a small pre-scripted "plan" of responses (one per poll, sequenced
# via a poll counter fixture), so each test only has to describe what the PR
# endpoint returns on each successive call. WATCH_INTERVAL/WATCH_MAX_WAIT are
# zeroed so the whole suite runs in well under a second.

setup() {
  SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/watch-pr-merged.sh"

  MOCK_BIN="$(mktemp -d)"
  FIXTURES="$(mktemp -d)"
  # FIXTURES must be exported so the mock gh subprocess can read it.
  export FIXTURES

  # Generous window by default — tests that expect a terminal state must not
  # race the clock; the timeout test overrides this down itself.
  export WATCH_INTERVAL=0
  export WATCH_MAX_WAIT=30

  _write_mock_gh
  export PATH="$MOCK_BIN:$PATH"
}

teardown() {
  rm -rf "$MOCK_BIN" "$FIXTURES"
}

# Writes the response plan the mock will serve. One line per poll number
# (1-indexed); polls beyond the last line keep repeating that last line, so a
# single line is enough to simulate "stays this way forever" (the timeout case).
_set_plan() {
  printf '%s\n' "$@" > "$FIXTURES/plan.jsonl"
  printf '0' > "$FIXTURES/poll_count"
}

_write_mock_gh() {
  cat > "$MOCK_BIN/gh" <<'MOCK'
#!/usr/bin/env bash
# Mock gh. Serves the FIXTURES/plan.jsonl response plan for `gh api <endpoint> -i [...]`.
set -uo pipefail
F="$FIXTURES"

sub="${1:-}"; shift || true
[[ "$sub" == "api" ]] || { echo "gh: unexpected subcommand: $sub" >&2; exit 1; }

n=$(( $(cat "$F/poll_count") + 1 ))
printf '%s' "$n" > "$F/poll_count"

total_lines=$(wc -l < "$F/plan.jsonl")
line_num=$n
(( line_num > total_lines )) && line_num=$total_lines
line=$(sed -n "${line_num}p" "$F/plan.jsonl")

code=$(echo "$line" | jq -r '.code')
etag=$(echo "$line" | jq -r '.etag')
body=$(echo "$line" | jq -c '.body')

if [[ "$code" == "error" ]]; then
  echo "gh: Could not resolve host: api.github.com" >&2
  exit 1
elif [[ "$code" == "304" ]]; then
  printf 'HTTP/2.0 304 Not Modified\r\n'
  printf 'etag: "%s"\r\n' "$etag"
  printf '\r\n'
else
  printf 'HTTP/2.0 200 OK\r\n'
  printf 'etag: "%s"\r\n' "$etag"
  printf '\r\n'
  printf '%s\n' "$body"
fi
MOCK
  chmod +x "$MOCK_BIN/gh"
}

# ============================================================
# Usage errors
# ============================================================

@test "invalid PR URL exits 2" {
  run "$SCRIPT" "https://example.com/not-a-pr-url"
  [ "$status" -eq 2 ]
  [[ "$output" == *"Invalid PR URL"* ]]
}

@test "missing PR URL exits 2 with usage message" {
  run "$SCRIPT"
  [ "$status" -eq 2 ]
  [[ "$output" == *"Usage:"* ]]
}

# ============================================================
# Terminal states reached on the very first poll
# ============================================================

@test "merged on the first poll exits 0 with MERGED <sha>" {
  _set_plan '{"code":200,"etag":"e1","body":{"merged":true,"state":"closed","merge_commit_sha":"deadbeef"}}'
  run "$SCRIPT" "https://github.com/acme/widgets/pull/1"
  [ "$status" -eq 0 ]
  [[ "$output" == *"MERGED deadbeef"* ]]
}

@test "closed without merging exits 1 with CLOSED_UNMERGED" {
  _set_plan '{"code":200,"etag":"e1","body":{"merged":false,"state":"closed","merge_commit_sha":null}}'
  run "$SCRIPT" "https://github.com/acme/widgets/pull/2"
  [ "$status" -eq 1 ]
  [[ "$output" == *"CLOSED_UNMERGED"* ]]
}

# ============================================================
# ETag / 304 path
# ============================================================

@test "a 304 no-change poll is skipped, then a later 200 merge is caught" {
  # Poll 1 returns 304 (resuming from a prior etag, nothing changed yet);
  # poll 2 returns 200 with merged=true. Proves the loop keeps polling past
  # a no-change response instead of misreading it as a terminal state.
  _set_plan \
    '{"code":304,"etag":"priorEtag","body":{}}' \
    '{"code":200,"etag":"e2","body":{"merged":true,"state":"closed","merge_commit_sha":"cafebabe"}}'
  run "$SCRIPT" "https://github.com/acme/widgets/pull/3" "priorEtag"
  [ "$status" -eq 0 ]
  [[ "$output" == *"MERGED cafebabe"* ]]
}

# ============================================================
# Timeout / resume path
# ============================================================

@test "gh api failures retry then exit 2 after repeated errors" {
  # A failed gh call has no HTTP status line — the parse must yield an empty
  # code for the error-streak handling to see, not abort under set -e with an
  # exit 1 that reads as CLOSED_UNMERGED.
  export WATCH_MAX_WAIT=30
  _set_plan '{"code":"error","etag":"","body":{}}'
  run "$SCRIPT" "https://github.com/acme/widgets/pull/5"
  [ "$status" -eq 2 ]
  [[ "$output" == *"repeated failures"* ]]
  [[ "$output" != *"CLOSED_UNMERGED"* ]]
}

@test "PR stays open through the whole window: exits 3 with RESUME_ETAG" {
  export WATCH_MAX_WAIT=1
  _set_plan '{"code":200,"etag":"eOpen","body":{"merged":false,"state":"open","merge_commit_sha":null}}'
  run "$SCRIPT" "https://github.com/acme/widgets/pull/4"
  [ "$status" -eq 3 ]
  # The mock's etag header carries real HTTP-style quotes (as GitHub's do);
  # the script passes them through unstripped, same as pr-check-watcher.sh.
  [[ "$output" == *'RESUME_ETAG="eOpen"'* ]]
}
