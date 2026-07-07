# Public Repository Rules (Rules 12-14)

Load this reference when the workflow under review lives in a **public** repo. These three rules apply *in addition to* Rules 1-11 (which always apply); they are the extra hardening public exposure demands.

**These rules apply only to public repos.** Before reviewing a workflow, check:
```bash
gh repo view --json visibility -q '.visibility'
```
If the result is `PUBLIC`, enforce Rules 12-14 in addition to Rules 1-11.

### Rule 12: Living Off The Pipeline (LOTP) — no secrets on fork PR builds

On public repos, `pull_request` workflows triggered by fork PRs should never
have access to secrets when running linters, build tools, or security scanners.

**Why:** Attackers submit PRs that modify tool config files (`.eslintrc`, `Makefile`,
`.rubocop.yml`, `pyproject.toml`) containing code execution directives. When CI runs
these tools, the malicious config executes with whatever permissions the workflow has.

**Mitigations:**
- Don't store secrets in workflows that run on `pull_request` from forks
- Run build/lint/test steps in a separate job with `permissions: {}` (no token)
- If secrets are needed, use a two-stage workflow: unprivileged build on fork PR,
  privileged deploy only on merge to protected branch

### Rule 13: Use `persist-credentials: false` on checkout

In public repo workflows, always set `persist-credentials: false` on
`actions/checkout` unless the job needs to push commits.

```yaml
- uses: actions/checkout@SHA # pinned
  with:
    persist-credentials: false
```

**Why:** By default, `actions/checkout` saves credentials in `.git/config`. If a
subsequent step uploads artifacts or runs untrusted code, those credentials can be
exfiltrated. `persist-credentials: false` removes them after checkout.

### Rule 14: Require OIDC tokens over long-lived secrets for cloud auth

For workflows that authenticate to AWS, GCP, or other cloud providers, prefer
OIDC token exchange over long-lived access keys stored as secrets.

```yaml
# VULNERABLE — long-lived key, high blast radius if leaked
env:
  AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
  AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}

# SAFE — short-lived token, scoped to this workflow run
permissions:
  id-token: write
steps:
  - uses: aws-actions/configure-aws-credentials@SHA
    with:
      role-to-assume: arn:aws:iam::ACCOUNT:role/github-actions
      aws-region: us-east-1
```

**Why:** OIDC tokens are short-lived (minutes), scoped to a specific workflow run,
and cannot be reused. Long-lived secrets persist until rotated and grant access to
anyone who exfiltrates them.
