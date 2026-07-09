#!/usr/bin/env python3
"""
Scan recent Claude Code session transcripts for tool misses.

Looks at Bash tool_use + tool_result pairs in JSONL session files and detects:
- Missing tools ("command not found" errors)
- BSD/GNU incompatibilities (macOS BSD tools failing with GNU-style flags)

Outputs JSON to stdout with missing_tools[], wrong_version_tools[], scan_summary{}.
"""

import json
import os
import re
import sys
import time
from collections import defaultdict
from pathlib import Path

# --- Configuration ---

SESSIONS_DIR = Path.home() / ".claude" / "projects"
IGNORE_FILE = Path.home() / ".claude" / "tool-misses-ignored.json"
DEFAULT_DAYS = 14

# Tools that are sandbox-blocked builtins (false positives for "command not found")
SANDBOX_BUILTINS = {
    "head", "cat", "ls", "tail", "sed", "awk", "echo", "find", "grep",
    "sort", "uniq", "wc", "tr", "cut", "tee", "xargs", "mv", "cp",
    "rm", "mkdir", "rmdir", "touch", "chmod", "chown", "ln",
    "printf", "read", "test",
}

# Commands to ignore — not installable via Homebrew, or the "missing" version is
# expected on macOS (e.g., `python` doesn't exist, use `python3` instead)
IGNORE_COMMANDS = {
    "python",   # macOS removed `python` in 12.3+; `python3` is the correct command
    "pytest",   # pip package, not a Homebrew formula
    "pip",      # pip package manager — comes with python3
}

# --- Missing tool → Homebrew formula mappings ---

TOOL_TO_FORMULA = {
    # Text processing
    "filterdiff": "patchutils",
    "combinediff": "patchutils",
    "lsdiff": "patchutils",
    "splitdiff": "patchutils",
    "interdiff": "patchutils",
    "colordiff": "colordiff",
    "diff-so-fancy": "diff-so-fancy",
    # Search & file tools
    "rg": "ripgrep",
    "fd": "fd",
    "ag": "the_silver_searcher",
    "fzf": "fzf",
    "tree": "tree",
    # JSON / YAML / data
    "jq": "jq",
    "yq": "yq",
    "csvkit": "csvkit",
    "xmlstarlet": "xmlstarlet",
    "htmlq": "htmlq",
    # Git tools
    "delta": "git-delta",
    "gh": "gh",
    "hub": "hub",
    "tig": "tig",
    "git-lfs": "git-lfs",
    # Programming languages & runtimes
    "python3": "python@3.12",
    "node": "node",
    "ruby": "ruby",
    "perl": "perl",
    "go": "go",
    "rustc": "rust",
    "cargo": "rust",
    # Build & dev tools
    "cmake": "cmake",
    "make": "make",
    "pkg-config": "pkg-config",
    "autoconf": "autoconf",
    "automake": "automake",
    # Network tools
    "wget": "wget",
    "curl": "curl",
    "httpie": "httpie",
    "nmap": "nmap",
    "netcat": "netcat",
    "nc": "netcat",
    # System tools
    "watch": "watch",
    "htop": "htop",
    "pstree": "pstree",
    "lsof": "lsof",
    "strace": "strace",
    # Shell tools
    "bash": "bash",
    "zsh": "zsh",
    "fish": "fish",
    "tmux": "tmux",
    "screen": "screen",
    # Compression
    "pigz": "pigz",
    "pbzip2": "pbzip2",
    "xz": "xz",
    "zstd": "zstd",
    # Misc
    "timeout": "coreutils",
    "gtimeout": "coreutils",
    "bat": "bat",
    "exa": "exa",
    "eza": "eza",
    "entr": "entr",
    "parallel": "parallel",
    "pv": "pv",
    "rename": "rename",
    "shellcheck": "shellcheck",
    "shfmt": "shfmt",
    "dos2unix": "dos2unix",
    "icdiff": "icdiff",
    "difftastic": "difftastic",
    "socat": "socat",
    "coreutils": "coreutils",
    "gnu-sed": "gnu-sed",
    "gawk": "gawk",
    "findutils": "findutils",
    "gnu-tar": "gnu-tar",
    "gnu-time": "gnu-time",
    "gnu-which": "gnu-which",
    "gnu-indent": "gnu-indent",
    "gnu-getopt": "gnu-getopt",
}

