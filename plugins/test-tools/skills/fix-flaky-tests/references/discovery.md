# Environment Discovery

Flaky-test investigation depends on three things that vary by repository: the **test
framework**, the **CI provider**, and the **app profile** (product-specific conventions
and known flake patterns). Detect each one before classifying a failure, then load only
the matching tier files. This keeps the generic methodology in `SKILL.md` while pulling in
the right framework idioms, log-fetch procedure, and app-specific flake catalogue.

Run detection once at the start of an investigation. It is cheap (a few `ls`/`grep`/`git`
calls) and determines which reference files are worth loading.

## 0. Target repository (resolve this first)

Everything below — framework files, CI log-fetch, app profile, and the git/PR-history fast
exits — must target the **code repo the failing test actually lives in**. That is not
always the repo you are checked out in (the skill may be invoked from other working
directories), and — critically — it is **not reliably the repo named in an issue or CI
URL**:

- **Issue-tracker URLs are often centralized.** Flaky-test issues for many repos may be
  filed in one shared tracker repo, even for tests that live in a different code repo. The
  `github.com/<org>/<repo>` in an issue link is the *tracker* repo, which may not be the
  code repo.
- **CI URLs name pipelines, not repos.** A Buildkite pipeline slug
  (`buildkite.com/<org>/<pipeline>`) is not necessarily a repo name.

So do not infer the code repo from a URL's path. Instead, anchor on the **failing test
file**:

1. Get the failing test's file path — usually named in the issue title/body or the user's
   prompt; fall back to the CI logs if it isn't. The issue/CI URLs are inputs to *identify
   the test*, not a source of the repo name.
2. The target repo is whichever repo contains that file. Check the current checkout first:
   `git ls-files --error-unmatch <test_file>` (or `ls <test_file>`). If it resolves, the
   current checkout is the target — confirm with `git remote get-url origin`.
3. **If the current checkout does not contain the failing test file**, you are in the wrong
   repo: the git/PR-history fast exits (`git log`, `gh pr list`) and file-based framework
   detection would silently run against the wrong project. Say so and switch to (or ask the
   user for) the checkout that contains the test before continuing.

The framework (§1) and CI (§2) signals below are then read from the **target** repo's
checkout, and the app profile (§3) from the **target** repo's identity (`git remote get-url
origin` of that checkout) — never from a tracker-issue or pipeline URL.

## 1. Test framework

Detect from files in the repo root (and the test directory layout). First match wins; a
repo can run more than one, in which case pick the framework that owns the failing file.

| Signal | Framework | Load |
|--------|-----------|------|
| `Gemfile` + `.rspec` or `spec/` dir | RSpec (Ruby) | `references/frameworks/rspec.md` |
| `package.json` with `jest`/`vitest` dep, `*.{test,spec}.{js,jsx,ts,tsx}` | Jest / Vitest (JS/TS) | `references/frameworks/<jest>.md` if present, else `_template.md` |
| `pytest.ini` / `tox.ini` / `pyproject.toml [tool.pytest.ini_options]` + `tests/` | pytest (Python) | framework file if present, else `_template.md` |
| `go.mod` + `*_test.go` | `go test` (Go) | framework file if present, else `_template.md` |

Only `frameworks/rspec.md` ships fully fleshed today. For any other framework, fall back to
`references/classification-generic.md` (the categories are language-agnostic) and treat
`frameworks/_template.md` as the shape a new framework file should take.

## 2. CI provider

The provider determines **how to fetch the failing job's logs** — the single most important
input (see the HARD GATE in `SKILL.md`).

**A CI URL in the prompt wins — check it before the repo config.** If the user supplied a
build/job URL, the provider is whatever that URL points at, regardless of which config
directories the repo carries:

| URL host / shape | Provider |
|--------|----------|
| `buildkite.com/...` | Buildkite |
| `circleci.com/...` or `app.circleci.com/...` | CircleCI |
| `github.com/<org>/<repo>/actions/runs/...` | GitHub Actions |

This matters in multi-CI repos: a repo with `.buildkite/` may still be failing on a GitHub
Actions run linked in the issue. Detecting the provider from config dirs there would load the
wrong log-fetch procedure and then fail the hard gate (or ask for pasted logs) even though the
correct logs were fetchable. Always reconcile the provider with the URL the user gave you.

**No URL given — detect from CI config directories:**

| Signal | Provider | Load |
|--------|----------|------|
| `.buildkite/` (e.g. `pipeline.yml`) | Buildkite | `references/ci/buildkite.md` |
| `.circleci/config.yml` | CircleCI | `references/ci/<circleci>.md` if present, else `_template.md` |
| `.github/workflows/*.yml` running tests | GitHub Actions | `references/ci/<github-actions>.md` if present, else `_template.md` |

If a repo matches more than one signal and no URL disambiguates, ask the user which CI ran the
failing job rather than guessing.

Only `ci/buildkite.md` ships fully fleshed today. For any other provider, the HARD GATE
still applies — get the real CI error from that provider's UI/API/logs, or ask the user to
paste the exception and backtrace. `ci/_template.md` is the shape a new CI file should take.

## 3. App profile

Detect from the **target** repo's identity — `git remote get-url origin` of the checkout
that contains the failing test file (resolved in §0), never from a tracker-issue or pipeline
URL. The app profile carries product-specific flake patterns (services, error classes,
infra) and workflow conventions (PR routing, bot behaviour) that the generic core cannot
know.

No app profiles ship with this skill by default — the mechanism is an extensibility point,
not a bundled catalogue:

| Repo | Profile | Load |
|------|---------|------|
| `your-org/your-app` | (example) | `references/profiles/your-app.md` |
| (anything else) | none bundled | skip — use generic + framework tiers only |

When no profile matches, do not invent app-specific classifications. Use
`classification-generic.md` plus the framework file, enforce the HARD GATE, and say plainly
which app-specific knowledge is unavailable. Add your own app profile by creating
`profiles/<your-app>.md` (see the pattern implied by the generic + framework files) and
registering its repo here.

## Output of discovery

State the detected stack in one line before investigating, e.g.:

> Detected: RSpec / Buildkite / no app profile — loading `frameworks/rspec.md`,
> `ci/buildkite.md`.

If any tier is unknown, say so and note the degraded mode (generic categories only, HARD
GATE unchanged).
