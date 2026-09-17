# Security — Detailed Criteria

## Scope

No credential exposure in skill instructions. No instructions to paste secrets into the conversation. No instructions that route secrets through the model or to disk in plaintext. No hardcoded secret literals in bundled scripts. No unsafe shell idioms in executable scripts.

"Bundled scripts" here spans both the skill's own `scripts/` **and** the scripts a hook associated with the skill invokes from its plugin `hooks/` — the executable-script and credential checks below apply to hook scripts too. (This is the Security side of the boundary [`hooks.md`](./hooks.md) draws: a secret in hook source is a Security finding, not a Hooks one.)

Security findings always escalate to **Critical** or **Major** — there is no "polish" tier. Credential-paste isn't style; shell injection isn't a nit.

## When This Applies

Severity tiers in scope: **Critical**, **Major**.

- **Critical** — credential exposure in instructions, plaintext credential storage, a hardcoded secret literal in a bundled script, an auth flow that surfaces secrets to the model as text.
- **Major** — security bug in an executable script under `scripts/` or a plugin `hooks/` script (command injection, unquoted expansion, credential leak, path traversal, disabled transport security).
- **Minor** — not in scope. Security findings are not polish.

## Credential Exposure Patterns (Critical)

### Asking the user to paste secrets into the conversation

**Pattern.** Skill body or reference file instructs the user to paste an `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`, an API key, a session token, a password, or any other credential as chat input.

**Severity.** Critical.

**Deterministic.** No — credential strings appear in this skill's own body as anti-pattern examples. The match decision requires context heuristics ("is this in an instruction or a warning?"), which an AI rerun can resolve differently on borderline cases.

**Why it's bad.** Credentials in the conversation transcript are stored, indexed, and potentially shared. They also typically circumvent a secure auth flow the user could have used instead.

**Fix.** Use a non-interactive auth flow that never surfaces credentials as text — one that injects them directly into the command's environment (a subshell, an env var sourced from a secret manager, or an MCP server that handles auth itself), so the secret never appears in the conversation.

### Writing credentials to plaintext temp files

**Pattern.** Skill instructs the user (or Claude) to write credentials to a file under `/tmp/` (or any unprotected path) and source it. Detectable by the combination of `/tmp/*.sh` and `export AWS_*=` / `export <SECRET>=` patterns.

**Severity.** Critical.

**Deterministic.** No — same context-heuristic concern. The `/tmp/*.sh` + `export` co-occurrence is regex-friendly, but anti-pattern examples in skill bodies cause false positives.

**Why it's bad.** Plaintext files in `/tmp/` may be world-readable, may survive reboots on some configurations, and aren't cleaned up reliably.

**Fix.** Use an auth flow that injects credentials directly into the process environment without ever serialising them to disk.

### Auth flow that surfaces secrets to the model

**Pattern.** The skill instructs an interactive or human-only auth flow and then captures its output so the model can read the resulting credentials — e.g. "run `<login>` in a separate terminal, then echo the resulting tokens and paste them back", or piping a credential-printing command into the conversation. The skill claims the model "can't access" the secure flow and routes around it by exposing the secret instead.

This also fires on the narrower trigger **even without an explicit echo-and-paste step**: the skill invokes an *interactive or human-only* auth command — one designed for a person at a terminal (browser-based confirmation, an interactive prompt), not for an automated agent — from inside its own automated flow. Such a command either hangs waiting for interactive input or emits credentials into the session output the model then reads. Naming the wrong (human) auth mode is the defect; the skill does not have to spell out the paste step for the exposure to occur.

**Severity.** Critical.

**Deterministic.** No — recognising that a described flow ends with the model reading a secret requires semantic understanding, not a single regex.

**Fix.** Use the tool's non-interactive / machine auth mode (the one designed for automated agents) that injects credentials into the environment directly, and drop any "echo the token and paste it" step. If no such mode exists, the skill should hand the privileged action to the user rather than capturing their secret.

### Hardcoded secret literal in a bundled script

**Pattern.** A bundled script — under the skill's `scripts/` **or** a plugin `hooks/` script it invokes — contains a live credential in its source: `Authorization: Bearer sk_live_…`, an API key, a fallback token, a DB password. Detectable by reading the script: a secret-shaped literal (`sk_live_`, `Bearer <token>`, `AKIA…`, `xoxb-…`) handed to `curl`, an SDK, or an `export`. This is a common way a hook script exposes a credential — an `async: true` telemetry `PostToolUse` hook that `curl`s an endpoint with an inlined bearer token.

**Severity.** Critical.

**Deterministic.** No — a real secret literal must be told apart from a placeholder (`sk_live_xxx`, `<your-token>`, `${OTEL_TOKEN}`) or an anti-pattern example, which requires reading the surrounding code.

**Why it's bad.** A secret committed into a distributed script is worse than an interactive paste — it ships to every install and lives in git history, so scrubbing the file does not undo the exposure; rotation is the only remedy once merged.

**Fix.** Read the secret from the environment or a secret manager at run time (`"Authorization: Bearer ${OTEL_TOKEN:?}"`), never inline it — and rotate any literal that was ever committed. Produce the corrected snippet as a rewrite.

## Correct Patterns to Recognise as Safe

