# Tool Database

Complete reference of error patterns, Homebrew formulae, and fix guidance for
the `tool-misses` skill.

## Missing Tool → Homebrew Formula Mappings

### Text Processing

| Command | Formula | Description |
|---------|---------|-------------|
| `filterdiff` | `patchutils` | Extract diffs from patch files |
| `combinediff` | `patchutils` | Combine two incremental patches |
| `lsdiff` | `patchutils` | List files in a patch |
| `splitdiff` | `patchutils` | Split a patch by file |
| `interdiff` | `patchutils` | Diff between two patches |
| `colordiff` | `colordiff` | Colorized diff output |
| `diff-so-fancy` | `diff-so-fancy` | Better-looking git diffs |

### Search & File Tools

| Command | Formula | Description |
|---------|---------|-------------|
| `rg` | `ripgrep` | Fast regex search (replacement for grep -r) |
| `fd` | `fd` | Fast file finder (replacement for find) |
| `ag` | `the_silver_searcher` | Code search (The Silver Searcher) |
| `fzf` | `fzf` | Fuzzy finder |
| `tree` | `tree` | Directory tree listing |

### JSON / YAML / Data

| Command | Formula | Description |
|---------|---------|-------------|
| `jq` | `jq` | JSON processor |
| `yq` | `yq` | YAML processor |
| `csvkit` | `csvkit` | CSV toolkit |
| `xmlstarlet` | `xmlstarlet` | XML toolkit |
| `htmlq` | `htmlq` | HTML selector (like jq for HTML) |

### Git Tools

| Command | Formula | Description |
|---------|---------|-------------|
| `delta` | `git-delta` | Better git diff viewer |
| `gh` | `gh` | GitHub CLI |
| `hub` | `hub` | GitHub wrapper for git |
| `tig` | `tig` | Text-mode interface for git |
| `git-lfs` | `git-lfs` | Git Large File Storage |

### Programming Languages & Runtimes

| Command | Formula | Notes |
|---------|---------|-------|
| `python` | — | **Ignored.** macOS removed `python` in 12.3+. Use `python3`. |
| `python3` | `python@3.12` | Usually already present via Xcode CLT |
| `pytest` | — | **Ignored.** Install via `pip3 install pytest`, not Homebrew. |
| `node` | `node` | Node.js runtime |
| `ruby` | `ruby` | Ruby runtime |
| `perl` | `perl` | Perl runtime |
| `go` | `go` | Go language |
| `rustc` | `rust` | Rust compiler |
| `cargo` | `rust` | Rust package manager |

### Build & Dev Tools

| Command | Formula | Description |
|---------|---------|-------------|
| `cmake` | `cmake` | Cross-platform build system |
| `make` | `make` | GNU Make |
| `pkg-config` | `pkg-config` | Library compile/link flags |
| `autoconf` | `autoconf` | Autotools configure generator |
| `automake` | `automake` | Autotools Makefile generator |

### Network Tools

| Command | Formula | Description |
|---------|---------|-------------|
| `wget` | `wget` | HTTP/FTP downloader |
| `curl` | `curl` | URL transfer tool |
| `httpie` | `httpie` | User-friendly HTTP client |
| `nmap` | `nmap` | Network scanner |
| `netcat` / `nc` | `netcat` | TCP/UDP networking utility |

### System Tools

| Command | Formula | Description |
|---------|---------|-------------|
| `watch` | `watch` | Run command periodically |
| `htop` | `htop` | Interactive process viewer |
| `pstree` | `pstree` | Process tree |

### Shell Utilities

| Command | Formula | Description |
|---------|---------|-------------|
| `bat` | `bat` | Cat with syntax highlighting |
| `eza` | `eza` | Modern ls replacement |
| `entr` | `entr` | Run command on file changes |
| `parallel` | `parallel` | GNU Parallel for shell |
| `pv` | `pv` | Pipe viewer (progress bar) |
| `rename` | `rename` | Batch file rename |
| `shellcheck` | `shellcheck` | Shell script linter |
| `shfmt` | `shfmt` | Shell script formatter |
| `dos2unix` | `dos2unix` | Line ending converter |

### Compression

| Command | Formula | Description |
|---------|---------|-------------|
| `pigz` | `pigz` | Parallel gzip |
| `pbzip2` | `pbzip2` | Parallel bzip2 |
| `xz` | `xz` | XZ compression |
| `zstd` | `zstd` | Zstandard compression |

## BSD vs GNU Incompatibility Patterns

These are errors that occur when Claude uses GNU-style flags with macOS BSD tools.

### sed (gnu-sed → gsed)

