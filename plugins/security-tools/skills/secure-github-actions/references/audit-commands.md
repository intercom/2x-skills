# Quick Audit Commands

Load this reference when auditing an existing set of workflows for violations of the rules in SKILL.md. Each command maps to a rule; run the ones relevant to the concern at hand.

Scan existing workflows for violations:

```bash
# Any ${{ }} inside a run: step value. Parses the YAML rather than pattern-matching
# lines, so every scalar form (inline, block |/>, plain multi-line, list items) is
# covered and non-step keys — e.g. a job coincidentally named "run" — are ignored.
# Runs under uv, which fetches PyYAML on the fly; the mikefarah yq equivalent is
#   yq '.jobs[].steps[] | select(.run) | select(.run | test("\{\{")) | .run' FILE
uv run --with pyyaml python - <<'PY'
import glob, yaml
for f in sorted(glob.glob(".github/workflows/*.yml") + glob.glob(".github/workflows/*.yaml")):
    try:
        data = yaml.safe_load(open(f))
    except yaml.YAMLError as e:
        print(f"{f}: YAML parse error: {e}"); continue
    if not isinstance(data, dict):
        continue
    for job_id, job in (data.get("jobs") or {}).items():
        if not isinstance(job, dict):
            continue
        for i, step in enumerate(job.get("steps") or []):
            run = step.get("run") if isinstance(step, dict) else None
            if isinstance(run, str) and "${{" in run:
                label = step.get("name") or f"step {i}"
                print(f"{f}: job '{job_id}' > {label}: " + "run uses a ${{ }} expression")
PY

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
