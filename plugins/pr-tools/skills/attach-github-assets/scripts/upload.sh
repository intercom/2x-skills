#!/bin/bash
# Usage: ./upload.sh <file-path> [repository_id]
# Requires: gh, curl, jq
set -euo pipefail

SUPPORTED="png, jpg, jpeg, gif, webp, svg, mov, mp4, webm"

usage() {
  cat >&2 <<'EOF'
Usage:
  upload.sh <file-path> [repository_id]
      Upload one file and print its asset URL.

  upload.sh --post-to <pr|issue>:<number> [--repo OWNER/REPO] [--body TEXT] <file-path>...
      Upload files and post them as one comment, preferring `gh ... --attach`.
EOF
}

die() {
  echo "Error: $*" >&2
  exit 1
}

mime_for() {
  case "$(printf '%s' "${1##*.}" | tr '[:upper:]' '[:lower:]')" in
    png) echo image/png ;;
    jpg | jpeg) echo image/jpeg ;;
    gif) echo image/gif ;;
    webp) echo image/webp ;;
    svg) echo image/svg+xml ;;
    mov) echo video/quicktime ;;
    mp4) echo video/mp4 ;;
    webm) echo video/webm ;;
    *) return 1 ;;
  esac
}

# bash 3.2 (macOS default) mishandles quoting in ${var//pattern/repl}, so this replaces literally.
replace_all() {
  local hay="$1" needle="$2" repl="$3" out=""
  while [[ "$hay" == *"$needle"* ]]; do
    out="${out}${hay%%"$needle"*}${repl}"
    hay="${hay#*"$needle"}"
  done
  printf '%s' "${out}${hay}"
}

validate_file() {
  [[ -f "$1" ]] || die "File not found: $1"
  mime_for "$1" >/dev/null || die "Unsupported file type '.${1##*.}'. Supported: $SUPPORTED"
}

resolve_repo_id() {
  local slug="$1" id
  if [[ -z "$slug" ]]; then
    slug=$(git remote get-url origin 2>/dev/null |
      sed -E 's#(git@github\.com:|https://github\.com/)##; s#\.git$##')
    [[ -n "$slug" ]] || die "Could not detect repository. Pass a repository_id, or --repo OWNER/REPO."
  fi
  id=$(gh api "repos/$slug" --jq .id 2>/dev/null) || die "Could not resolve repository id for $slug."
  echo "$id"
}

upload_one() {
  local file="$1" repo_id="$2" name mime encoded_name encoded_mime token response code body url

  token=$(gh auth token 2>/dev/null) || die "gh auth token failed. Run 'gh auth login' first."

  name=$(basename "$file")
  mime=$(mime_for "$name")
  encoded_name=$(printf '%s' "$name" | jq -sRr @uri)
  encoded_mime=$(printf '%s' "$mime" | jq -sRr @uri)

  response=$(curl -s -w "\n%{http_code}" \
    "https://uploads.github.com/user-attachments/assets?name=${encoded_name}&content_type=${encoded_mime}&repository_id=${repo_id}" \
    -X POST \
    -H "Content-Type: application/octet-stream" \
    -H "Accept: application/json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    -H "Authorization: Bearer $token" \
    --data-binary "@$file")

  code=$(echo "$response" | tail -1)
  body=$(echo "$response" | sed '$d')
  [[ "$code" == "201" ]] || die "Upload failed with HTTP $code: $body"

  url=$(echo "$body" | jq -r '.url // empty')
  [[ -n "$url" ]] || die "No URL in response: $body"
  echo "$url"
}

POST_TO=""
REPO_SLUG=""
BODY=""
FILES=()

need() { [[ $# -ge 2 && -n "$2" ]] || die "$1 needs a value"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --post-to)
      need "$@"
      POST_TO="$2"
      shift 2
      ;;
    --repo)
      need "$@"
      REPO_SLUG="$2"
      shift 2
      ;;
    --body)
      need "$@"
      BODY="$2"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    --*)
      usage
      die "Unknown flag: $1"
      ;;
    *)
      FILES+=("$1")
      shift
      ;;
  esac
