---
name: attach-github-assets
description: Upload local files (screenshots, screen recordings, images, videos) to GitHub as user-attachment assets and return markdown-ready URLs for PR descriptions, issue bodies, or PR/issue comments.
metadata:
  user-invocable: true
  argument-hint: "<file-path> [additional-file-paths...]"
  keywords:
    - pr-image
allowed-tools: Bash Read Glob
---

# Attach GitHub Assets

Upload local files to GitHub via `uploads.github.com/user-attachments/assets`.

## Contract: if loaded, run the script

**This skill exists to call `upload.sh`. If it is loaded with a local file path in context, you MUST run the script — do not describe the flow, do not propose markdown without uploading, do not stop after acknowledging the request.** The only correct trajectory ends with a `gh`/`curl`-backed upload and either a returned asset URL or a posted comment.

If no local file path is present and none can be inferred from conversation, output `no-op: no local file path` and exit — do NOT call `upload.sh` with a placeholder, a remote URL, or a guessed path.

## When to Self-Invoke

Self-invoke ONLY when **all** of the following hold:

1. The user (or a calling skill) references a concrete **local** file path — absolute (`/tmp/...`, `~/Desktop/...`) or relative to cwd — for an image (png, jpg, jpeg, gif, webp, svg) or video (mov, mp4, webm).
2. The destination is GitHub — a PR body, issue body, PR/issue comment, or `/create-sub-issues` flow.

Canonical triggers:
- User pastes a local screenshot/recording path and asks to put it on a PR/issue.
- A PR-creation flow is producing a body and the conversation already contains visual context (e.g. QA screenshots, extracted video frames).

## When NOT to invoke

- The change is backend/logic only and no images or recordings have been mentioned. *Most PR-creation prompts in this category never need this skill — do not load it speculatively.*
- The user references a remote URL (already on GitHub, Slack, S3, etc.). The script only handles local files.
- No file path appears in the conversation. "Should I add a screenshot?" is a question, not an invocation.
- The file is not a supported type (see `upload.sh` for the list — only image/video formats are accepted).

If you have been loaded but none of the "When to Self-Invoke" conditions are met, emit `no-op: <reason>` and return control. This is the script-first path; staying loaded without uploading is the failure mode.

## Flow

### Step 1: Resolve file path(s)

- If `$ARGUMENTS` is set, use those file path(s) verbatim — one per upload.
- Otherwise, scan the recent conversation for local image/video paths. Use only paths the user actually referenced; do not invent paths.

`upload.sh` itself errors on missing files (`File not found: <path>`), so do not pre-gate on existence — pass the user's path through and surface the script's error verbatim if it fails.

### Step 2: Run the upload script

The script has two modes. Pick by one fact — **where do the files have to end up?** Never by weighing mechanisms: the script chooses between native `gh --attach` and a direct upload itself, so there is nothing to decide beyond the mode.

**A new comment on a named issue or PR** → post it in one call, all files at once:

```bash
${CLAUDE_PLUGIN_ROOT}/skills/attach-github-assets/scripts/upload.sh \
  --post-to <pr|issue>:<number> [--repo OWNER/REPO] [--body "<text>"] "<file-path>" ["<other-file>" ...]
```

Prints the comment URL. Use `pr:` for a pull request and `issue:` for an issue — the wrong one errors. This mode uses `gh ... comment --attach` when the installed `gh` has it (v2.99.0+) and otherwise uploads and composes the body itself; both produce the same comment, so no version check is needed here.

**Anywhere else** → print the asset URL, **once per file**, for embedding in a body assembled elsewhere:

```bash
${CLAUDE_PLUGIN_ROOT}/skills/attach-github-assets/scripts/upload.sh "<file-path>"
```

The script auto-detects the repo ID from `git remote` and MIME type from extension. Returns the asset URL on stdout, exits non-zero on failure.

To override repo ID (e.g. uploading from a worktree whose remote isn't the target repo):

```bash
${CLAUDE_PLUGIN_ROOT}/skills/attach-github-assets/scripts/upload.sh "<file-path>" <repo_id>
```

In this mode run the script **once per file** — never batch into a single invocation, because the second positional argument is read as the repo ID. Never substitute `curl`, a bare `gh` command, or any other upload mechanism for the script.

A named PR or issue does **not** by itself mean `--post-to`. A **PR or issue body** — "put these in PR #123's description", "add this to the issue body" — is this mode, not the comment mode: `--post-to` writes a separate comment and returns no URL, so the body it was meant for would stay unchanged. Use this mode for a body, and let whoever owns that body write the markdown from Step 3 into it.

### Step 3: Return markdown for the returned URL(s)

Only for the no-target mode; `--post-to` has already written the comment.

- **Images** (png, jpg, jpeg, gif, webp, svg) → `![{filename}]({url})`
- **Videos** (mov, mp4, webm) → paste the URL on its own line; GitHub auto-renders video URLs and `![]()` would break that.

## Examples

- `/attach-github-assets ~/Desktop/screenshot.png`
- `/attach-github-assets /tmp/before.png /tmp/after.png`
