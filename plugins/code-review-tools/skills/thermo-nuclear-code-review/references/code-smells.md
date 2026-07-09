# Structural Code Smell Baseline (Fowler)

An always-on baseline of structural "Bad Smells in Code" (Martin Fowler, _Refactoring_, ch. 3), curated for the thermo-nuclear review. This baseline applies even when a file or repo documents no standards of its own — it is the structural floor every diff is measured against, alongside the Non-Negotiable Standards.

## Two binding rules

These two rules keep the baseline safe and prevent it from manufacturing noise:

1. **The repo overrides the baseline.** A documented pattern in your team's style guide, an existing convention in the surrounding code, or an explicit team standard always wins. Where the codebase deliberately endorses something the baseline would flag (e.g. a canonical `case`/`when` dispatcher that the architecture standardizes on), suppress the smell — do not flag it.
2. **Every smell is a judgement call, never a hard violation.** Name the smell as a labelled heuristic ("possible Feature Envy here"), quote the hunk, and explain the structural cost. Default smells to **MAJOR** or **SUGGESTION**. Escalate to **BLOCKER** only when a smell compounds a Non-Negotiable Standard — e.g. Duplicated Code that re-implements a canonical helper is also a Standard 6 (canonical layer) violation; Speculative Generality that adds a whole layer of indirection is also a Standard 4 violation.

**Skip anything tooling already enforces.** RuboCop, ESLint, Prettier, and type-checkers catch formatting, naming-convention, and lint issues. Do not spend findings on what CI already blocks — the review's value is the structural judgement no linter can make.

## The smells

Each smell reads *what it is* → *how to fix*. Match each against the diff (and, per the Review Context, against the full files the diff touches).

- **Mysterious Name** — a method, variable, class, or type whose name doesn't reveal what it does or holds. → Rename it. If no honest name comes easily, the design underneath is murky — that's the real finding.
- **Duplicated Code** — the same logic shape appears in more than one hunk or file in the change. → Extract the shared shape and call it from both. If a canonical helper already exists, reuse it (Standard 6).
- **Feature Envy** — a method that reaches into another object's data more than its own (chains of `other.x`, `other.y`, `other.z`). → Move the method onto the data it envies, or extract the envious part.
- **Data Clumps** — the same few fields or parameters keep travelling together (a type wanting to be born). → Bundle them into one value object / struct / typed model and pass that instead.
- **Primitive Obsession** — a primitive, string, or hash standing in for a domain concept that deserves its own type (Standard 5: type/boundary cleanliness). → Give the concept its own small type rather than threading raw primitives through signatures.
- **Repeated Switches** — the same `case`/`when` or `if`-cascade on the same type recurs across the change. → Replace with polymorphism, a typed dispatcher, or one map both sites share (Standard 4: replace condition chains). _Suppress if the repo standardizes on an explicit dispatcher — rule 1._
- **Shotgun Surgery** — one logical change forces scattered edits across many unrelated files in the diff. → Gather what changes together into one module so the next change touches one place (relates to Standard 2: spaghetti growth).
- **Divergent Change** — one file or module is edited for several unrelated reasons in the same diff. → Split so each module changes for one reason.
- **Speculative Generality** — abstraction, parameters, hooks, or config added for needs the change doesn't actually have. → Delete it; inline back until a real need shows up (Standard 4: thin abstractions / identity wrappers).
- **Message Chains** — long `a.b().c().d()` navigation the caller shouldn't depend on. → Hide the walk behind one method on the first object (law of Demeter).
- **Middle Man** — a class or method that mostly just delegates onward without adding anything. → Cut it and call the real target directly (Standard 4: delete wrappers that don't clarify the API).
- **Refused Bequest** — a subclass or implementer that ignores or overrides most of what it inherits. → Drop the inheritance and use composition instead.

## How this fits the review

- These smells are the **structural floor**, not a new axis. They feed the same finding format and the same severity ladder (BLOCKER / MAJOR / SUGGESTION) as the Non-Negotiable Standards.
- When a smell points at a code judo move (whole branches, helpers, or layers disappearing), prefer that framing over a mechanical "extract method" suggestion — Standard 0 still governs.
- Several smells overlap with the Standards by design (Duplicated Code ↔ Std 2/6, Speculative Generality / Middle Man ↔ Std 4, Primitive Obsession ↔ Std 5, Repeated Switches ↔ Std 4). The catalogue's job is to widen recall for the smells the Standards don't name explicitly — Mysterious Name, Feature Envy, Data Clumps, Shotgun Surgery, Divergent Change, Message Chains, Refused Bequest.
</content>
