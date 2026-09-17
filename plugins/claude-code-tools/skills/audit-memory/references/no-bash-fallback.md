# Discovery without `Bash`

Sandboxes and eval harnesses routinely deny `Bash`, and a discovery step with no fallback turns that into a dead end. Every step has a tool-only equivalent. Use these, and report that you ran without `Bash`.

| Need | Without `Bash` |
|---|---|
| memory root | the `--root <path>` argument if the caller gave one, resolved against the cwd if relative. **No tool exposes environment variables**, so `CLAUDE_MEMORY_ROOT` is invisible here — if no `--root` was passed, use `~/.claude/projects` and say outright that you audited the default root and could not see whether `CLAUDE_MEMORY_ROOT` was set |
| root exists at all | `Glob` `<root>/*` **before anything else**. Empty means the root is absent *or* empty, and those need opposite responses — an absent root is an error to stop on, an empty one is a clean "nothing to audit". Distinguish them by globbing the parent for the root's own name; if you cannot, say which of the two you could not rule out rather than picking the reassuring one |
| memory files per project | `Glob` `<root>/*/memory/*.md` |
| project → repo | `Grep` pattern `"cwd":\s*"[^"]+"` over `<root>/<project>/*.jsonl`, `output_mode: "content"`, `head_limit: 1` — the transcript's own field, same authority as the script. Keep the `\s*`: transcripts are not always written compactly, and a pattern anchored to `"cwd":"` misses every pretty-printed line, which looks identical to a project having no resolvable repo |
| does the repo exist | `Glob` `<cwd>/*` — non-empty means present |
| file ages | `Read` the memory's `metadata.modified`, and say so if you had no mtime available |

**Escape glob metacharacters in every interpolated path.** The `Glob` patterns above splice a root, project or repo path into a pattern, and `[`, `]`, `?` and `*` are legal in a directory name — `~/src/app[v2]` globs as a character class and silently matches nothing, which is indistinguishable from an absent root. Wrap each such character in brackets (`[[]`, `[?]`, `[*]`) before splicing, and treat an empty result on a path containing one as unresolved rather than absent. The `Bash` path escapes these already (`glob.escape`); this path has to do it by hand.

The rest of the audit needs no shell either: claims verify through `Read`, `Glob` and `Grep`, and edits through `Edit`. Only PR, issue and branch state genuinely requires `gh`/`git`; without them those claims are `NEEDS-gh`, which is honest — never `STALE`.

**Whole-file archival cannot complete on this path.** Removal is a snapshot-then-`rm`, and `rm` needs a shell, so `Edit`/`Write` alone cannot take a file out of the corpus. Do not claim the file was archived. Instead: write the snapshot and the manifest entry as usual, then stub the file — **replace the frontmatter `description` as well as the body**, not the body alone. `description` is the line recall surfaces, so a stub carrying the original one keeps asserting the stale claim to every future session, which is the exact failure the removal was for. But **the stub must not say the file was archived or removed** — it has not been; that is the false report this whole path exists to avoid. Word both lines as *pending*: "superseded — pending removal, snapshot at `<path>`". Keep `name` and the `metadata:` block so the file still parses. Then remove its `MEMORY.md` pointer, and say plainly that the stub remains and needs `Bash` (or a manual `rm`) to finish. A file reported as archived while still sitting in the corpus is the same false-report failure as miscounting writes.

**The root is unconfirmed on this path.** Because `CLAUDE_MEMORY_ROOT` is unreadable, a run that fell back to the default root cannot know it is auditing the corpus the caller meant. Report findings, but make no write of any kind — no archive, no edit, no `lastReviewed` stamp — until the user confirms the root. Findings can be discarded; an archive written against the wrong corpus cannot.
