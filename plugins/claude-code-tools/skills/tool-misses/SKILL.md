---
name: tool-misses
description: >
  Scan recent Claude Code sessions for "command not found" errors and BSD/GNU
  incompatibilities on macOS, fix them via Homebrew, and record availability in
  CLAUDE.md; runs only when the user invokes /tool-misses (scan | on | off | status).
disable-model-invocation: true
metadata:
  keywords:
    - gsed
    - ggrep
    - gnu-sed
  user-invocable: true
allowed-tools: Bash Read Edit Write AskUserQuestion
---

# Tool Misses

Scan recent Claude Code sessions for tool failures — missing commands and BSD/GNU
incompatibilities — then fix them with Homebrew and record availability in CLAUDE.md.

## Response Style

Skip narration and transitional commentary. Run each step, then present the findings
or ask the user directly. Do not preface tool calls with sentences like "Now I'll run
the scanner" or "Let me check whether Homebrew is installed", and do not paraphrase
script output the user can already see — show the tables and the questions, nothing else.

## Workflow

### Step 0: Handle enable/disable arguments

This skill accepts an optional argument that controls its companion PostToolUse
hook (`suggest-tool-misses.sh`), which nudges the user toward this skill when a
tool failure is detected in Bash output. The hook reads a persistent marker file
at `~/.claude/.disable-tool-misses-hook` and stays silent whenever it exists.

Dispatch on the argument before doing anything else:

- `off`, `disable`, `stop`, `mute`, or `silence` → silence the hook:
  ```bash
  touch ~/.claude/.disable-tool-misses-hook
  ```
  Confirm suggestions are off until re-enabled with `/tool-misses on`, then STOP
  (do not run a scan).
- `on`, `enable`, `start`, or `unmute` → re-enable the hook:
  ```bash
  rm -f ~/.claude/.disable-tool-misses-hook
  ```
  Confirm suggestions are back on, then STOP (do not run a scan).
- `status` → report whether the hook is on or off:
  ```bash
  test -f ~/.claude/.disable-tool-misses-hook && echo "off" || echo "on"
  ```
  Report the result, then STOP.
- No argument, `scan`, or anything else → proceed to Step 1.

### Step 1: Detect tool misses

Run the scanner script against recent session transcripts:

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/skills/tool-misses/scripts/detect-tool-misses.py
```

This scans `~/.claude/projects/*/*.jsonl` files from the last 14 days. It looks at
Bash `tool_use` + `tool_result` pairs and matches error output against two pattern sets:

- **Missing tools**: `command not found` errors
- **Wrong version / incompatibility**: BSD vs GNU errors (e.g., `grep -P` failing,
  `sed -i` syntax differences, `find -printf` not supported)

Output is JSON with `missing_tools[]`, `wrong_version_tools[]`, and `scan_summary{}`.

If the script finds no misses, report that and stop.

### Step 2: Check current state

For each detected tool, check whether it has already been resolved:

```bash
command -v <tool>        # Is it installed now?
command -v g<tool>       # Is the GNU version available?
brew --prefix 2>/dev/null # Is Homebrew installed?
```

Categorize each tool as: still missing, now installed but not in CLAUDE.md, or fully resolved.

### Step 3: Look up fixes

Consult `references/tool-database.md` for each detected tool to find:
- The correct Homebrew formula
- The g-prefix command name (for GNU tools)
- Guidance text for CLAUDE.md

For tools not in the database, note them as "unknown — manual resolution needed".

### Step 4: Present report

Show the findings in tables grouped by status:

```
## Missing Tools (not currently installed)
| Tool | Error | Homebrew Formula | Occurrences |
|------|-------|------------------|-------------|
| filterdiff | command not found | patchutils | 3 |

## BSD/GNU Incompatibilities
| Tool | Error Pattern | Fix | g-prefix |
|------|---------------|-----|----------|
| grep | invalid option -- P | brew install grep | ggrep |

## Already Resolved (installed since the error)
| Tool | Status |
|------|--------|
| jq   | Now installed |

## GNU Tools Available but Not in CLAUDE.md
| Tool | g-prefix | Formula |
|------|----------|---------|
| gsed | gsed     | gnu-sed |
```

Only show sections that have entries. If everything is resolved, say so and skip to Step 8.

If the scanner output includes `ignored_tools`, mention how many were skipped:
```
(3 previously dismissed tools hidden — edit ~/.claude/tool-misses-ignored.json to reset)
```

### Step 5: Prompt for action — per tool

Present each detected tool individually for the user to decide. For each tool,
use AskUserQuestion with these options:

- **Install + add to CLAUDE.md** (Recommended) — Install via Homebrew and record in CLAUDE.md
- **Install only** — Install but don't modify CLAUDE.md
- **CLAUDE.md only** — Already installed, just add the CLAUDE.md entry
- **Dismiss permanently** — Not needed; hide from future scans

If a tool has no known Homebrew formula, adjust options to only show "Dismiss permanently"
and "Skip for now".

**Dismiss behavior:** When the user dismisses a tool, add it to `~/.claude/tool-misses-ignored.json`:

```json
{
  "ignored": ["qmd", "init_common"],
  "notes": {
    "qmd": "Dismissed 2026-02-08 — short-term experiment",
    "init_common": "Dismissed 2026-02-08 — shell function, not a tool"
  }
}
```

Read the file first (or start with empty `{"ignored":[], "notes":{}}`) and merge.
The scanner automatically filters out tools in this list on future runs.

### Step 6: Install tools

For each tool the user approved for installation:

```bash
brew install <formula>
```

After each install, verify it worked:

```bash
command -v <tool> && echo "OK" || echo "FAILED"
```

If a GNU tool was installed, also verify the g-prefix command:

```bash
command -v g<tool> && echo "OK" || echo "FAILED"
```

Report any install failures and continue with the rest.

### Step 7: Update CLAUDE.md

Add a `## Tool Availability (macOS)` section to `~/.claude/CLAUDE.md` (global config,
since these are system-wide tools). Follow these rules:

- Consult `references/claude-md-templates.md` for entry format
- Show proposed additions before writing — never write without confirmation
- Don't duplicate entries that already exist in CLAUDE.md
- If the section already exists, append new entries to it
- If the file doesn't exist, create it with just the tool availability section

Read the current file first:

```bash
cat ~/.claude/CLAUDE.md 2>/dev/null || echo ""
```

Show the proposed changes as a diff-style preview before applying.

### Step 8: Summarize

Show a final summary:

```
## Summary

Installed: filterdiff (patchutils), rg (ripgrep)
CLAUDE.md: Added 3 entries to ~/.claude/CLAUDE.md
  - GNU grep available as ggrep
  - GNU sed available as gsed
  - filterdiff available (patchutils)

Dismissed: qmd, init_common (won't appear in future scans)
No action needed: jq (already installed and in CLAUDE.md)
```

## Error Handling

**No session files found:**
- Check if `~/.claude/projects/` exists
- Suggest the user has a new install or cleared history
- Offer to scan a custom path

**Homebrew not installed:**
- Warn that brew is required for installation
- Still offer to update CLAUDE.md with manual install instructions
- Provide the Homebrew install command: `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`

**Script errors:**
- If the Python script fails, show the error and suggest running it manually
- Fall back to a simpler scan if needed

## Additional Resources

- `references/tool-database.md` — Complete error pattern → Homebrew formula mappings
- `references/claude-md-templates.md` — Templates for CLAUDE.md entries
- `scripts/detect-tool-misses.py` — Session scanner script
