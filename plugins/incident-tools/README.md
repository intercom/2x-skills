# incident-tools

Evidence-grounded root cause analysis for incidents and post-mortems.

Part of the [`fin-2x`](../../README.md) marketplace.

## Install

```
/plugin marketplace add intercom/2x-skills
/plugin install incident-tools@fin-2x
```

## Skills

- **[five-whys](./skills/five-whys/)** — Builds a five-whys causal chain from impact to a root cause you can act on. Every factual claim cites a primary source and carries a Measured, Derived or Inferred label. One fact-checker subagent per section re-verifies the claims, then a cynic subagent tries to break each causal link. The chain ships only when every claim is confirmed or labelled as an inference and no link is broken. Written for internal RCAs and post-mortems, not customer-facing write-ups.

## License

MIT
