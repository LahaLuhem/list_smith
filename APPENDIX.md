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
- [Consumer-facing surfaces impose no design system](#design-system-agnostic)
- [`lib/src/` directory layout](#src-directory-layout)
- [Pull-to-refresh resets the list on V1](#pull-to-refresh-resets-v1)

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

<a id="design-system-agnostic"></a>
## Consumer-facing surfaces impose no design system

- **Decision:** list_smith's own code, and every default it ships for a visible surface (loading,
  error, empty, "no more items", the pull-to-refresh indicator, and the search field where the
  package owns it), are built on `package:flutter/widgets.dart` only, never `material.dart` or
  `cupertino.dart`. Every visible surface stays overridable by the consumer; the defaults we ship in
  their place are neutral, widgets-layer widgets.
- **Scope is our surfaces, not the dependency closure.** A dependency may import Material internally
  (`infinite_scroll_pagination`'s default indicators do). We neutralise it by overriding *every*
  default builder slot it exposes, so no Material widget appears in list_smith's own default look
  and feel. Migrating that dependency's internal Material use once Flutter unbundles Material from
  the SDK is the dependency's problem, not ours.
- **Why:** two reasons. Developer experience: list_smith should drop into a Material app, a
  Cupertino app, or a bespoke design system without importing a look the consumer never chose.
  Forward-compatibility: Flutter is decoupling `material` / `cupertino` from the framework core
  (https://github.com/orgs/flutter/projects/220), so the widgets layer is where a design-neutral
  package belongs.
- **Consequences:** the widgets layer ships no progress spinner, so our neutral loading and refresh
  defaults are small widgets-layer implementations (for example a `CustomPainter`), not
  `CircularProgressIndicator`. And when wrapping a dependency that ships Material defaults, leaving
  any of its default-builder slots null is a defect: the Material default leaks onto our surface, so
  fill every slot.

---

<a id="src-directory-layout"></a>
## `lib/src/` directory layout

- **Decision:** organise `lib/src/` by kind at the top level (`data/`, `widgets/`, `utils/`), then
  by feature within each (`data/refresh/`, `widgets/defaults/`, ...), one primary public class per
  file.
- **Why:** it matches the maintainer's existing Flutter packages (`platform_adaptive_widgets` and
  `smart_search_list` both use `models/` + `widgets/` + a helpers folder), so a contributor moving
  between the packages meets the same shape. By-kind at the top keeps data separate from behaviour;
  by-feature within keeps a concern's pieces together.
- **Rejected:** top-level `enums/` / `typedefs/` folders. They scatter one cohesive vocabulary (a
  typedef, the model it builds, and the enum it carries) across three folders.
- **`data/` over `models/`:** the folder also holds enums and typedefs, which are not models. Public
  types stay unexported from `lib/list_smith.dart` until the widget shell lands, so the whole public
  surface appears in one place at one time.

---

<a id="pull-to-refresh-resets-v1"></a>
## Pull-to-refresh resets the list on V1

- **Decision (V1):** on refresh, the wrapped controller's `refresh()` resets the paging state, so
  the list clears and the first-page loader shows while the fresh page loads. `onRefresh` completes
  as soon as the refresh is triggered, so the pull indicator retracts right away (the standard
  infinite_scroll_pagination pattern).
- **Why not hold the indicator until fresh data:** awaiting the reload would keep the pull
  indicator on screen *while* the reset also shows the first-page loader, i.e. two spinners at
  once. Completing immediately keeps one indicator visible at a time.
- **Deferred (WIP):** a "keep the old items visible, hold the pull indicator until fresh data
  arrives, then swap" behaviour is nicer, but needs a soft refresh that doesn't reset up front.
  Revisit post-V1; it likely rides on a dedicated refresh-policy seam.

---

**TODO (design pass and beyond).** Decisions still to be recorded here as they land, for example:
the SDK floor rationale, the public API surface and why it's shaped that way, how sync vs async
data sources are modelled, the search / cache interplay policy, and what `list_smith` deliberately
does *not* do (learning from the `smart_search_list` pitfalls it replaces).
