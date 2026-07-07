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

## License

MIT
