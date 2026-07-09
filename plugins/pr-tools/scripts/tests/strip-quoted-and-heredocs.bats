#!/usr/bin/env bats
# Tests for strip-quoted-and-heredocs.py
#
# Verifies the helper strips quoted segments and heredoc bodies so callers
# can match command-phrase patterns against the cleaned text.

setup() {
  SCRIPTS_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  HELPER="$SCRIPTS_DIR/strip-quoted-and-heredocs.py"
}

# Pipe stdin into the helper, capture stdout
run_helper() {
  printf '%s' "$1" | python3 "$HELPER"
}

# ============================================================
# Unquoted content passes through unchanged
# ============================================================

@test "passes through a bare command unchanged" {
  result=$(run_helper "foo bar baz")
  [ "$result" = "foo bar baz" ]
}

@test "passes through multi-line unquoted content unchanged" {
  input=$'cd /tmp\nls -la\necho done'
  result=$(run_helper "$input")
  [ "$result" = "$input" ]
}

# ============================================================
# Single-quoted segments are stripped
# ============================================================

@test "strips single-quoted segment" {
  result=$(run_helper "echo 'hidden phrase'")
  [ "$result" = "echo " ]
}

@test "strips multiple single-quoted segments" {
  result=$(run_helper "foo 'a' bar 'b'")
  [ "$result" = "foo  bar " ]
}

# ============================================================
# Double-quoted segments are stripped (with escape handling)
# ============================================================

@test "strips double-quoted segment" {
  result=$(run_helper 'echo "hidden phrase"')
  [ "$result" = "echo " ]
}

@test "strips double-quoted segment containing escaped quotes" {
  # `echo "he said \"hi\""` — whole quoted span (with inner \") strips out
  result=$(run_helper 'echo "he said \"hi\""')
  [ "$result" = "echo " ]
}

# ============================================================
# Heredoc bodies are stripped
# ============================================================

@test "strips plain heredoc body" {
  input=$'cat <<EOF\nsecret line\nEOF'
  result=$(run_helper "$input")
  [ "$result" = "cat " ]
}

@test "strips dash-indented heredoc body" {
  input=$'cat <<-EOF\n\tsecret line\n\tEOF'
  result=$(run_helper "$input")
  [ "$result" = "cat " ]
}

@test "strips quoted-delimiter heredoc body" {
  input=$'cat <<\'EOF\'\nsecret line\nEOF'
  result=$(run_helper "$input")
  [ "$result" = "cat " ]
}

@test "strips heredoc with double-quoted delimiter" {
  input=$'cat <<"EOF"\nsecret line\nEOF'
  result=$(run_helper "$input")
  [ "$result" = "cat " ]
}

# ============================================================
# Mixed cases
# ============================================================

@test "strips quotes and heredocs together, preserves surrounding content" {
  input=$'echo "a"; cat <<EOF\nbody\nEOF\necho \'b\''
  result=$(run_helper "$input")
  # After stripping: 'echo ; cat \necho '
  [ "$result" = $'echo ; cat \necho ' ]
}

@test "phrase outside any quotes survives stripping" {
  result=$(run_helper "gh pr create 'hidden'")
  [[ "$result" == *"gh pr create"* ]]
}

@test "phrase inside single quotes is removed" {
  result=$(run_helper "echo 'gh pr create'")
  [[ "$result" != *"gh pr create"* ]]
}

@test "phrase inside double quotes is removed" {
  result=$(run_helper 'echo "gh pr create"')
  [[ "$result" != *"gh pr create"* ]]
}

@test "phrase inside heredoc body is removed" {
  input=$'cat <<EOF\ngh pr create\nEOF'
  result=$(run_helper "$input")
  [[ "$result" != *"gh pr create"* ]]
}

# ============================================================
# Edge cases
# ============================================================

@test "handles empty input" {
  result=$(run_helper "")
  [ "$result" = "" ]
}

@test "handles unterminated single quote gracefully (leaves it alone)" {
  result=$(run_helper "echo 'unterminated")
  # Unterminated single quote doesn't match — content preserved
  [ "$result" = "echo 'unterminated" ]
}

@test "handles unterminated heredoc gracefully (leaves content alone)" {
  input=$'cat <<EOF\nnever closed'
  result=$(run_helper "$input")
  # No closing delimiter — body preserved
  [[ "$result" == *"never closed"* ]]
}
