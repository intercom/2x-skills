#!/usr/bin/env python3
"""Check whether a skill is still active on the CURRENT branch of a transcript.

Claude Code transcripts are an append-only DAG: every event carries a ``uuid``
and ``parentUuid``. A ``/rewind`` (or an edited/retried turn) starts a new branch
from an earlier node — the abandoned branch's events physically REMAIN in the
.jsonl file. ``/rewind`` fires no hook, so the skill-activation marker written by
track-skill-activation.sh is never cleared when the user rewinds past a skill load.

This helper lets intercept-gh-pr-create.sh re-validate a marker: a skill counts as
active only if its activation sits in the ancestry of the current (latest)
main-conversation leaf. A load that was rewound away lives on an abandoned branch
and is therefore NOT an ancestor, so the guard can correctly re-engage.

A skill can be activated two ways, both of which write the same marker:
  * the ``Skill`` tool (PreToolUse:Skill -> track-skill-activation.sh) — appears as
    an assistant ``tool_use`` block named "Skill";
  * a ``/skill`` slash command (UserPromptSubmit -> track-skill-slash-command.sh) —
    expanded inline, so it appears as a user message whose text begins with the raw
    slash command (e.g. ``/create-pr`` or ``/pr-tools:create-pr``) or carries
    a synthesized ``<command-name>`` tag. Both forms are recognised here.

Matching these structured signals (not a bare substring) avoids the false positives
that originally motivated replacing transcript grepping with markers.

SAFETY: this helper must FAIL OPEN. It returns 1 ("block") only on a confident,
fully-parsed "absent" determination. Any ambiguity — unreadable/undecodable file,
any line that failed to parse, a dangling parent chain, or an unexpected error —
returns 2 so the caller honours the marker. An uncaught exception would exit 1 and
be misread as "absent", so everything runs under a guard that converts errors to 2.

Usage:  skill-active-in-transcript.py <transcript_path> <skill_name>

Exit codes (consumed by the caller, which fails OPEN on anything but 1):
  0  skill IS active in the current branch  -> allow
  1  skill is POSITIVELY absent (rewound away) -> let the caller block
  2  undetermined (missing/empty/unreadable/parse error/ambiguous) -> caller fails open
"""
import re
import sys

UNDETERMINED = 2

# Matches the raw slash-command form at the start of a prompt, mirroring
# base/hooks/track-skill-slash-command.sh (which writes the marker).
_SLASH_RE = re.compile(r"^\s*/([A-Za-z0-9_:.-]+)")
# Matches a synthesized <command-name>/skill</command-name> tag anywhere.
_CMD_NAME_RE = re.compile(r"<command-name>\s*/?([A-Za-z0-9_:.-]+)")


def _skill_component(value):
    """Normalise 'pr-tools:create-pr' / 'create-pr' -> 'create-pr'."""
    if not isinstance(value, str):
        return None
    return value.split(":")[-1].strip()


def _text_of(content):
    """Best-effort plain text for a message's content (string or block list)."""
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts = []
        for block in content:
            if isinstance(block, dict) and isinstance(block.get("text"), str):
                parts.append(block["text"])
        return "\n".join(parts)
    return ""


def _is_skill_tool_load(entry, skill_name):
    """True if entry is a main-conversation assistant Skill tool_use for skill_name."""
    if entry.get("isSidechain") is True or entry.get("isVisibleInTranscriptOnly") is True:
        return False
    msg = entry.get("message")
    if not isinstance(msg, dict):
        return False
    content = msg.get("content")
    if not isinstance(content, list):
        return False
    for block in content:
        if not isinstance(block, dict):
            continue
        if block.get("type") != "tool_use" or block.get("name") != "Skill":
            continue
        tool_input = block.get("input")
        if not isinstance(tool_input, dict):
            continue  # wrong-shaped input: ignore this block, never crash
        for key in ("command", "skill", "skill_name"):
            if _skill_component(tool_input.get(key)) == skill_name:
                return True
    return False


