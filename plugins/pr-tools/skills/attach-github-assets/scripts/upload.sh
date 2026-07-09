#!/bin/bash
# Usage: ./upload.sh <file-path> [repository_id]
# Requires: gh, curl, jq
set -euo pipefail

FILE_PATH="${1:-}"
REPO_ID="${2:-}"

if [[ -z "$FILE_PATH" ]]; then
  echo "Usage: upload.sh <file-path> [repository_id]" >&2
  exit 1
fi

if [[ ! -f "$FILE_PATH" ]]; then
  echo "Error: File not found: $FILE_PATH" >&2
  exit 1
fi

# Get auth token
TOKEN=$(gh auth token 2>/dev/null) || {
  echo "Error: gh auth token failed. Run 'gh auth login' first." >&2
  exit 1
}

# Auto-detect repo ID if not provided
if [[ -z "$REPO_ID" ]]; then
  # Try to get owner/repo from git remote
  REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
  if [[ -n "$REMOTE_URL" ]]; then
    # Extract owner/repo from SSH or HTTPS remote URL
    OWNER_REPO=$(echo "$REMOTE_URL" | sed -E 's#(git@github\.com:|https://github\.com/)##; s#\.git$##')
    REPO_ID=$(gh api "repos/$OWNER_REPO" --jq '.id' 2>/dev/null || echo "")
  fi

  if [[ -z "$REPO_ID" ]]; then
    echo "Error: Could not detect repository ID. Pass it as second argument." >&2
    exit 1
  fi
fi

# Determine MIME type from extension
FILENAME=$(basename "$FILE_PATH")
EXT="${FILENAME##*.}"
EXT_LOWER=$(echo "$EXT" | tr '[:upper:]' '[:lower:]')

case "$EXT_LOWER" in
  png)  MIME="image/png" ;;
  jpg|jpeg) MIME="image/jpeg" ;;
  gif)  MIME="image/gif" ;;
  webp) MIME="image/webp" ;;
  svg)  MIME="image/svg+xml" ;;
  mov)  MIME="video/quicktime" ;;
  mp4)  MIME="video/mp4" ;;
  webm) MIME="video/webm" ;;
  *)
    echo "Error: Unsupported file type '.$EXT_LOWER'. Supported: png, jpg, jpeg, gif, webp, svg, mov, mp4, webm" >&2
    exit 1
    ;;
esac

# URL-encode filename and mime type
ENCODED_NAME=$(printf '%s' "$FILENAME" | jq -sRr @uri)
ENCODED_MIME=$(printf '%s' "$MIME" | jq -sRr @uri)

# Upload
RESPONSE=$(curl -s -w "\n%{http_code}" \
  "https://uploads.github.com/user-attachments/assets?name=${ENCODED_NAME}&content_type=${ENCODED_MIME}&repository_id=${REPO_ID}" \
  -X POST \
  -H "Content-Type: application/octet-stream" \
  -H "Accept: application/json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  -H "Authorization: Bearer $TOKEN" \
  --data-binary "@$FILE_PATH")

# Split response body and HTTP status
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [[ "$HTTP_CODE" != "201" ]]; then
  echo "Error: Upload failed with HTTP $HTTP_CODE" >&2
  echo "$BODY" >&2
  exit 1
fi

# Extract URL from response
URL=$(echo "$BODY" | jq -r '.url // empty')
if [[ -z "$URL" ]]; then
  echo "Error: No URL in response: $BODY" >&2
  exit 1
fi

# Output the URL
echo "$URL"
