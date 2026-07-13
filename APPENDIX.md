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
- [Async override surfaces grouped; universal ones stay flat](#async-surfaces-holder)
- [Sync search: flat input, a pure resolver](#sync-search-shape)
- [Async search: one controller, two views](#async-two-view-search)
- [Observer seam: async-only, no-op-method sink](#observer-seam)

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
  (<https://github.com/orgs/flutter/projects/220>), so the widgets layer is where a design-neutral
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
  by feature within each (`data/pagination/`, `data/search/`, ...), then **by kind again within a
  feature** (`models/`, `typedefs/`, `enums/`, `extensions/`, `utils/`), one primary public symbol
  per file. Sealed cases nest one level under the base's kind and stay `part`s of it
  (`models/policies/`, `source/sources/`). The third level was adopted as each feature's vocabulary
  grew past a couple of files; a small feature stays flat until it earns the split.
- **Why:** it matches the maintainer's existing Flutter packages (`platform_adaptive_widgets` and
  `smart_search_list` both use `models/` + `widgets/` + a helpers folder), so a contributor moving
  between the packages meets the same shape. By-kind at the top keeps data separate from behaviour;
  by-feature keeps a concern's pieces together; by-kind within a feature keeps a grown feature
  scannable (all its typedefs in one place, its policy cases in another).
- **Rejected:** *top-level* `enums/` / `typedefs/` folders (`lib/src/typedefs/`), which scatter one
  feature's vocabulary across the whole tree. The by-kind split is deliberately scoped *within* a
  feature, so a feature stays self-contained; and a typedef with a single home type still lives in
  that type's file (`RefreshBuilder` with `ListSmithRefreshState`), never pulled out just to fill a
  `typedefs/` folder.
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

<a id="async-surfaces-holder"></a>
## Async override surfaces grouped; universal ones stay flat

- **Decision:** the async-only override surfaces (first/new-page loading, first/new-page error, the
  end-of-list footer, and the pull-to-refresh indicator) are bundled into one `AsyncListSurfaces`
  holder, passed as a single `surfaces:` argument. Surfaces every list has, `emptyBuilder` now (and
  `noResultsBuilder` with search), stay flat constructor parameters. The `pullToRefresh` on/off flag
  stays flat too; only its indicator builder sits in the holder.
- **The rule (Rule X):** a surface is a flat parameter if *every* list has it, and moves into the
  async holder if *only async* lists have it. Behaviour flags (`pullToRefresh`, `pageSize`,
  `endPolicy`) are not surfaces and stay flat regardless.
- **Why:** the `.async` constructor had grown seven optional builders that buried the behavioural
  parameters (`fetchPage`, `pageSize`, `endPolicy`). Grouping them mirrors what `ListScrollConfig`
  does for the scrollable's knobs, shortens the call site, and lets a consumer define one surface set
  and reuse it across lists. Autocomplete still lists every slot inside `AsyncListSurfaces(...)`, so
  discoverability holds.
- **Why not group every surface** (including `emptyBuilder`): the sync search path has an empty state
  but none of the async surfaces. A single shared holder would put the six async-only builders where
  a `.sync` list could set them and see nothing happen, the ghost-parameter bug list_smith exists to
  remove. Keeping universal surfaces flat means they read the same on `.async` and `.sync`, and the
  holder stays honestly async-only.
- **Landed in** the Step 2a refactor, alongside extracting the async engine into the unexported
  `AsyncListView` and making `ListSmith` a stateless dispatcher over the sealed `ListSource`.

---

<a id="sync-search-shape"></a>
## Sync search: flat input, a pure resolver, universal surfaces stay flat

- **Decision:** the `.sync` constructor takes its search input (`query`, `minSearchLength`,
  `searchDebounce`) as flat parameters, not a `SearchConfig` holder, even though the override
  surfaces were just grouped into `AsyncListSurfaces`.
- **Why flat, not a holder:** the cases differ. `AsyncListSurfaces` groups override builders a
  consumer sets once and rarely touches; `query` is the opposite, changing on essentially every
  rebuild, so burying the most-changed parameter in a holder reads badly. The debounce default also
  diverges by path (`Duration.zero` sync, 300ms async), which flat per-constructor defaults express
  cleanly and one shared holder could not.
- **Pure resolver:** the trim + min-length gating and predicate filtering live in a widget-free
  `resolveSyncSearch(...)` returning `(visibleItems, isSearching)`, unit-tested directly. This
  mirrors `PaginationEndPolicyResolver`: the branchy logic (an empty or too-short query shows
  everything; an active query with no matches is the no-results surface) is tested without a widget.
- **Surfaces stay flat:** `emptyBuilder` (source empty) and `noResultsBuilder` (search matched
  nothing) are flat and shared with the async path, per Rule X (see
  [#async-surfaces-holder](#async-surfaces-holder)); a sync list carries none of the async surfaces,
  so `.sync` takes no `AsyncListSurfaces`.
- **Materialisation:** `SyncSource` keeps the consumer's raw iterable; `SyncListView` materialises it
  once and re-materialises only when the iterable identity changes, so an unchanged list is not
  re-copied or re-filtered per build.
- **`scrollCacheExtent`, not `cacheExtent`:** Flutter 3.44 deprecated `ScrollView.cacheExtent`
  (`double`) for `scrollCacheExtent` (`ScrollCacheExtent`). `ListScrollConfig.cacheExtent` stays a
  public `double?` in logical pixels; `SyncListView` wraps it via `ScrollCacheExtent.pixels(...)` and
  imports `ScrollCacheExtent` from `package:flutter/rendering.dart` (rendering is the widgets layer's
  own foundation, not a design system, so the no-Material/Cupertino rule is unaffected). The async
  path is untouched: ISP's `PagedListView` has its own, non-deprecated `cacheExtent`.

---

<a id="async-two-view-search"></a>
## Async search: one controller, two views

- **Decision:** async search rides a single `PagingController`. A mode-aware fetch closure reads the
  debounced committed query: empty runs the normal `fetchPage`, non-empty runs `searchFetchPage`.
  Search is opt-in (a null `searchFetchPage` is a plain pagination list), and search mode requires
  both a non-empty query and a fetcher.
- **Why one controller, not two:** pagination and pull-to-refresh then compose for free, one end
  policy and one `refresh()` serve both modes, and there is no second controller to keep in sync.
  `refresh()` re-reads the query, so pulling to refresh in search mode reloads the current search.
- **Cache policy is a pure decision plus an impure execution.** On a committed-query change,
  `SearchCachePolicy.actionFor(wasSearching, isSearching)` returns a `CacheAction`
  (`refresh` / `snapshotThenRefresh` / `restoreNormal`). That decision is widget- and controller-free,
  so it is unit-tested directly (the `PaginationEndPolicyResolver` split again); the view executes it
  against the controller. `Keep` snapshots `controller.value` on entering search and restores it on
  leaving (an instant return, no refetch); `Replace` always refetches; a search-to-search change
  refetches under either policy.
- **Safety of `searchFetchPage!`:** search mode is `query.isNotEmpty && source.supportsSearch`, so the
  fetch closure only calls `searchFetchPage!` when it is non-null. A query set without a fetcher trips
  an `assert` in debug and degrades to normal pagination in release, not a null-check crash.
- **Shared `QueryDebouncer`:** the debounce (timer, trim, skip-unchanged) was extracted from
  `SyncListView` into an unexported helper both views own (a 2c refactor-first step). The owner seeds
  the initial query synchronously and schedules each later change; a zero-debounce change commits on
  the next tick, which removed a `setState`-during-`didUpdateWidget` hazard the async path would hit.

---

<a id="observer-seam"></a>
## Observer seam: async-only, no-op-method sink

- **Decision:** an optional `ListSmithObserver` injected via `ListSmith.async(observer: ...)`,
  modelled on `better_internet_connectivity_checker`'s `ConnectivityObserver`: an `abstract base
  class` with a no-op default body per event, so a subclass overrides only what it wants and
  unhandled events cost nothing. Five events, all async: `onPageLoaded`, `onError`, `onRefresh`,
  `onQueryCommitted`, `onSearchModeChanged`. A default `LoggingListSmithObserver` logs each via
  `dart:developer`.
- **Discrete events only.** The seam fires from callbacks that run outside `build` (the page fetch,
  the refresh gesture, the debounced-query commit), never from render-derived state. So no-results,
  empty, and end-reached are excluded on purpose: they exist only as a function of the paging/filter
  state during `build`, and firing an observer there would re-fire on every rebuild and risk a
  `setState`-during-build. end-reached is the one worth revisiting, but it needs a latched,
  post-frame dispatch, which is more machinery than the discrete events carry.
- **Async-only, not shared with `.sync`.** The observer earns its place by surfacing what the hidden
  controller keeps out of reach (fetch results, errors, refresh, the debounced commit and mode
  flip). A sync list has no controller, fetch, or refresh, and the consumer owns the query it
  filters on, so there is nothing worth observing. Putting an observer on `.sync` would be the
  ghost-parameter mistake Rule X (see [#async-surfaces-holder](#async-surfaces-holder)) exists to
  avoid; a `SyncListSmithObserver` stays an additive option if a real use case appears.
- **Fully hidden, non-generic.** Every callback takes plain values (`int` indices and counts, the
  `String` query, `Object` / `StackTrace`), never `PagingController`, `PagingState`, or the ISP
  generics, so wiring diagnostics can't reach an internal handle (holds decision 3). Non-generic (no
  items in the payload): logging and analytics want counts and mode, a non-generic observer is far
  easier to subclass, and the package being unpublished keeps a generic variant open if items are
  ever wanted.
- **`abstract base`, extend-only.** Guarantees a new lifecycle event can ship as a no-op method in a
  later minor release without breaking existing subclasses. It's a **dispatch** seam, not a decision
  seam (the only decision, the mode flip, is the transition `SearchCachePolicyResolver` already
  owns), so it carries no new pure resolver; it is covered by widget tests driving a
  `RecordingListSmithObserver`.

---

**TODO (design pass and beyond).** Decisions still to be recorded here as they land, for example:
the SDK floor rationale, the public API surface and why it's shaped that way, how sync vs async
data sources are modelled, the search / cache interplay policy, and what `list_smith` deliberately
does *not* do (learning from the `smart_search_list` pitfalls it replaces).