# --- BSD vs GNU incompatibility patterns ---
# Each entry: (error_regex, tool_name, formula, g_prefix, description)

WRONG_VERSION_PATTERNS = [
    # sed
    (
        r"sed: 1:.*: invalid command code",
        "sed", "gnu-sed", "gsed",
        "BSD sed doesn't support GNU sed syntax"
    ),
    (
        r"sed: 1:.*: extra characters at the end of .* command",
        "sed", "gnu-sed", "gsed",
        "BSD sed doesn't support GNU sed syntax"
    ),
    (
        r"sed: -[iI]: .*: No such file or directory",
        "sed", "gnu-sed", "gsed",
        "BSD sed -i requires an extension argument"
    ),
    # grep
    (
        r"grep: invalid option -- P",
        "grep", "grep", "ggrep",
        "BSD grep doesn't support -P (Perl regex)"
    ),
    (
        r"grep: invalid option -- 'P'",
        "grep", "grep", "ggrep",
        "BSD grep doesn't support -P (Perl regex)"
    ),
    # find
    (
        r"find: -printf: unknown primary",
        "find", "findutils", "gfind",
        "BSD find doesn't support -printf"
    ),
    (
        r"find: -regextype: unknown primary",
        "find", "findutils", "gfind",
        "BSD find doesn't support -regextype"
    ),
    # xargs
    (
        r"xargs: illegal option -- d",
        "xargs", "findutils", "gxargs",
        "BSD xargs doesn't support -d (delimiter)"
    ),
    (
        r"xargs: illegal option -- P",
        "xargs", "findutils", "gxargs",
        "BSD xargs doesn't support -P (parallel)"
    ),
    # date
    (
        r"date: illegal option -- d",
        "date", "coreutils", "gdate",
        "BSD date doesn't support -d (parse date string)"
    ),
    (
        r"date: illegal option -- -",
        "date", "coreutils", "gdate",
        "BSD date doesn't support GNU long options"
    ),
    # readlink
    (
        r"readlink: illegal option -- f",
        "readlink", "coreutils", "greadlink",
        "BSD readlink doesn't support -f (canonicalize)"
    ),
    # stat
    (
        r"stat: illegal option -- -",
        "stat", "coreutils", "gstat",
        "BSD stat uses different syntax than GNU stat"
    ),
    (
        r"stat: unrecognized option",
        "stat", "coreutils", "gstat",
        "BSD stat uses different syntax than GNU stat"
    ),
    # awk
    (
        r"awk: .*function .* is not defined",
        "awk", "gawk", "gawk",
        "BSD awk lacks some GNU awk functions"
    ),
    (
        r"awk: .*: unknown option",
        "awk", "gawk", "gawk",
        "BSD awk doesn't support some GNU awk options"
    ),
    # tar
    (
        r"tar: Option --\w+ is not supported",
        "tar", "gnu-tar", "gtar",
        "BSD tar doesn't support some GNU tar options"
    ),
    # sort
    (
        r"sort: invalid option -- V",
        "sort", "coreutils", "gsort",
        "BSD sort doesn't support -V (version sort)"
    ),
    # head/tail
    (
        r"head: illegal line count -- -",
        "head", "coreutils", "ghead",
        "BSD head uses different syntax for negative counts"
    ),
    (
        r"tail: illegal offset -- \+",
        "tail", "coreutils", "gtail",
        "BSD tail uses different syntax"
    ),
]

# Compile regexes once
COMPILED_WRONG_VERSION = [
    (re.compile(pattern, re.IGNORECASE), tool, formula, gprefix, desc)
    for pattern, tool, formula, gprefix, desc in WRONG_VERSION_PATTERNS
]

# "command not found" patterns
# Note: we intentionally omit "No such file or directory" — it fires on file paths, not missing commands
# Two distinct error formats:
#   bash/sh: "<shell>: <name>: command not found"  → name is between the colons
#   zsh:     "zsh: command not found: <name>"       → name is after the second colon
# The negative lookahead (?!:) on pattern 1 stops it from greedily capturing the
# shell name on a zsh-style line (which would otherwise yield "zsh" as the missing tool).
MISSING_CMD_PATTERNS = [
    re.compile(r"(?:bash: |sh: )?(\S+): command not found(?!:)"),
    re.compile(r"command not found: (\S+)"),
]


