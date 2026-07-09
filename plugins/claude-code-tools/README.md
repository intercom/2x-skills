# claude-code-tools

Meta-tools for running Claude Code well: audit your permission allowlist, fix local toolchain gaps, and analyze usage costs.

Part of the [`fin-2x`](../../README.md) marketplace.

## Install

```
/plugin marketplace add intercom/2x-skills
/plugin install claude-code-tools@fin-2x
```

## Skills

- **[permissions-analyzer](./skills/permissions-analyzer/)** — Vets a Claude Code permission allowlist against a GREEN/YELLOW/RED safety model and merges the safe entries into `~/.claude/settings.json`. Runs on top of the built-in `/fewer-permission-prompts` scan, adding a RED override that never auto-allows shell interpreters or package-manager executors (`npm`, `uv`, `bundle`, `npx`, …).
- **[tool-misses](./skills/tool-misses/)** — Scans recent Claude Code sessions for `command not found` errors and BSD/GNU incompatibilities on macOS, fixes them via Homebrew, and records availability in CLAUDE.md.
- **[cc-cost-analysis](./skills/cc-cost-analysis/)** — A framework, ready-to-use query shapes, and cost-model formulas for analyzing Claude Code usage costs from exported OpenTelemetry data (per-user spend, expensive sessions, context bloat, model/token breakdowns).

## Hooks

`claude-code-tools` installs opt-out nudge hooks (all non-blocking — they only inject a context reminder):

- A `PermissionRequest` counter plus a `PostToolUse` hook that suggests `/permissions-analyzer` after you've been prompted for approval several times in a session.
- A `PostToolUse` hook that suggests `/tool-misses` when a genuine `command not found` or BSD/GNU incompatibility shows up in command output.

Silence either with `/permissions-analyzer disable` / `/tool-misses off` (re-enable with `enable` / `on`).

## License

MIT
