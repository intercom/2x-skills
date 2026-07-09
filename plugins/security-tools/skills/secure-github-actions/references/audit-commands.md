# Quick Audit Commands

Load this reference when auditing an existing set of workflows for violations of the rules in SKILL.md. Each command maps to a rule; run the ones relevant to the concern at hand.

Scan existing workflows for violations:

```bash
# Any ${{ }} in run: blocks (all expressions, not just attacker-controlled)
grep -rn 'run:' .github/workflows/*.yml | xargs -I{} grep -n '\${{' {} 2>/dev/null
# More precise: find run: blocks and check for ${{ inside them
for f in .github/workflows/*.yml; do
  awk '/^[[:space:]]*run:[[:space:]]*\|/{flag=1;next} flag && /^[[:space:]]*[a-z]/{flag=0} flag && /\$\{\{/{print FILENAME":"NR": "$0}' "$f"
done

# secrets: inherit
grep -rn 'secrets: inherit' .github/workflows/

# Mutable action refs (not SHA-pinned)
grep -rn 'uses:' .github/workflows/ | grep -v '@[a-f0-9]\{40\}' | grep -v '@main'

# Missing permissions blocks
for f in .github/workflows/*.yml; do
  grep -q 'permissions:' "$f" || echo "MISSING permissions: $f"
done

# Reusable-workflow callers that lack a top-level permissions: block
# (caller permissions cap callee permissions — missing block = callee silently
# clipped to org default of read-only)
for f in .github/workflows/*.yml; do
  if grep -qE 'uses:.*\.ya?ml@' "$f"; then
    grep -qE '^permissions:' "$f" || echo "REUSABLE CALLER missing top-level permissions: $f"
  fi
done

# Unpinned npx
grep -rn 'npx.*@latest\|npx -y ' .github/workflows/

# PR creation or approval (fails if the org setting "Allow GitHub Actions to
# create and approve pull requests" is off — migrate to a GitHub App)
grep -rn 'gh pr review\|gh pr create\|pulls/.*/reviews' .github/workflows/

# Unrestricted Bash in Claude actions
grep -rn 'allowed_tools.*Bash[^(]' .github/workflows/

# GITHUB_ENV/GITHUB_PATH writes with attacker input
grep -rn 'GITHUB_ENV\|GITHUB_PATH' .github/workflows/

# Missing persist-credentials: false (public repos)
grep -rn 'actions/checkout' .github/workflows/ | grep -v 'persist-credentials'
```