def load_ignored_tools() -> set[str]:
    """Load the persistent ignore list from ~/.claude/tool-misses-ignored.json."""
    if not IGNORE_FILE.exists():
        return set()
    try:
        with open(IGNORE_FILE) as f:
            data = json.load(f)
        return set(data.get("ignored", []))
    except (json.JSONDecodeError, OSError):
        return set()


def find_session_files(days: int = DEFAULT_DAYS) -> list[Path]:
    """Find JSONL session files modified within the last N days."""
    if not SESSIONS_DIR.exists():
        return []

    cutoff = time.time() - (days * 86400)
    files = []

    for jsonl_file in SESSIONS_DIR.rglob("*.jsonl"):
        try:
            if jsonl_file.stat().st_mtime >= cutoff:
                files.append(jsonl_file)
        except OSError:
            continue

    return sorted(files, key=lambda f: f.stat().st_mtime, reverse=True)


def extract_bash_pairs(session_file: Path) -> list[dict]:
    """
    Extract Bash tool_use + tool_result pairs from a JSONL session file.

    JSONL format:
    - Assistant messages (type="assistant") contain tool_use blocks in message.content[]
    - Tool results come in user messages (type="user") as tool_result blocks in message.content[]
      with a tool_use_id linking back to the original tool_use

    Returns list of dicts with keys: command, output, tool_use_id, file
    """
    pairs = []
    tool_uses = {}  # tool_use_id -> command

    try:
        with open(session_file, "r", encoding="utf-8", errors="replace") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    record = json.loads(line)
                except json.JSONDecodeError:
                    continue

                record_type = record.get("type", "")
                message = record.get("message", {})
                if not isinstance(message, dict):
                    continue
                content_list = message.get("content", [])
                if not isinstance(content_list, list):
                    continue

                for block in content_list:
                    if not isinstance(block, dict):
                        continue

                    # Collect Bash tool_use from assistant messages
                    if (
                        record_type == "assistant"
                        and block.get("type") == "tool_use"
                        and block.get("name") == "Bash"
                    ):
                        tool_id = block.get("id", "")
                        command = block.get("input", {}).get("command", "")
                        if tool_id and command:
                            tool_uses[tool_id] = command

                    # Collect tool_result from user messages
                    elif (
                        record_type == "user"
                        and block.get("type") == "tool_result"
                    ):
                        tool_id = block.get("tool_use_id", "")
                        if tool_id not in tool_uses:
                            continue

                        content = block.get("content", "")
                        if isinstance(content, list):
                            text_parts = []
                            for sub in content:
                                if isinstance(sub, dict) and sub.get("type") == "text":
                                    text_parts.append(sub.get("text", ""))
                                elif isinstance(sub, str):
                                    text_parts.append(sub)
                            content = "\n".join(text_parts)
                        elif not isinstance(content, str):
                            content = str(content)

                        pairs.append({
                            "command": tool_uses[tool_id],
                            "output": content,
                            "tool_use_id": tool_id,
                            "file": str(session_file),
                        })
                        del tool_uses[tool_id]

    except (OSError, PermissionError) as e:
        print(f"Warning: Could not read {session_file}: {e}", file=sys.stderr)

    return pairs


def is_false_positive_missing(cmd: str) -> bool:
    """Check if a 'command not found' match is a false positive."""
    # File paths
    if cmd.startswith("/") or cmd.startswith("./") or cmd.startswith("../"):
        return True
    # Sandbox-blocked builtins that Claude shouldn't try to install
    if cmd.lower() in SANDBOX_BUILTINS:
        return True
    # Commands that aren't installable via Homebrew or are expected-missing on macOS
    if cmd.lower() in IGNORE_COMMANDS:
        return True
    # Very short or obviously not a command
    if len(cmd) <= 1 or " " in cmd:
        return True
    # Contains path separators (it's a path, not a command)
    if "/" in cmd:
        return True
    # Starts with a flag
    if cmd.startswith("-"):
        return True
    # Starts with a dot (hidden files, .nvmrc, etc.)
    if cmd.startswith("."):
        return True
    # Contains backslash-escaped characters (from embedded JSON in output)
    if "\\" in cmd:
        return True
    # Contains quotes or commas (from parsing artifacts)
    if any(ch in cmd for ch in ('"', "'", ",", ";", "(", ")", "{", "}", "[", "]")):
        return True
    # Contains colons (e.g., "hackathon_init:7" — shell function errors)
    if ":" in cmd:
        return True
    # ALL_CAPS placeholder words (e.g., PATTERN, COMMAND, TOOL from embedded text)
    if cmd.isupper() and len(cmd) > 2:
        return True
    # Must look like a valid command name: letters, numbers, hyphens, underscores
    if not re.match(r'^[a-zA-Z_][a-zA-Z0-9._-]*$', cmd):
        return True
    return False