These are NOT findings — recognise them as the right pattern:

- A non-interactive auth invocation that injects credentials into the command's subshell/environment and never prints them — e.g. `eval "$(some-auth --machine <scope>)" && <command>`.
- MCP tool calls where authentication is handled by the MCP server, not the skill (the server holds the token; the skill never sees it).
- Reconnecting an expired MCP session via the documented reconnect flow rather than capturing a token by hand.

## Security Bugs in Executable Scripts (Major)

All sub-patterns below are **not deterministic** — flagging command injection, unquoted expansion, credential leaks, path traversal, or disabled transport security requires reading the script and understanding its data-flow semantics.

### Command injection in shell scripts

**Pattern.** Script under `scripts/` interpolates user-controlled input into a shell command without quoting. Detectable by reading the script files in the skill folder.

**Severity.** Major.

**Fix.** Quote variable expansions: `"$var"` not `$var`. Use `printf '%s' "$var"` for stricter cases. Prefer arrays for argument lists.

### Unquoted variable expansion

**Pattern.** Shell script has `cmd $var` where `$var` could contain spaces or special characters. Same root cause as command injection but lower exploit surface.

**Severity.** Major.

**Fix.** Quote: `cmd "$var"`.

### Credential leak in script output

**Pattern.** Shell script prints `$AWS_SECRET_ACCESS_KEY` or a similar secret to stdout/stderr, or writes it to a log file.

**Severity.** Major.

**Fix.** Never print credentials. Mask if you must reference them: `echo "Using key ${AWS_ACCESS_KEY_ID:0:4}…"`.

### Path traversal

**Pattern.** Script accepts a path argument and uses it without validating it stays within the expected directory. `rm -rf "$user_path"` is the worst case.

**Severity.** Major.

**Fix.** Validate the path with `realpath` and check it has the expected prefix before any destructive operation.

### Transport security disabled

**Pattern.** A bundled script turns off TLS / certificate verification on a network call: `verify=False` (Python `requests`), `ssl_verify_peer: false`, `curl -k` / `curl --insecure`, `rejectUnauthorized: false` (Node), `InsecureSkipVerify: true` (Go), or an equivalent flag that suppresses cert checking against a remote host. The connection is then open to a man-in-the-middle: any party on the path can impersonate the endpoint and read or tamper with the traffic, including credentials and production data in the request/response.

**Severity.** Major.

**Deterministic.** No — the literal flag is regex-detectable, but distinguishing a real production MITM exposure from a deliberate localhost / self-signed-dev-cert context, or from an anti-pattern example, requires reading the surrounding code and its target host.

**Fix.** Leave verification on (`verify=True` / drop the `-k` / drop `rejectUnauthorized: false`). If the target is an internal host with a private CA, trust that CA explicitly (`verify="/path/to/ca-bundle.pem"`, `--cacert`, `NODE_EXTRA_CA_CERTS`) rather than disabling verification globally. Show the corrected call.

## Out of Scope / False-Positive Guardrails

- **Anti-pattern examples in skill bodies are not credential exposure.** A skill that contains the strings `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN` as **descriptions of what NOT to do** is teaching, not instructing. Detection must use context: is the string in an instruction telling the user to do something, or in a "do not" warning? If the surrounding text frames it as wrong, it's not a finding.
- **Plain mention of "paste" is not a finding.** Skills often say "paste the URL" or "paste the build ID" — only flag when "paste" is associated with credential strings.
- **Bundled-script security review requires reading the actual scripts.** Don't speculate about script content from SKILL.md alone. If the skill folder has executable scripts under `scripts/`, or an associated hook invokes a plugin `hooks/` script, and they're security-relevant, read them.
- **A documented localhost / dev-only TLS-disable is not the transport-security finding.** A `verify=False` scoped to `https://localhost` or a self-signed dev cert, clearly framed as dev-only, is not a production MITM exposure — and an anti-pattern example (this file names the disabling flags as things NOT to do) is teaching, not a finding. Flag transport-security-disabled only when a real remote/production call has verification suppressed.

## Rewrite Policy

**Produce a suggested rewrite for executable-script bugs (the Major-tier finding types) and for a hardcoded secret literal in a bundled script (Critical).** Show the fixed code inline — quoted expansions, masked credential output, `realpath` validation, re-enabled TLS verification (or an explicit private-CA bundle), an env-read `"Bearer ${TOKEN:?}"` in place of an inlined secret, etc. The rewrite lives inside the finding it addresses (collapsible details block per [`suggested-rewrites.md`](./suggested-rewrites.md)).

**For credential-exposure Critical findings, describe the fix in prose.** Name the secure replacement explicitly — a non-interactive auth flow that injects credentials into the command environment (so they live only in the process/subshell, never in the conversation transcript or on disk) — and explain why. Do not generate a full rewrite of the surrounding skill section; the author needs to choose where the auth invocation belongs.

## Notes for Implementers

- For the credential-paste patterns, detection is FP-prone: anti-pattern examples in skill bodies (showing what NOT to do) fire false positives. Use context to distinguish instructions from warnings before flagging.
- The safe pattern is always the same shape regardless of tool: credentials enter the process environment through a machine/non-interactive flow and are never serialised to the conversation or to disk. Recognise that shape and pass it.
