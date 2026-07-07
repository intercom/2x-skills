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

## License

MIT