def detect_missing_tools(pairs: list[dict]) -> dict:
    """Detect missing tool errors from Bash tool_use/tool_result pairs."""
    missing = defaultdict(lambda: {"count": 0, "examples": [], "formula": None})

    for pair in pairs:
        output = pair["output"]
        for pattern in MISSING_CMD_PATTERNS:
            for match in pattern.finditer(output):
                cmd = match.group(1).strip()
                if is_false_positive_missing(cmd):
                    continue

                missing[cmd]["count"] += 1
                if len(missing[cmd]["examples"]) < 3:
                    missing[cmd]["examples"].append({
                        "command": pair["command"][:200],
                        "error": match.group(0)[:200],
                        "file": pair["file"],
                    })
                if cmd in TOOL_TO_FORMULA:
                    missing[cmd]["formula"] = TOOL_TO_FORMULA[cmd]

    return dict(missing)


def detect_wrong_version(pairs: list[dict]) -> dict:
    """Detect BSD/GNU incompatibility errors from Bash tool_use/tool_result pairs."""
    wrong = defaultdict(lambda: {
        "count": 0, "examples": [], "formula": None,
        "g_prefix": None, "description": None,
    })

    for pair in pairs:
        output = pair["output"]
        for compiled_re, tool, formula, gprefix, desc in COMPILED_WRONG_VERSION:
            if compiled_re.search(output):
                wrong[tool]["count"] += 1
                wrong[tool]["formula"] = formula
                wrong[tool]["g_prefix"] = gprefix
                wrong[tool]["description"] = desc
                if len(wrong[tool]["examples"]) < 3:
                    wrong[tool]["examples"].append({
                        "command": pair["command"][:200],
                        "error_match": compiled_re.pattern,
                        "file": pair["file"],
                    })

    return dict(wrong)


def main():
    days = DEFAULT_DAYS
    if len(sys.argv) > 1:
        try:
            days = int(sys.argv[1])
        except ValueError:
            print(f"Usage: {sys.argv[0]} [days]", file=sys.stderr)
            sys.exit(1)

    session_files = find_session_files(days)

    if not session_files:
        result = {
            "missing_tools": {},
            "wrong_version_tools": {},
            "scan_summary": {
                "files_scanned": 0,
                "pairs_analyzed": 0,
                "days_scanned": days,
                "error": "No session files found in ~/.claude/projects/",
            },
        }
        json.dump(result, sys.stdout, indent=2)
        return

    all_pairs = []
    for sf in session_files:
        all_pairs.extend(extract_bash_pairs(sf))

    missing = detect_missing_tools(all_pairs)
    wrong_version = detect_wrong_version(all_pairs)

    # Filter out user-dismissed tools
    ignored = load_ignored_tools()
    ignored_found = {k: missing.pop(k) for k in list(missing) if k in ignored}
    ignored_found.update({k: wrong_version.pop(k) for k in list(wrong_version) if k in ignored})

    result = {
        "missing_tools": missing,
        "wrong_version_tools": wrong_version,
        "ignored_tools": list(ignored_found.keys()),
        "ignore_file": str(IGNORE_FILE),
        "scan_summary": {
            "files_scanned": len(session_files),
            "pairs_analyzed": len(all_pairs),
            "days_scanned": days,
            "total_missing": len(missing),
            "total_wrong_version": len(wrong_version),
            "total_ignored": len(ignored_found),
        },
    }

    json.dump(result, sys.stdout, indent=2)


if __name__ == "__main__":
    main()
