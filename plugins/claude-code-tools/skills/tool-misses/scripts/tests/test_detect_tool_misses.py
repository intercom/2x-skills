"""Unit tests for scripts/detect-tool-misses.py.

Run with: uv run --with pytest pytest plugins/developer-tools/skills/tool-misses/scripts/tests/ -x -q
"""

import importlib.util
from pathlib import Path

SCRIPT = Path(__file__).parent.parent.resolve() / "detect-tool-misses.py"


def _load():
    spec = importlib.util.spec_from_file_location("detect_tool_misses", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


detector = _load()


def _pair(output: str, command: str = "mytool --help") -> dict:
    return {
        "command": command,
        "output": output,
        "tool_use_id": "abc",
        "file": "/fake.jsonl",
    }


class TestMissingCommandExtraction:
    def test_zsh_suffix_format_does_not_capture_shell_name(self):
        # zsh's actual error format puts the missing command AFTER the colon:
        #   "zsh: command not found: mytool"
        # A naive regex anchored on "<word>: command not found" greedily captures
        # "zsh" itself. This is the regression we are guarding against.
        result = detector.detect_missing_tools(
            [_pair("zsh: command not found: mytool")]
        )
        assert "zsh" not in result
        assert "mytool" in result

    def test_bash_prefix_format_captures_target_command(self):
        # bash format: "<shell>: <name>: command not found" — name is mid-string.
        result = detector.detect_missing_tools(
            [_pair("bash: mytool: command not found")]
        )
        assert "bash" not in result
        assert "mytool" in result

    def test_sh_prefix_format_captures_target_command(self):
        # sh format matches bash format. Common in bundle exec / non-login shells.
        result = detector.detect_missing_tools(
            [_pair("sh: mytool: command not found")]
        )
        assert "sh" not in result
        assert "mytool" in result

    def test_bare_format_captures_target_command(self):
        # No shell prefix at all — direct error message.
        result = detector.detect_missing_tools([_pair("mytool: command not found")])
        assert "mytool" in result
