# code-review-tools

Strict structural and architectural code review that hunts for dramatic simplifications.

Part of the [`fin-2x`](../../README.md) marketplace.

## Install

```
/plugin marketplace add intercom/2x-skills
/plugin install code-review-tools@fin-2x
```

## Skills

- **[thermo-nuclear-code-review](./skills/thermo-nuclear-code-review/)** — An extremely strict structural and architectural review of a diff, branch, or file set. It hunts for "code judo" moves — changes that dramatically simplify the implementation — rather than correctness bugs or style nits. Applies a numbered set of standards (dead code, wrong abstraction layer, reinvented primitives, over-configurable code, …) with severity levels and a high approval bar. Pair it with a separate correctness-focused review; this one is about structure.

## License

MIT
