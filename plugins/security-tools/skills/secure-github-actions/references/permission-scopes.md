# Choosing GITHUB_TOKEN Permission Scopes

Detail behind Rule 5. Two production incidents are recorded here — a PR-comment
403 and an org-wide `startup_failure` — because both came from a hardening pass
that narrowed a scope on reasoning that looked correct from the caller alone.

## The API namespace is NOT the permission scope

Do **not** derive the permission scope from the REST method's namespace. For the Actions
default `GITHUB_TOKEN`, the permission check keys off the **resource being acted on**, not
the API path. The trap: **commenting on a pull request with the `GITHUB_TOKEN` requires
`pull-requests: write`** even though the call goes through the *issues* namespace
(`github.rest.issues.createComment`, `gh pr comment`, `gh issue comment` on a PR). PRs are
issues in the REST data model, but the `GITHUB_TOKEN` permission gate treats a PR as a PR.

Commenting on a real **issue** does take `issues: write` — keep that scope for
issue-comment workflows, and do not flag it. The point is narrower: `issues: write` does
**not** also unlock commenting on a **PR** under the `GITHUB_TOKEN`. (GitHub's "Create an
issue comment" REST reference lists `issues: write` as accepted, but that describes issue
targets and fine-grained PATs; the `GITHUB_TOKEN`-on-a-PR path is the exception this rule
exists for.)

This is not theoretical. A real PR-commenting workflow ran fine with `pull-requests: write`
(and no `issues:` scope). A hardening pass changed it to `pull-requests: read` +
`issues: write`, and the `github.rest.issues.createComment` call failed at runtime:

```
RequestError [HttpError]: Resource not accessible by integration
status: 403
'x-accepted-github-permissions': 'issues=write; pull_requests=write'
```

`issues: write` was present yet the comment still 403'd, because `pull-requests` had been
downgraded to `read`. The minimal scope that works is **`pull-requests: write` alone** —
before the breaking change the workflow commented on PRs with `pull-requests: write` and no
`issues:` scope at all. So for a PR-comment workflow, grant `pull-requests: write` and
never downgrade it to `read`; add `issues: write` **only** if the same workflow also
comments on or manages real *issues*. `issues: write` is neither sufficient for PR comments
nor required when only PRs are touched. (GitHub's `x-accepted-github-permissions` header
lists `issues=write; pull_requests=write`, but it is over-broad here — the production
before-state proves `pull-requests: write` on its own is enough.)

```yaml
# BROKEN — workflow triggers on pull_request and posts a comment on the PR,
# but pull-requests was downgraded to read because the call "uses issues.createComment".
# The comment API returns 403 at runtime; the step fails.
permissions:
  pull-requests: read   # WRONG for a workflow that comments on PRs
  issues: write

# SAFE — commenting on a PR target needs pull-requests: write
permissions:
  pull-requests: write
```

Quick scope map for the common operations:

| Operation | Required scope |
|-----------|---------------|
| Comment on a **PR** with `GITHUB_TOKEN` (`issues.createComment` / `gh pr comment` on a PR) | `pull-requests: write` (sufficient on its own; `issues: write` is neither required nor sufficient for PR comments) |
| Comment on an **issue** | `issues: write` |
| Add/remove labels on an issue | `issues: write` |
| Add/remove labels on a PR | `issues: write` or `pull-requests: write` (label endpoints accept either) |
| Reusable-workflow caller whose callee uses OIDC | keep `id-token: write` (do not strip) |
| List PR files / read PR metadata (`pulls.listFiles`, `pulls.get`) | `pull-requests: read` |
| Edit PR title/body (`pulls.update`) | `pull-requests: write` |
| Request PR reviewers (`pulls.requestReviewers`) | `pull-requests: write` |

## Never downgrade an existing `write` scope during a hardening pass without checking what runs

Least privilege means removing scopes the workflow does **not** use — not blindly
narrowing every `write` to `read`. Before lowering an existing `write` scope (especially
`pull-requests: write`), read every step and confirm the workflow does not *write* to
that resource at runtime. A workflow that posts PR comments, edits PRs, or manages
labels genuinely needs its write scope; downgrading it produces a silent 403 that CI
may still log as green. When in doubt, keep the existing `write` scope and flag it for
manual confirmation rather than narrowing it.

## Reusable workflow callers: caller caps callee

For reusable-workflow callers, the rule above is **functional**, not just
defense-in-depth: the callee's `permissions:` block can only restrict the
caller's, never expand it. Without a caller block, the callee's writes get
silently clipped — the workflow logs green while the API call returns 403/404
inside the script.

Mirror every scope the callee declares at the caller's top level.

```yaml
# BROKEN — callee declares `permissions: issues: write` for label management,
# but the caller's missing permissions block clips the request to read-only.
# Workflow logs green; labelling silently fails.
jobs:
  call-label-prs:
    uses: your-org/shared-workflows/.github/workflows/label-prs.yml@1a2b3c4d5e6f70819a2b3c4d5e6f70819a2b3c4d # v1.5.0

# SAFE — caller grants what the callee needs.
permissions:
  contents: read
  issues: write
jobs:
  call-label-prs:
    uses: your-org/shared-workflows/.github/workflows/label-prs.yml@1a2b3c4d5e6f70819a2b3c4d5e6f70819a2b3c4d # v1.5.0
```

**You usually cannot see what the callee needs from the caller alone.** A reusable
workflow lives in another file (often another repo), so a scope the caller's own steps
never reference is **not** evidence it's unused — the callee may depend on it. Never strip
a scope from a reusable-workflow caller on "the caller doesn't use it" reasoning. To
verify, read the callee's top-level `permissions:` (and what its steps do); if you can't,
**keep the existing scope** and leave an inline comment so the next hardening pass does too.

`id-token: write` is the highest-stakes example. A caller that only `uses:` a reusable
workflow has no OIDC step of its own, so a hardening pass that can't see the callee reads
`id-token: write` as "unnecessary" and strips it — but if the callee authenticates to a
cloud via OIDC (`aws-actions/configure-aws-credentials`, etc.), the caller's cap now
denies it. This is rejected at **run-creation time** → `startup_failure`: no jobs, no
logs, just a red X. (This is a real failure mode: an org-wide reusable workflow that
uploads to cloud storage via OIDC broke every caller that had `id-token: write` stripped —
every push failed with `startup_failure`.)

```yaml
# BROKEN — caller dropped id-token: write because no caller step uses OIDC.
# The callee uploads to cloud storage via OIDC; run creation fails with startup_failure.
permissions:
  contents: read
jobs:
  upload-sbom:
    uses: your-org/shared-workflows/.github/workflows/upload-sbom.yml@c0ffee1234567890abcdef1234567890abcdef12 # v3.2.0

# SAFE — keep id-token: write; the callee's OIDC step needs it.
permissions:
  contents: read
  id-token: write   # required by the reusable callee for OIDC cloud upload
jobs:
  upload-sbom:
    uses: your-org/shared-workflows/.github/workflows/upload-sbom.yml@c0ffee1234567890abcdef1234567890abcdef12 # v3.2.0
```

Note the two distinct failure modes: a clipped **`GITHUB_TOKEN`** scope (issues,
pull-requests, contents…) fails *inside* the callee at API-call time (403/404, often
logs green); a clipped **`id-token: write`** fails at *run creation* (`startup_failure`,
no logs at all).
