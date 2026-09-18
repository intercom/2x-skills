# pr-tools

Open well-formed GitHub pull requests from Claude Code and attach screenshots and recordings to them.

Part of the [`fin-2x`](../../README.md) marketplace.

## Install

```
/plugin marketplace add intercom/2x-skills
/plugin install pr-tools@fin-2x
```

## Skills

- **[attach-github-assets](./skills/attach-github-assets/)** — Upload local files (screenshots, screen recordings, images, videos) to GitHub as user-attachment assets and return markdown-ready URLs for PR descriptions, issue bodies, or PR/issue comments.
- **[create-pr](./skills/create-pr/)** — Open or update a well-formed GitHub pull request for the current branch: gathers intent, validates the diff against it, applies public-repo safeguards, and writes a clean Why/How description.

## Watchers

`create-pr` launches these three scripts in the background once a PR is created or updated, so the session never polls `gh pr view` / `gh pr checks` in a loop. Each blocks until something changes (or times out at ~9.5 minutes and prints a cursor to resume from):

- **watch-pr-comments.sh** — blocks until a new comment, review, or inline review comment lands.
- **watch-pr-merged.sh** — blocks until the PR is merged or closed unmerged.
- **pr-check-watcher.sh** — blocks until all CI checks (check-runs and commit statuses) reach a terminal state.

## Hooks

`pr-tools` installs a `PreToolUse` hook that intercepts direct `gh pr create` calls and redirects you to the `create-pr` skill, so PRs go through its intent-gathering and public-repo safeguards. Once `create-pr` is loaded in the session, `gh pr create` runs normally. The hook only matches real invocations (not `gh pr create` mentioned inside a quoted string or heredoc), fails open on any ambiguity, and clears its per-session state on context compaction.

## License

MIT
