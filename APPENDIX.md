# APPENDIX for `list_smith`

Design rationale: the "why" behind decisions that the code and the hard rules alone don't explain.
Hard rules and workflow live in [`.ai/AGENTS.md`](.ai/AGENTS.md); code style in
[`CODESTYLE.md`](CODESTYLE.md). Each heading carries an explicit `<a id="…">` anchor; link by
anchor, and keep anchors stable across renames.

This is a decision log. It's mostly empty on purpose: the library's API and architecture haven't
been designed yet, so the rationale for those decisions doesn't exist to record. Entries get added
as decisions are actually made, not pre-emptively. The one entry below covers a decision made
during the repository setup itself.

<!-- TOC start -->

- [`AGENTS.md` and `CLAUDE.md` are symlinks into `.ai/`](#ai-files-symlinked)

<!-- TOC end -->

<a id="ai-files-symlinked"></a>
## `AGENTS.md` and `CLAUDE.md` are symlinks into `.ai/`

- **Decision:** the canonical text for both files lives under [`.ai/`](.ai/). The repo root holds
  symlinks (`AGENTS.md -> .ai/AGENTS.md`, `CLAUDE.md -> .ai/CLAUDE.md`).
- **Why:** Claude Code and most other coding agents auto-discover `CLAUDE.md` / `AGENTS.md` at the
  project root, but two more loose Markdown files at the root add noise to the file tree. Scoping
  them under `.ai/` keeps the agent-facing docs together; the root symlinks preserve
  auto-discovery. `.gitignore` ignores the root symlinks and commits the `.ai/` targets;
  `.pubignore` excludes both so none of it ships in the published tarball.
- **Cross-platform note:** symlinks survive `git clone` on macOS and Linux. On a Windows host
  without symlink support enabled, the file may show up as a small text file containing the link
  target. If that ever bites a contributor, the fallback is to drop the symlinks and keep real
  files at the root, hand-syncing the content.

---

**TODO (design pass and beyond).** Decisions still to be recorded here as they land, for example:
the SDK floor rationale, the public API surface and why it's shaped that way, how sync vs async
data sources are modelled, the search / cache interplay policy, and what `list_smith` deliberately
does *not* do (learning from the `smart_search_list` pitfalls it replaces).
