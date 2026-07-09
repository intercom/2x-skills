#!/usr/bin/env python3
"""Strip single-quoted, double-quoted, and heredoc-delimited content from
a shell command read on stdin, writing the stripped result to stdout.

Pragmatic — not a full bash parser. Intended for hooks that want to check
whether a specific command phrase appears as a real invocation rather than
as text inside a quoted flag value or heredoc body.

Handled forms:
- Single-quoted segments: '...'            (no escape handling — sh semantics)
- Double-quoted segments: "..."            (\\" treated as escaped quote)
- Heredocs: <<WORD, <<-WORD, <<'WORD', <<"WORD"  terminated by WORD on its own line
"""
import re
import sys


HEREDOC_OPEN = re.compile(
    r"<<-?\s*(?P<q>['\"]?)(?P<delim>[A-Za-z_][A-Za-z0-9_]*)(?P=q)"
)


def strip_heredocs(text: str) -> str:
    out: list[str] = []
    pos = 0
    while pos < len(text):
        m = HEREDOC_OPEN.search(text, pos)
        if not m:
            out.append(text[pos:])
            break
        out.append(text[pos:m.start()])
        delim = m.group("delim")
        after = text[m.end():]
        nl = after.find("\n")
        if nl < 0:
            pos = m.end()
            continue
        rest = after[nl + 1:]
        close = re.search(r"(?m)^[ \t]*" + re.escape(delim) + r"[ \t]*$", rest)
        if not close:
            pos = m.end()
            continue
        pos = m.end() + nl + 1 + close.end()
    return "".join(out)


def strip(text: str) -> str:
    text = strip_heredocs(text)
    text = re.sub(r'"(?:[^"\\]|\\.)*"', "", text)
    text = re.sub(r"'[^']*'", "", text)
    return text


def main() -> None:
    sys.stdout.write(strip(sys.stdin.read()))


if __name__ == "__main__":
    main()