def _is_slash_load(entry, skill_name):
    """True if entry is a user message that activated skill_name via slash command.

    Claude Code stores a slash invocation as a synthesized command block — the
    message text begins with <command-name> / <command-message> tags (verified
    against real transcripts). We only trust a <command-name> tag when the message
    actually IS such a block (text starts with the tag), so user-authored prose
    that merely quotes `<command-name>/create-pr</command-name>` cannot spoof an
    activation and bypass the guard. The raw `/skill` form is also accepted, but
    only anchored at the very start of the message.

    KNOWN LIMITATION: Claude Code stores no field distinguishing a synthesized
    slash block from user-typed text, so a user who already holds a stale marker
    could in principle bypass the guard by sending a message that begins with a
    literal `<command-name>/create-pr</command-name>`. This is accepted: the guard
    is a workflow nudge, not a boundary against the operator themselves (who can
    disable the hook or call `gh api` directly), and recognising genuine slash
    activations avoids false-blocking the common `/create-pr` path — a strictly
    better trade than refusing to honour slash loads at all."""
    if entry.get("isSidechain") is True or entry.get("isVisibleInTranscriptOnly") is True:
        return False
    if entry.get("type") != "user":
        return False
    msg = entry.get("message")
    text = _text_of(msg.get("content")) if isinstance(msg, dict) else ""
    if not text:
        return False

    # Raw form: the message is exactly the slash command (anchored at start).
    m = _SLASH_RE.match(text)
    if m and _skill_component(m.group(1)) == skill_name:
        return True

    # Synthesized form: only trust it when the message is genuinely a command
    # block, i.e. it opens with the command tags rather than merely mentioning one.
    stripped = text.lstrip()
    if stripped.startswith("<command-name>") or stripped.startswith("<command-message>"):
        for name in _CMD_NAME_RE.findall(text):
            if _skill_component(name) == skill_name:
                return True
    return False


def _evaluate(path, skill_name):
    try:
        # errors="replace" so undecodable bytes never raise (fail-open intent).
        with open(path, "r", errors="replace") as fh:
            raw_lines = fh.read().splitlines()
    except OSError:
        return UNDETERMINED

    import json  # local import keeps a stray import error inside the guard

    parent_of = {}          # uuid -> parentUuid
    load_uuids = set()      # uuids that activated skill_name (tool or slash)
    last_main_uuid = None   # latest main-conversation leaf (file order)
    parse_failures = 0

    for line in raw_lines:
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
        except (ValueError, TypeError):
            parse_failures += 1
            continue
        if not isinstance(entry, dict):
            parse_failures += 1
            continue
        uuid = entry.get("uuid")
        if not uuid:
            # A conversation message with no uuid is anomalous — bias to ambiguity
            # rather than silently dropping it from the DAG.
            if entry.get("type") in ("user", "assistant"):
                parse_failures += 1
            continue
        # Keep every uuid-bearing record in the parent map so the ancestry chain
        # stays connected through interleaved attachment/system nodes...
        parent_of[uuid] = entry.get("parentUuid")
        # ...but only a real, user-visible conversation message may anchor the
        # walk. Transcripts end on trailing records (attachment/system/snapshot)
        # that carry uuids, and transcript-only nodes aren't on the live branch;
        # starting the walk from any of those could miss an active ancestor.
        if (
            entry.get("type") in ("user", "assistant")
            and entry.get("isSidechain") is not True
            and entry.get("isVisibleInTranscriptOnly") is not True
        ):
            last_main_uuid = uuid
        if _is_skill_tool_load(entry, skill_name) or _is_slash_load(entry, skill_name):
            load_uuids.add(uuid)

    if not parent_of or last_main_uuid is None:
        return UNDETERMINED  # nothing usable -> caller falls back to prior behaviour

    # Walk parentUuid from the current leaf to the root, collecting ancestors.
    ancestors = set()
    cursor = last_main_uuid
    dangling = False
    cyclic = False
    while cursor is not None:
        if cursor in ancestors:
            cyclic = True  # parent loop -> malformed/ambiguous, not a clean root
            break
        if cursor not in parent_of:
            # Chain references a node we never parsed -> transcript is incomplete.
            dangling = True
            break
        ancestors.add(cursor)
        cursor = parent_of[cursor]

    if load_uuids & ancestors:
        return 0  # active on the current branch

    # Not found among ancestors. Only re-block if we are confident the transcript
    # was complete, fully parsed, and acyclic; any ambiguity stays undetermined
    # (fail open) per the safety contract.
    if dangling or cyclic or parse_failures:
        return UNDETERMINED
    return 1


def main():
    if len(sys.argv) < 3:
        return UNDETERMINED
    try:
        return _evaluate(sys.argv[1], sys.argv[2])
    except Exception:
        # Never let an unexpected error become exit 1 (which the caller reads as
        # "skill absent" and would wrongly block). Any crash fails open.
        return UNDETERMINED


if __name__ == "__main__":
    sys.exit(main())