| Error Pattern | Regex | Cause |
|---------------|-------|-------|
| `sed: 1: "...": invalid command code` | `sed: 1:.*: invalid command code` | GNU sed syntax not recognized by BSD sed |
| `sed: 1: "...": extra characters at the end of ... command` | `sed: 1:.*: extra characters at the end of .* command` | BSD sed requires different escaping |
| `sed: -i: ...: No such file or directory` | `sed: -[iI]: .*: No such file or directory` | BSD sed `-i` requires an extension argument (`-i ''`) |

**Fix:** `brew install gnu-sed` → use `gsed` instead of `sed`

### grep (grep → ggrep)

| Error Pattern | Regex | Cause |
|---------------|-------|-------|
| `grep: invalid option -- P` | `grep: invalid option -- P` | BSD grep doesn't support Perl-compatible regex (`-P`) |

**Fix:** `brew install grep` → use `ggrep -P` or use `grep -E` for extended regex

### find (findutils → gfind)

| Error Pattern | Regex | Cause |
|---------------|-------|-------|
| `find: -printf: unknown primary` | `find: -printf: unknown primary` | BSD find doesn't support `-printf` |
| `find: -regextype: unknown primary` | `find: -regextype: unknown primary` | BSD find doesn't support `-regextype` |

**Fix:** `brew install findutils` → use `gfind` instead of `find`

### xargs (findutils → gxargs)

| Error Pattern | Regex | Cause |
|---------------|-------|-------|
| `xargs: illegal option -- d` | `xargs: illegal option -- d` | BSD xargs doesn't support `-d` (custom delimiter) |
| `xargs: illegal option -- P` | `xargs: illegal option -- P` | BSD xargs doesn't support `-P` (parallel) |

**Fix:** `brew install findutils` → use `gxargs` instead of `xargs`

### date (coreutils → gdate)

| Error Pattern | Regex | Cause |
|---------------|-------|-------|
| `date: illegal option -- d` | `date: illegal option -- d` | BSD date doesn't support `-d` (parse date string) |
| `date: illegal option -- -` | `date: illegal option -- -` | BSD date doesn't support GNU long options |

**Fix:** `brew install coreutils` → use `gdate` instead of `date`

### readlink (coreutils → greadlink)

| Error Pattern | Regex | Cause |
|---------------|-------|-------|
| `readlink: illegal option -- f` | `readlink: illegal option -- f` | BSD readlink doesn't support `-f` (canonicalize) |

**Fix:** `brew install coreutils` → use `greadlink -f` instead of `readlink -f`

### stat (coreutils → gstat)

| Error Pattern | Regex | Cause |
|---------------|-------|-------|
| `stat: illegal option -- -` | `stat: illegal option -- -` | BSD stat uses completely different syntax |
| `stat: unrecognized option` | `stat: unrecognized option` | BSD stat uses `-f` format, not `--format` |

**Fix:** `brew install coreutils` → use `gstat` instead of `stat`

### awk (gawk → gawk)

| Error Pattern | Regex | Cause |
|---------------|-------|-------|
| `awk: ... function ... is not defined` | `awk: .*function .* is not defined` | BSD awk lacks some GNU awk functions (e.g., `mktime`, `strftime`) |
| `awk: ... unknown option` | `awk: .*: unknown option` | BSD awk doesn't support some GNU awk flags |

**Fix:** `brew install gawk` → use `gawk` instead of `awk`

### tar (gnu-tar → gtar)

| Error Pattern | Regex | Cause |
|---------------|-------|-------|
| `tar: Option --<name> is not supported` | `tar: Option --\w+ is not supported` | BSD tar missing some GNU tar options |

**Fix:** `brew install gnu-tar` → use `gtar` instead of `tar`

### sort (coreutils → gsort)

| Error Pattern | Regex | Cause |
|---------------|-------|-------|
| `sort: invalid option -- V` | `sort: invalid option -- V` | BSD sort doesn't support `-V` (version sort) |

**Fix:** `brew install coreutils` → use `gsort -V` instead of `sort -V`

## Special Cases

### python vs python3

macOS may have `python3` via Xcode Command Line Tools but not `python`. The
`python` command was removed in macOS 12.3+.

- If `python` is missing but `python3` exists: suggest adding an alias or using `python3` explicitly
- If both are missing: `brew install python@3.12`
- CLAUDE.md guidance: "Use `python3` explicitly — `python` is not available on macOS by default."

### Sandbox false positives

Claude Code's sandbox blocks direct use of some commands (like `cat`, `head`, `ls`).
Errors for these look like "command not found" but the tool IS installed — Claude
just needs to use the dedicated Read/Glob/Grep tools instead. The scanner filters
these out automatically.

### Tools with non-obvious formula names

| Command | Formula | Why |
|---------|---------|-----|
| `rg` | `ripgrep` | Binary name differs from formula |
| `ag` | `the_silver_searcher` | Binary name differs from formula |
| `fd` | `fd` | Same name but easy to confuse |
| `delta` | `git-delta` | Avoids conflict with another `delta` |
| `python` | `python@3.12` | Versioned formula |
