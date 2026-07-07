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

**This skill exists to call `upload.sh`. If it is loaded with a local file path in context, you MUST run the script — do not describe the flow, do not propose markdown without uploading, do not stop after acknowledging the request.** The only correct trajectory ends with a `gh`/`curl`-backed upload and a returned asset URL.

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

### Step 2: Run the upload script — once per file

```bash
${CLAUDE_PLUGIN_ROOT}/skills/attach-github-assets/scripts/upload.sh "<file-path>"
```

The script auto-detects the repo ID from `git remote` and MIME type from extension. Returns the asset URL on stdout, exits non-zero on failure.

To override repo ID (e.g. uploading from a worktree whose remote isn't the target repo):

```bash
${CLAUDE_PLUGIN_ROOT}/skills/attach-github-assets/scripts/upload.sh "<file-path>" <repo_id>
```

Run the script **once per file** — never batch into a single invocation, never substitute `curl` or a different upload mechanism.

### Step 3: Return markdown for the returned URL(s)

- **Images** (png, jpg, jpeg, gif, webp, svg) → `![{filename}]({url})`
- **Videos** (mov, mp4, webm) → paste the URL on its own line; GitHub auto-renders video URLs and `![]()` would break that.

## Examples

- `/attach-github-assets ~/Desktop/screenshot.png`
- `/attach-github-assets /tmp/before.png /tmp/after.png`