done

if [[ -z "$POST_TO" ]]; then
  [[ ${#FILES[@]} -gt 0 ]] || {
    usage
    exit 1
  }
  validate_file "${FILES[0]}"
  REPO_ID="${FILES[1]:-}"
  [[ -n "$REPO_ID" ]] || REPO_ID=$(resolve_repo_id "")
  upload_one "${FILES[0]}" "$REPO_ID"
  exit 0
fi

KIND="${POST_TO%%:*}"
NUMBER="${POST_TO#*:}"
[[ "$KIND" == "pr" || "$KIND" == "issue" ]] || die "--post-to must be pr:<number> or issue:<number>, got '$POST_TO'"
[[ "$NUMBER" =~ ^[1-9][0-9]*$ ]] || die "--post-to needs a positive number, got '$NUMBER'"
[[ ${#FILES[@]} -gt 0 ]] || die "--post-to needs at least one file"
# gh caps --attach at 50; enforced here so the outcome doesn't depend on the installed gh.
[[ ${#FILES[@]} -le 50 ]] || die "--post-to takes at most 50 files, got ${#FILES[@]}. Split them across calls."

# Uploads can't be undone, so validate every file before uploading any.
for f in "${FILES[@]}"; do
  validate_file "$f"
done

REPO_FLAG=()
[[ -n "$REPO_SLUG" ]] && REPO_FLAG=(--repo "$REPO_SLUG")

GH_ARGS=("$KIND" comment "$NUMBER" ${REPO_FLAG[@]+"${REPO_FLAG[@]}"})

if gh "$KIND" comment --help 2>/dev/null | grep -q -- '--attach'; then
  [[ -n "$BODY" ]] && GH_ARGS+=(--body "$BODY")
  for f in "${FILES[@]}"; do
    GH_ARGS+=(--attach "$f")
  done
else
  # No --attach: upload and compose ourselves. Refuse two body forms gh's markdown
  # machinery would rewrite (reference-style links, video-as-image-embed) rather than diverge.
  for f in "${FILES[@]}"; do
    if [[ "$BODY" =~ \][[:space:]]*:[[:space:]]*"$f" ]]; then
      die "This gh has no --attach, and a reference-style link to $f cannot be rewritten faithfully. Upgrade gh to 2.99.0+, or write the reference as [alt]($f)."
    fi
    if [[ "$BODY" == *"!["*"]($f)"* && "$(mime_for "$f")" == video/* ]]; then
      die "This gh has no --attach, and a video written as an image embed cannot be rewritten faithfully. Upgrade gh to 2.99.0+, write it as [alt]($f), or drop the reference and let it be appended."
    fi
  done

  # Confirm the target exists first — a wrong number would orphan every upload.
  gh "$KIND" view "$NUMBER" ${REPO_FLAG[@]+"${REPO_FLAG[@]}"} --json id >/dev/null 2>&1 ||
    die "No $KIND #$NUMBER to comment on${REPO_SLUG:+ in $REPO_SLUG}."

  REPO_ID=$(resolve_repo_id "$REPO_SLUG")
  COMPOSED="$BODY"
  for f in "${FILES[@]}"; do
    url=$(upload_one "$f" "$REPO_ID")
    REF="]($f)"
    if [[ "$COMPOSED" == *"$REF"* ]]; then
      # Match gh --attach: repoint an existing reference rather than appending a copy.
      COMPOSED=$(replace_all "$COMPOSED" "$REF" "]($url)")
    elif [[ "$(mime_for "$f")" == video/* ]]; then
      # A video URL must stand alone for GitHub to render it; ![](…) breaks that.
      COMPOSED="${COMPOSED}"$'\n\n'"${url}"
    else
      COMPOSED="${COMPOSED}"$'\n\n'"![$(basename "$f")]($url)"
    fi
  done
  GH_ARGS+=(--body "$COMPOSED")
fi

exec gh "${GH_ARGS[@]}"
