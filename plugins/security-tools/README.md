# security-tools

Harden GitHub Actions workflows against supply-chain and injection attacks.

Part of the [`fin-2x`](../../README.md) marketplace.

## Install

```
/plugin marketplace add intercom/2x-skills
/plugin install security-tools@fin-2x
```

## Skills

- **[secure-github-actions](./skills/secure-github-actions/)** — Harden GitHub Actions workflows against supply-chain and injection attacks when creating, modifying, or reviewing a `.github/workflows/*.yml` file. 14 rules covering expression injection, SHA-pinning, least-privilege permissions, `pull_request_target`, and OIDC.

## Hooks

`security-tools` installs a `PostToolUse` hook that fires when you read or edit a file under `.github/workflows/` (or `.github/workflows-disabled/`) and reminds Claude to load the `secure-github-actions` skill, so workflow changes get the hardening review automatically. It is non-blocking — it only injects a context reminder.

## License

MIT
