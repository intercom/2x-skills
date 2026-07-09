---
name: permissions-analyzer
description: |
  Vet a Claude Code permission allowlist against a GREEN/YELLOW/RED safety model and reduce permission
  prompts. Runs on top of the built-in /fewer-permission-prompts scan (and permission auto mode):
  filters proposed auto-allow commands through a GREEN/YELLOW/RED safety model — never auto-allowing
  interpreters or package-manager executors — before merging the safe ones into ~/.claude/settings.json.
  Also turns the proactive "reduce your prompts" suggestions off or on (disable/enable).
disable-model-invocation: true
metadata:
  keywords:
    - settings
    - approvals
    - security
  user-invocable: true
allowed-tools: Bash Read Write AskUserQuestion
---

# Permissions Analyzer

The mechanical scan of session history for frequently-approved commands is a job for Claude Code's
built-in `/fewer-permission-prompts` skill and permission auto mode (https://code.claude.com/docs/en/permissions).
This skill adds the layer neither provides: an opinionated **safety filter** plus a guarded
write into the user's global `~/.claude/settings.json`. The built-in scan does not apply the RED
override below, so it can auto-allow commands this skill would reject — this skill applies the filter.

## Modes

Pick the mode from the argument after `/permissions-analyzer`:

- **`disable`** (or `off`, `stop`, `mute`) — silence the proactive suggestion nudge. Run `touch ~/.claude/.disable-permissions-analyzer-suggestions`, confirm the tips are off for all sessions, and mention `/permissions-analyzer enable` turns them back on. Do not run the vet-and-merge flow.
- **`enable`** (or `on`) — re-enable the nudge. Check whether `~/.claude/.disable-permissions-analyzer-suggestions` exists, run `rm -f ~/.claude/.disable-permissions-analyzer-suggestions`, then confirm — say the suggestions are back on if the marker existed, or that they were never disabled if it did not. Do not run the vet-and-merge flow.
- **No argument (default)** — run the vet-and-merge flow below.

The marker only governs the proactive suggestions; the flow is always available by running `/permissions-analyzer` with no argument.

## Vet-and-merge flow

The goal: get safe, high-frequency commands onto the auto-allow list without letting anything that can execute arbitrary code slip through.

1. **Get candidate commands.** Prefer the built-in scan — point the user at `/fewer-permission-prompts`, which mines their session history and proposes an allowlist. Also accept a list the user pastes or the entries already in their `permissions.allow`. For users who want prompts gone entirely rather than command-by-command, mention permission **auto mode** as the broader option. With no candidates supplied and nothing to review, do not fabricate a classified list — route the user to `/fewer-permission-prompts` first, then vet what it returns.
2. **Audit what the built-in already wrote, and strip RED.** The built-in scan writes to the project `.claude/settings.json` allowlist without applying the RED override. When the user has already run it, read that allowlist (and the user's `~/.claude/settings.json`), identify any RED entries, and — on the same explicit confirmation the write path requires — remove them from the allowlist. Flagging alone is not enough: a RED rule the built-in auto-allowed stays active until it is removed.
3. **Classify each candidate** into GREEN / YELLOW / RED using `references/safety-tiers.md`. The RED override is the whole point of this skill — see below.
4. **Present grouped by tier** in a table before asking for confirmation.
5. **Merge the safe ones** into `~/.claude/settings.json` on explicit confirmation.

## Read `references/safety-tiers.md` first

Classification rules and the permission syntax table live there. Two things matter most:

- **The RED override.** Anything that can execute arbitrary code — directly or via `run`/`exec`/`start` subcommands — is RED, even if the same tool is a "package manager" or "build tool". `npm`, `npx`, `uv`, `bundle`, `pipx`, `bunx`, `deno`, `mise` and bare interpreters (`bash`, `python`, `node`, `ruby`) are never auto-allow candidates.
- **Read-only is not "looks read-only".** A linter is GREEN only when it cannot mutate files (`eslint` without `--fix`, `rubocop` without `-A`/`-a`).

`references/security-rationale.md` covers the threat model (prompt injection, supply chain, side effects) — cite it when a user pushes back on a RED.

<!--
Maintainer note: the bullets below are declarative *constraints*, not a runbook — kept
flat on purpose to avoid procedure smell. Do NOT drop the tier-grouped-table presentation
or the "preserve other keys" merge rule: both are load-bearing operational facts. The
get-candidates→classify→confirm→write order is derivable from these constraints; the
guardrails are not.
-->

**Constraints:**
- Present the classified commands grouped by safety tier in a table before asking for confirmation.
- Dedup against the **target** file — the user's global `~/.claude/settings.json` `permissions.allow`. Skip a command only if it is already allowed there; a command being present in the project `.claude/settings.json` allowlist is not a reason to skip promoting it to the global allowlist.
- Never write to `~/.claude/settings.json` without explicit user confirmation via `AskUserQuestion`. Show the diff first.
- When merging accepted patterns into `permissions.allow`, preserve every other key in `settings.json` — surgical merge, never a full-file overwrite.
- Back up the file before attempting to repair a malformed `settings.json`.
- Use the Permission Syntax table in `safety-tiers.md` for rule format — don't improvise patterns.

## Resources

- `references/safety-tiers.md` — Classification rules, RED override, permission syntax
- `references/security-rationale.md` — Threat model and defense layers
