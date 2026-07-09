# Command Safety Classification

Classify commands by their potential impact, not by name. The same command can be safe or dangerous depending on context and arguments.

**Precedence rule:** If a command can execute arbitrary code — directly or via subcommands like `run`, `exec`, `start` — it is RED, regardless of its other capabilities. Many package managers double as script executors.

## Classification Principles

### GREEN - Safe to Auto-Allow

Commands that meet ALL of these criteria:

- **Read-only**: Does not modify files, state, or external systems
- **Local scope**: Only accesses the local filesystem
- **No secrets exposure**: Does not read sensitive files or environment variables
- **Predictable output**: Results are deterministic and bounded

**Examples of safe activities:**
- Listing directory contents
- Searching file contents
- Checking file metadata
- Running test suites (sandboxed execution)
- Running linters and formatters in read-only mode (e.g. `eslint` without `--fix`, `rubocop` without `-A`/`-a`, `prettier --check`). The same tool with a write flag is YELLOW.

### YELLOW - Recommend With Caution

Commands that have legitimate frequent use but carry moderate risk:

- **Modifies local state**: Creates, moves, or edits files
- **Runs predefined operations**: Build tools, test runners, linters — tools that execute a fixed, known set of operations (NOT arbitrary script execution — see RED)
- **Version control**: Can modify history or push to remotes

> **Package managers are not YELLOW.** Tools like `npm`, `uv`, `bundle`, `pipx` are sometimes considered "dependency installers" but they all expose subcommands that execute arbitrary user-provided code (`npm exec`, `uv run`, `bundle exec`, `pipx run`) and run lifecycle scripts on install. The RED override below takes precedence — they belong in RED, not here.

**Key consideration:** These commands are often safe in development workflows but can cause issues if misused. Explain the tradeoff and let the user decide.

### RED - Never Auto-Allow

Commands involving any of these risk categories:

**Shell Interpreters**
- Any command that can execute arbitrary code (bash, sh, zsh, fish, etc.)
- Script interpreters (python, ruby, node, perl) without specific constraints
- These bypass all other safety checks since they can run any command

**Package Managers That Execute Code**
- These tools are primarily package managers but can also execute arbitrary code, making them as dangerous as script interpreters:
  - `npm` / `npx` — `npm exec`, `npx <pkg>` run arbitrary packages; lifecycle scripts (`preinstall`, `postinstall`) execute on install
  - `uv` — `uv run` executes arbitrary Python scripts and commands
  - `bundle` / `bundler` — `bundle exec` runs arbitrary commands in gem context
  - `pipx` — `pipx run` executes arbitrary Python packages
  - `bunx` / `bun` — `bunx <pkg>` runs arbitrary packages; `bun run` executes scripts
  - `deno` — `deno run` executes arbitrary TypeScript/JavaScript
  - `mise` — `mise exec` / `mise run` executes arbitrary commands
- The key test: can `<tool> run <script>` or `<tool> exec <command>` execute arbitrary user-provided code? If yes, it belongs here.

**Destructive Operations**
- Permanent deletion without recovery
- Overwriting data without backup
- Resetting state irreversibly

**Secret Exposure**
- Reading credential files
- Dumping environment variables
- Accessing private keys or tokens

**Third-Party System Actions**
- Cloud infrastructure modifications (AWS, GCP, Azure)
- Container orchestration changes
- Remote server access
- API calls that create, modify, or delete resources

**Privilege Escalation**
- Running commands as root or another user
- Modifying file permissions or ownership

**Arbitrary Remote Execution**
- Downloading and executing scripts
- Opening network connections for data transfer

---

## Permission Syntax

| Pattern | Meaning |
|---------|---------|
| `Bash(git status)` | Exact command only |
| `Bash(git:*)` | Command with any subcommand/args |
| `Bash(git add:*)` | Specific subcommand with any args |

---

## Evaluation Questions

When classifying an unfamiliar command, ask:

1. **Is it a shell/script interpreter, or can it execute arbitrary code?** (bash, sh, python, ruby, node, uv, npm, npx, bundle, pipx, bunx, deno, mise) - Always RED
2. **Does it modify anything?** Files, state, external systems?
3. **Could it expose secrets?** Reads configs, env vars, credentials?
4. **Does it affect systems beyond this machine?** Cloud, remote, APIs?
5. **Is the action reversible?** Can mistakes be undone?
6. **Does it require elevated privileges?** Sudo, root, other users?

If the answer to any of these is "yes" or "maybe", it should not be auto-allowed.
