#!/usr/bin/env bats

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SCRIPT="$SCRIPT_DIR/upload.sh"

setup() {
  TEST_TEMP_DIR=$(mktemp -d)
  touch "$TEST_TEMP_DIR/shot.png" "$TEST_TEMP_DIR/clip.mov"

  # GH_MOCK_ATTACH picks the branch; GH_MOCK_VIEW_FAILS simulates a wrong PR/issue number.
  cat > "$TEST_TEMP_DIR/gh" << 'MOCK_GH'
#!/bin/bash
case "$*" in
  *comment*--help*)
    echo "  -b, --body text        The comment body text"
    if [[ "$GH_MOCK_ATTACH" == "true" ]]; then
      echo "      --attach file      Attach an image or video file"
    fi
    ;;
  "auth token")
    echo "gho_faketoken"
    ;;
  *view*--json*)
    [[ "$GH_MOCK_VIEW_FAILS" == "true" ]] && exit 1
    echo '{"id":"PR_1"}'
    ;;
  *api*repos/*)
    echo "12345	true"
    ;;
  *)
    # Record the invocation so a test can assert on the composed command.
    echo "GH_CALL: $*" >> "$GH_MOCK_LOG"
    echo "https://github.com/o/r/pull/7#issuecomment-1"
    ;;
esac
MOCK_GH
  chmod +x "$TEST_TEMP_DIR/gh"

  # Leaves a marker so a test can assert no upload was attempted.
  cat > "$TEST_TEMP_DIR/curl" << MOCK_CURL
#!/bin/bash
touch "$TEST_TEMP_DIR/curl-ran"
echo '{"url":"https://github.com/user-attachments/assets/deadbeef"}'
echo "201"
MOCK_CURL
  chmod +x "$TEST_TEMP_DIR/curl"

  export GH_MOCK_LOG="$TEST_TEMP_DIR/gh-calls.log"
  : > "$GH_MOCK_LOG"
  export PATH="$TEST_TEMP_DIR:$PATH"
}

teardown() {
  rm -rf "$TEST_TEMP_DIR"
}

# ---------- legacy positional mode stays byte-compatible ----------

@test "positional mode prints the asset URL" {
  run "$SCRIPT" "$TEST_TEMP_DIR/shot.png" 12345
  [ "$status" -eq 0 ]
  [ "$output" = "https://github.com/user-attachments/assets/deadbeef" ]
}

@test "positional mode rejects a missing file" {
  run "$SCRIPT" "$TEST_TEMP_DIR/nope.png"
  [ "$status" -eq 1 ]
  [[ "$output" == *"File not found"* ]]
}

@test "positional mode rejects an unsupported type" {
  touch "$TEST_TEMP_DIR/notes.txt"
  run "$SCRIPT" "$TEST_TEMP_DIR/notes.txt"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unsupported file type"* ]]
}

@test "no arguments prints usage" {
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage:"* ]]
}

# ---------- --post-to prefers native --attach ----------

@test "post-to uses gh --attach when available, one flag per file" {
  export GH_MOCK_ATTACH=true
  run "$SCRIPT" --post-to pr:7 --body "see below" "$TEST_TEMP_DIR/shot.png" "$TEST_TEMP_DIR/clip.mov"
  [ "$status" -eq 0 ]
  call=$(cat "$GH_MOCK_LOG")
  [[ "$call" == *"pr comment 7"* ]]
  [[ "$call" == *"--attach $TEST_TEMP_DIR/shot.png"* ]]
  [[ "$call" == *"--attach $TEST_TEMP_DIR/clip.mov"* ]]
}

@test "post-to omits --body when no body was given" {
  export GH_MOCK_ATTACH=true
  run "$SCRIPT" --post-to issue:12 "$TEST_TEMP_DIR/shot.png"
  [ "$status" -eq 0 ]
  call=$(cat "$GH_MOCK_LOG")
  [[ "$call" == *"issue comment 12"* ]]
  [[ "$call" != *"--body"* ]]
}

@test "post-to passes --repo through" {
  export GH_MOCK_ATTACH=true
  run "$SCRIPT" --post-to issue:12 --repo acme/widgets "$TEST_TEMP_DIR/shot.png"
  [ "$status" -eq 0 ]
  [[ "$(cat "$GH_MOCK_LOG")" == *"--repo acme/widgets"* ]]
}

# ---------- --post-to falls back on older gh ----------

@test "post-to falls back to upload-and-compose when gh lacks --attach" {
  export GH_MOCK_ATTACH=false
  run "$SCRIPT" --post-to pr:7 "$TEST_TEMP_DIR/shot.png"
  [ "$status" -eq 0 ]
  call=$(cat "$GH_MOCK_LOG")
  [[ "$call" != *"--attach"* ]]
  [[ "$call" == *"![shot.png](https://github.com/user-attachments/assets/deadbeef)"* ]]
}

@test "fallback posts a bare URL for video so GitHub renders a player" {
  export GH_MOCK_ATTACH=false
  run "$SCRIPT" --post-to pr:7 "$TEST_TEMP_DIR/clip.mov"
  [ "$status" -eq 0 ]
  call=$(cat "$GH_MOCK_LOG")
  [[ "$call" != *"!["* ]]
  [[ "$call" == *"https://github.com/user-attachments/assets/deadbeef"* ]]
}

# The fallback must repoint an existing reference like gh --attach does, or the same input diverges.
@test "fallback repoints a body reference instead of appending a copy" {
  export GH_MOCK_ATTACH=false
  run "$SCRIPT" --post-to pr:7 --body "before: ![shot]($TEST_TEMP_DIR/shot.png)" "$TEST_TEMP_DIR/shot.png"
  [ "$status" -eq 0 ]
  call=$(cat "$GH_MOCK_LOG")
  [[ "$call" == *"![shot](https://github.com/user-attachments/assets/deadbeef)"* ]]
  [[ "$call" != *"$TEST_TEMP_DIR/shot.png"* ]]
  [ "$(grep -c 'deadbeef' "$GH_MOCK_LOG")" -eq 1 ]
}

@test "fallback still appends a file the body never referenced" {
  export GH_MOCK_ATTACH=false
  run "$SCRIPT" --post-to pr:7 --body "context only" "$TEST_TEMP_DIR/shot.png"
  [ "$status" -eq 0 ]
  call=$(cat "$GH_MOCK_LOG")
  [[ "$call" == *"context only"* ]]
  [[ "$call" == *"![shot.png](https://github.com/user-attachments/assets/deadbeef)"* ]]
}

@test "fallback posts one comment for multiple files" {
  export GH_MOCK_ATTACH=false
  run "$SCRIPT" --post-to pr:7 "$TEST_TEMP_DIR/shot.png" "$TEST_TEMP_DIR/clip.mov"
  [ "$status" -eq 0 ]
  [ "$(grep -c 'GH_CALL' "$GH_MOCK_LOG")" -eq 1 ]
}

# ---------- --post-to argument validation ----------

@test "post-to rejects a bad kind" {
  run "$SCRIPT" --post-to discussion:7 "$TEST_TEMP_DIR/shot.png"
  [ "$status" -eq 1 ]
  [[ "$output" == *"must be pr:<number> or issue:<number>"* ]]
}

@test "post-to rejects a non-numeric number" {
  run "$SCRIPT" --post-to pr:abc "$TEST_TEMP_DIR/shot.png"
  [ "$status" -eq 1 ]
  [[ "$output" == *"positive number"* ]]
}

# There is no PR or issue 0, so accepting it would only ever orphan uploads.
@test "post-to rejects zero as a number" {
  run "$SCRIPT" --post-to pr:0 "$TEST_TEMP_DIR/shot.png"
  [ "$status" -eq 1 ]
  [[ "$output" == *"positive number"* ]]
}

# Uploads are irreversible, so a missing target must be caught before any run.
@test "fallback checks the target exists before uploading" {
  export GH_MOCK_ATTACH=false GH_MOCK_VIEW_FAILS=true
  run "$SCRIPT" --post-to pr:404 "$TEST_TEMP_DIR/shot.png"
  [ "$status" -eq 1 ]
  [[ "$output" == *"No pr #404"* ]]
  [ ! -s "$GH_MOCK_LOG" ]
  [ ! -f "$TEST_TEMP_DIR/curl-ran" ]
}

@test "fallback refuses a reference-style link it cannot rewrite faithfully" {
  export GH_MOCK_ATTACH=false
  run "$SCRIPT" --post-to pr:7 --body "[shot]: $TEST_TEMP_DIR/shot.png" "$TEST_TEMP_DIR/shot.png"
  [ "$status" -eq 1 ]
  [[ "$output" == *"reference-style link"* ]]
  [ ! -f "$TEST_TEMP_DIR/curl-ran" ]
}

# Reproducing gh's markdown parsing here isn't worth it, so the fallback refuses instead.
@test "fallback refuses a video written as an image embed" {
  export GH_MOCK_ATTACH=false
  run "$SCRIPT" --post-to pr:7 --body "![clip]($TEST_TEMP_DIR/clip.mov)" "$TEST_TEMP_DIR/clip.mov"
  [ "$status" -eq 1 ]
  [[ "$output" == *"video written as an image embed"* ]]
  [ ! -f "$TEST_TEMP_DIR/curl-ran" ]
}

@test "post-to rejects zero files" {
  run "$SCRIPT" --post-to pr:7
  [ "$status" -eq 1 ]
  [[ "$output" == *"at least one file"* ]]
}

# Checked before the branch so 51 files fails the same way on old and new gh.
@test "post-to rejects more than 50 files on either branch" {
  files=()
  for i in $(seq 1 51); do
    touch "$TEST_TEMP_DIR/f$i.png"
    files+=("$TEST_TEMP_DIR/f$i.png")
  done

  for attach in true false; do
    export GH_MOCK_ATTACH="$attach"
    : > "$GH_MOCK_LOG"
    run "$SCRIPT" --post-to pr:7 "${files[@]}"
    [ "$status" -eq 1 ]
    [[ "$output" == *"at most 50 files"* ]]
    [ ! -s "$GH_MOCK_LOG" ]
  done
}

@test "post-to accepts exactly 50 files" {
  export GH_MOCK_ATTACH=true
  files=()
  for i in $(seq 1 50); do
    touch "$TEST_TEMP_DIR/f$i.png"
    files+=("$TEST_TEMP_DIR/f$i.png")
  done

  run "$SCRIPT" --post-to pr:7 "${files[@]}"
  [ "$status" -eq 0 ]
  [ "$(grep -c 'GH_CALL' "$GH_MOCK_LOG")" -eq 1 ]
}

@test "a flag missing its value fails loudly instead of looping" {
  run "$SCRIPT" --post-to
  [ "$status" -eq 1 ]
  [[ "$output" == *"needs a value"* ]]
}

@test "unknown flags are rejected" {
  run "$SCRIPT" --nope "$TEST_TEMP_DIR/shot.png"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown flag"* ]]
}

# Uploads can't be undone, so partial success would orphan assets on GitHub.
@test "post-to validates every file before uploading any" {
  export GH_MOCK_ATTACH=false
  run "$SCRIPT" --post-to pr:7 "$TEST_TEMP_DIR/shot.png" "$TEST_TEMP_DIR/missing.png"
  [ "$status" -eq 1 ]
  [[ "$output" == *"File not found"* ]]
  [ ! -s "$GH_MOCK_LOG" ]
}
