# CLAUDE.md Templates

Templates for adding tool availability entries to CLAUDE.md files.

## Section Header

```markdown
## Tool Availability (macOS)
```

This section should be placed at the end of the CLAUDE.md file, after any existing
project-specific guidance.

## Entry Templates

### GNU tool (BSD replacement)

```markdown
- GNU {tool} is available as `g{tool}` (`brew install {formula}`). Use `g{tool}` instead of `{tool}` when you need {specific_capability}.
```

**Examples:**

```markdown
- GNU sed is available as `gsed` (`brew install gnu-sed`). Use `gsed` instead of `sed` for in-place editing (`-i`) and extended regex.
- GNU grep is available as `ggrep` (`brew install grep`). Use `ggrep -P` for Perl-compatible regex; BSD grep only supports `-E` (extended).
- GNU find is available as `gfind` (`brew install findutils`). Use `gfind` when you need `-printf` or `-regextype`.
- GNU xargs is available as `gxargs` (`brew install findutils`). Use `gxargs` when you need `-d` (delimiter) or `-P` (parallel).
- GNU date is available as `gdate` (`brew install coreutils`). Use `gdate -d` to parse date strings; BSD date uses `-j -f` instead.
- GNU readlink is available as `greadlink` (`brew install coreutils`). Use `greadlink -f` for canonical paths; BSD readlink doesn't support `-f`.
- GNU stat is available as `gstat` (`brew install coreutils`). Use `gstat --format` for GNU-style format strings; BSD stat uses `-f`.
- GNU awk is available as `gawk` (`brew install gawk`). Use `gawk` for GNU-specific functions like `mktime` and `strftime`.
- GNU tar is available as `gtar` (`brew install gnu-tar`). Use `gtar` for GNU-specific options.
- GNU sort is available as `gsort` (`brew install coreutils`). Use `gsort -V` for version sorting.
```

### Missing tool (newly installed)

```markdown
- `{command}` is available (`brew install {formula}`). {brief_usage_note}.
```

**Examples:**

```markdown
- `filterdiff` is available (`brew install patchutils`). Use for extracting specific files from patch output.
- `rg` (ripgrep) is available (`brew install ripgrep`). Fast regex search across files.
- `jq` is available (`brew install jq`). Use for JSON processing in shell commands.
- `delta` is available (`brew install git-delta`). Enhanced diff viewer for git.
- `fd` is available (`brew install fd`). Fast file finder, alternative to `find`.
- `bat` is available (`brew install bat`). Cat with syntax highlighting and line numbers.
- `perl` is available (`brew install perl`). Use for one-liners requiring Perl regex features.
- `wget` is available (`brew install wget`). Use for HTTP downloads when curl syntax is cumbersome.
- `tree` is available (`brew install tree`). Use for directory tree visualization.
- `watch` is available (`brew install watch`). Use for running commands periodically.
- `shellcheck` is available (`brew install shellcheck`). Shell script linter.
```

### Python special case

```markdown
- Use `python3` explicitly — `python` is not available on macOS by default. If both are needed: `brew install python@3.12`.
```

## Placement Rules

### System-wide tools → `~/.claude/CLAUDE.md`

Tools installed via Homebrew are system-wide, so their availability should be
recorded in the global CLAUDE.md:

```
~/.claude/CLAUDE.md
```

This ensures every Claude Code session knows about available tools, regardless
of which project directory it's running in.

### Project-specific tools → `./CLAUDE.md`

If a tool is only relevant to a specific project (e.g., a project-specific linter
or build tool), add it to the project's local CLAUDE.md instead:

```
./CLAUDE.md           # project root
./.claude/CLAUDE.md   # project claude config
```

## Deduplication Rules

Before adding any entry:

1. Read the existing CLAUDE.md file
2. Check if the tool name is already mentioned (case-insensitive search)
3. If found, skip that entry — don't duplicate
4. If the existing entry is outdated (wrong formula, missing g-prefix), update it

## Full Section Example

```markdown
## Tool Availability (macOS)

- GNU sed is available as `gsed` (`brew install gnu-sed`). Use `gsed` instead of `sed` for in-place editing (`-i`) and extended regex.
- GNU grep is available as `ggrep` (`brew install grep`). Use `ggrep -P` for Perl-compatible regex; BSD grep only supports `-E` (extended).
- GNU find is available as `gfind` (`brew install findutils`). Use `gfind` when you need `-printf` or `-regextype`.
- `filterdiff` is available (`brew install patchutils`). Use for extracting specific files from patch output.
- `jq` is available (`brew install jq`). Use for JSON processing in shell commands.
- Use `python3` explicitly — `python` is not available on macOS by default.
```
