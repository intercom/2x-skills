# Suggested Rewrites — Format Spec

This file is the **cross-cutting format spec** for the rewrite block — placement, structure, authoring constraints. It does NOT decide *whether* a given finding gets a rewrite.

**The decision to rewrite (or not) for a finding lives in that finding's category reference**, under the "Rewrite Policy" subsection — see [`structural.md`](./structural.md), [`integrity.md`](./integrity.md), [`test-coverage.md`](./test-coverage.md), [`security.md`](./security.md), [`content-quality.md`](./content-quality.md), [`convention.md`](./convention.md), or [`cost.md`](./cost.md) for the policy that applies to its findings.

Quick reference — which categories produce rewrites:

| Category | Rewrites produced? |
|----------|--------------------|
| Structural Discipline | No (describe structural change in prose) |
| Integrity | **Yes** for Behaviour findings (concrete code fix); prose for others |
| Test Coverage | No (describe the eval scenario in prose) |
| Security | **Yes** for executable-script bugs; prose for credential-paste and auth-flow findings |
| Content Quality | **Yes** for procedure smell / vague context, `weak-completion-criterion`, and `temporal-self-reference`; prose for `no-op-instruction` (unless the fix is a strong-leading-word replacement) |
| Convention | **Yes** for similar-skill "differentiate" verdict, `description-as-routing-signal`, and `invocation-mode-mismatch`; prose for placement / hook integration / repo-convention |
| Cost | No (point at the anti-pattern and name the lever; author applies the fix) |

The rest of this file is the format spec the rewrite block follows when a category does call for one.

## Format

Place the rewrite inside the finding it addresses, in a collapsible details block so reviewers can scan findings without scrolling through replacement text:

```markdown
**Major:** Section "## Querying Data" is procedural — 6 numbered steps teaching
generic telemetry-tool usage Claude already knows. The project-specific facts (dataset
name, environment filter, column availability) are valuable but buried in choreography.

<details>
<summary>Suggested rewrite</summary>

[Complete replacement section here — ready to copy into SKILL.md]

</details>
```

## Authoring Constraints

When writing a rewrite under rules 1–3:

1. **Preserve all project-specific facts** from the original — don't lose real context when removing procedure.
2. **Make it copy-pasteable** — the author should be able to drop it in as a direct replacement.
3. **Be shorter than the original** — removing choreography naturally reduces length.
4. **Use declarative structure** — tables, constraint lists, "when X, Y applies" patterns beat numbered steps.
5. **Don't invent new content** — only restructure what's already in the skill or its references.
6. **For reference files**: include any expected frontmatter or headers; produce the full file, not a fragment.
