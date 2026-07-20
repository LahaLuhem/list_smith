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
- [Grouping: erased key, sync buckets, async pre-sorted](#grouping-shape)
- [Grouping dispatches on the type; the views don't branch](#grouping-polymorphic-dispatch)
- [Explicit end signals: open policy plus fetcher building block](#explicit-end-signals)

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
- **Why:** it matches the maintainer's existing Flutter packages (`platform_adaptive_widgets` uses
  `models/` + `widgets/` + a helpers folder), so a contributor moving between the packages meets
  the same shape. By-kind at the top keeps data separate from behaviour;
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

- **Decision:** the async-only override surfaces (first/new-page loading, first/new-page error, and
  the end-of-list footer) are bundled into one `AsyncListSurfaces` holder, passed as a single
  `surfaces:` argument. Surfaces every list has, `emptyBuilder` now (and `noResultsBuilder` with
  search), stay flat constructor parameters.
- **The rule (Rule X):** a surface is a flat parameter if *every* list has it, and moves into the
  async holder if *only async* lists have it. Behaviour config (`pageSize`, `endPolicy`, and the
  `refresh` seam) is not a surface and stays flat regardless.
- **The pull-to-refresh indicator is the deliberate exception, not in the holder.** It rides on the
  `PullToRefresh` case of the `refresh` seam, next to the on/off choice, so a refresh indicator can
  only be set on a list that actually refreshes. Putting it in the holder would let a `NoRefresh` list
  set an indicator that never shows, the ghost this package removes. (The wider principle, that an
  opt-in feature's config lives with the feature, is the [unified opt-in idioms](#opt-in-idioms).)
- **Why:** the `.async` constructor had grown a run of optional builders that buried the behavioural
  parameters (`fetchPage`, `pageSize`, `endPolicy`). Grouping them mirrors what `ListScrollConfig`
  does for the scrollable's knobs, shortens the call site, and lets a consumer define one surface set
  and reuse it across lists. Autocomplete still lists every slot inside `AsyncListSurfaces(...)`, so
  discoverability holds.
- **Why not group every surface** (including `emptyBuilder`): the sync search path has an empty state
  but none of the async surfaces. A single shared holder would put the async-only builders where a
  `.sync` list could set them and see nothing happen, the ghost-parameter bug list_smith exists to
  remove. Keeping universal surfaces flat means they read the same on `.async` and `.sync`, and the
  holder stays honestly async-only.
- **Landed in** the Step 2a refactor, alongside extracting the async engine into the unexported
  `AsyncListView` and making `ListSmith` a stateless dispatcher over the sealed `ListSource`. The
  pull-to-refresh indicator later moved out of the holder onto the `refresh` seam with issue #3.

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
  mirrors the pure `PaginationEndPolicy.hasReachedEnd`: the branchy logic (an empty or too-short
  query shows everything; an active query with no matches is the no-results surface) is tested
  without a widget.
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
  debounced committed query: empty runs the normal `fetchPage`, non-empty runs the `AsyncSearch`
  fetcher. Search is opt-in (the default `NoSearch` is a plain pagination list), and search mode
  requires both a non-empty query and an `AsyncSearch`.
- **Why one controller, not two:** pagination and pull-to-refresh then compose for free, one end
  policy and one `refresh()` serve both modes, and there is no second controller to keep in sync.
  `refresh()` re-reads the query, so pulling to refresh in search mode reloads the current search.
- **Cache policy is a pure decision plus an impure execution.** On a committed-query change,
  `SearchCachePolicy.actionFor(wasSearching, isSearching)` returns a `CacheAction`
  (`refresh` / `snapshotThenRefresh` / `restoreNormal`). That decision is widget- and controller-free,
  so it is unit-tested directly (the `hasReachedEnd` split again); the view executes it
  against the controller. `Keep` snapshots `controller.value` on entering search and restores it on
  leaving (an instant return, no refetch); `Replace` always refetches; a search-to-search change
  refetches under either policy.
- **Reading the search case:** search mode is `query.isNotEmpty && source.supportsSearch` (where
  `supportsSearch` is `search is AsyncSearch`), and the fetch closure pattern-matches the `AsyncSearch`
  case to reach its fetcher, so there is no nullable fetcher to bang. A query set without an
  `AsyncSearch` trips an `assert` in debug and degrades to normal pagination in release.
- **Shared `QueryDebouncer`:** the debounce (timer, trim, skip-unchanged) was extracted from
  `SyncListView` into an unexported helper both views own (a 2c refactor-first step). The owner seeds
  the initial query synchronously and schedules each later change; a zero-debounce change commits on
  the next tick, which removed a `setState`-during-`didUpdateWidget` hazard the async path would hit.

---

<a id="opt-in-idioms"></a>
## Unified opt-in idioms: every optional behaviour is a sealed, defaulted seam

- **Decision (issue #3):** each optional async behaviour is opted into the same way, by passing a
  non-default case of a sealed, defaulted seam. Refresh is `Refresh` (`PullToRefresh` default,
  `NoRefresh` off); async search is `Search` (`NoSearch` default, `AsyncSearch` on); grouping
  (`NoGrouping` / `Grouping.by`) and the end and cache policies already had this shape. The whole
  `.async` surface now reads one way: a default you can ignore, or a named case for the feature.
- **What it replaced:** a default-on `bool pullToRefresh` and a nullable `searchFetchPage` whose
  presence was the opt-in. Three different shapes for "turn a feature on" (a bool, a nullable
  callback, and sync's required `searchBy`) made the surface harder to learn than it needed to be.
- **Why it also removes ghosts:** the loose shapes had leaked two inert parameters, the exact bug
  list_smith exists to kill. `searchCachePolicy` sat on every `.async` list, doing nothing without a
  search fetcher; `AsyncListSurfaces.refreshBuilder` sat there doing nothing when `pullToRefresh` was
  false. Folding each feature's config into its own case (the cache policy into `AsyncSearch`, the
  indicator into `PullToRefresh`) means a knob can only be set on a list that uses it.
- **The rule:** an *optional* behaviour is a sealed, defaulted seam, opted into by passing a case.
  Behaviour that is the whole reason a constructor exists stays a plain required parameter: `.sync`'s
  `searchBy` is required, because an in-memory list with no predicate is just a `ListView.builder`.
  Live input that changes every build (`query`, `minSearchLength`, `searchDebounce`) stays flat, not
  folded into a seam, since a holder rebuilt every frame buys nothing.
- **Pre-publish, so the break was free.** The package is not yet on pub.dev, so reshaping `.async`
  cost nothing downstream. `SyncSearchPredicate`, `SearchPageFetcher`, and the `SearchCachePolicy`
  cases stay public; they are now reached through `AsyncSearch(...)` rather than as flat parameters.

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

<a id="grouping-shape"></a>
## Grouping: erased key, sync buckets, async pre-sorted

- **Decision:** an optional `Grouping<T>` on both constructors, defaulting to `NoGrouping`; opt in
  with `Grouping.by(groupBy:, headerBuilder:)`. A sealed, injected, defaulted seam like the end and
  cache policies. Chosen over a nullable `ListGrouping<T>?` holder (a nullable inert field again) and
  over flat `groupBy` + `headerBuilder` params (which allow the ghost combo of a header builder with
  no grouper); the sealed seam makes "off" a real case and rules both out. Breaking-change freedom
  (unpublished) let us take the cleaner shape.
- **`NoGrouping<T>` is generic, defaulted per construction.** Each constructor fills an unset
  `grouping` with `grouping ?? NoGrouping<T>()`. It was once a single `const NoGrouping()` of type
  `Grouping<Never>` (a `const` default assignable to any `Grouping<T>`, since `Never <: T`), but the
  polymorphic dispatch below needs `NoGrouping` at the real `T`, which a `Grouping<Never>` cannot give
  without crashing at runtime. See [#grouping-polymorphic-dispatch](#grouping-polymorphic-dispatch).
  The cost is one small allocation per list built without a grouping, off any hot path.
- **The key type is erased, so `ListSmith` stays single-generic.** `Grouping.by<T, K>` infers `K`
  from `groupBy`, keeps it typed in `headerBuilder`, then stores `Object`-keyed closures. A second
  generic `ListSmith<T, K>` was rejected: Dart can't default a type parameter, so every non-grouping
  list would carry a meaningless `K` forever. The `key as K` downcast is sound because each key
  reaching the header builder came from the same instance's `groupBy`. Caveat (on `Grouping.by`): an
  untyped inline `groupBy` closure widens `T` to `Object` (its parameter is the type variable, and
  nested inference doesn't recover it), so type the parameter or pass a typed function.
- **Header rides on the group's first item, not a sticky sliver.** `KeyedGrouping.decorate` wraps
  each cell in a `GroupedItem` that stacks the header before the group's first item in a `Flex` along
  the scroll axis, so ISP keeps its single flat pager and list_smith keeps owning the scrollable
  (decision 3). A per-cell look-back at the previous item's key marks where a group starts, O(1) per
  built cell. Sticky headers would need a sliver `CustomScrollView` and, on async, splitting the
  pager plus scroll-offset tracking (the fragility the package rejects), so they are deferred as a
  future opt-in.
- **Sync buckets; async trusts arrival order.** A sync list holds every item, so it reorders the
  filtered items into contiguous groups (`bucketByGroup` via `collection`'s `groupListsBy`; groups
  in first-appearance order, item order kept within a group), and the input can arrive in any order.
  An async list can't reorder across pages, so the fetcher must return items already grouped by key;
  a debug-only `groupsAreContiguous` assert flags a key that recurs after its section ended. Same
  sync-owns-the-data / async-is-incremental split as the rest of the package.
- **A presentation transform, not a source or policy.** `grouping` is a shared param on `ListSmith`
  (like `itemBuilder` / `scroll`), passed to both engines, not a field on the sealed source. Its pure
  ordering and boundary logic stays widget-free and unit-tested (`bucketByGroup`, `isGroupStart`,
  `groupsAreContiguous`, mirroring `resolveSyncSearch` and the policy resolvers); the per-build item
  wrapping lives on the type itself as `Grouping.decorate` (see
  [#grouping-polymorphic-dispatch](#grouping-polymorphic-dispatch)). `resolveSyncSearch` returns a lazy
  view so the grouped sync path buckets the filtered iterable with one materialisation; the sync view
  re-resolves on an items or `grouping` identity change so toggling grouping takes effect (hence
  "hold the `Grouping` stable" on a large list, to avoid re-bucketing every build).

---

<a id="grouping-polymorphic-dispatch"></a>
## Grouping dispatches on the type; the views don't branch

- **Decision:** the flat-vs-grouped choice lives on the sealed `Grouping<T>` as two `@internal`
  methods, so the view flow calls one delegate instead of testing `is KeyedGrouping` in three places.
  `arrange(items)` is the sync display ordering (`NoGrouping` returns the items as-is, no copy when
  they are already a `List`; `KeyedGrouping` buckets them via `bucketByGroup`). `decorate(itemBuilder,
  flatItems:, axis:)` returns the per-build item builder (`NoGrouping` returns it unchanged;
  `KeyedGrouping` wraps each cell in a `GroupedItem` and runs the debug contiguity assert). The pure
  helpers (`bucketByGroup`, `isGroupStart`, `groupsAreContiguous`) are unchanged and called from the
  methods. Same "delegate the decision to the type, keep the shell branch-free" move as the open
  end-policy (see [#explicit-end-signals](#explicit-end-signals)).
- **Sealed stays sealed.** Unlike `PaginationEndPolicy` (opened for consumer strategies), there is no
  compelling consumer-defined-grouping case, and the methods return neutral types, so nothing leaks
  either way; opening it later is a one-line change. The methods are `@internal` (`package:meta`):
  callable across the package's own libraries, not consumer API, since grouping is configured through
  `Grouping.by`.
- **`NoGrouping` had to become generic.** A method with a `T`-typed parameter, on an instance reified
  at `Never`, rejects a real argument at runtime: Dart makes such parameters covariant and checks
  them, so `arrange(<String>[...])` on a `Grouping<Never>` throws `List<String> is not
  Iterable<Never>`. The old `const NoGrouping()` default was exactly a `Grouping<Never>`, so keeping
  it would crash every ungrouped list the moment `arrange` or `decorate` ran. Hence `NoGrouping<T>`
  and the `grouping ?? NoGrouping<T>()` default (see [#grouping-shape](#grouping-shape)). A bare
  `const NoGrouping()` in a *consumer's* concrete call still infers `NoGrouping<Foo>` and is fine;
  only the library's own generic default could not name `T` inside a `const`.
- **The ungrouped path still does no flatten.** `decorate` takes `flatItems` as a callback, and
  `NoGrouping.decorate` never invokes it, so an ungrouped async list skips the O(loaded) page flatten
  just as the old short-circuit did. Only `KeyedGrouping.decorate` calls `flatItems()`, once per
  build, for the one-item look-back and the assert. The dispatch is per build, not per item: one
  virtual call replaces one `is` check, so the render path is unchanged. Confirmed perf-neutral
  against the `benchmark/micro` baseline.
- **`GroupedItem` was decoupled from `KeyedGrouping`.** It takes the `groupOf` and `headerFor`
  closures directly rather than the whole grouping, so `decorate` can build it without a cycle: the
  grouping model imports the `GroupedItem` widget, and had `GroupedItem` kept a `KeyedGrouping` field
  the two files would import each other. The trade is deliberate: `Grouping` gains a presentation
  method, so the model is no longer purely widget-free, though its ordering and boundary logic still
  is (the resolver helpers), and the dependency graph stays acyclic.

---

<a id="overlap-dedup"></a>
## Overlap de-dup runs at the display layer, not before storage

- **Decision:** `itemId` de-dup (drop items whose key already appeared on an earlier page) is a
  computed view over the paging state, `_dedupedForDisplay` running ISP's `PagingState.filterItems`
  in the build, not a filter applied to the pages the controller stores. The controller keeps the raw
  pages the fetchers returned; only what renders is de-duped.
- **Why not de-dup before storage (the issue #2 bug):** the end policy (`_nextPageKey`) reads the
  item count of each stored page. De-dup before storage lets a fully-duplicate page collapse to empty,
  and `StopOnEmptyPagesPolicy` reads that empty page as end-of-data and stops paginating even though
  the backend had more past the overlap. Raw stored pages mean the policy sees what the backend
  actually returned; a page that de-dups to nothing on screen still counts as a full page for end
  detection. Realistic partial-boundary overlap never hit this (those pages stay non-empty); a
  fully-duplicate mid-stream page, reachable with small page sizes, did.
- **One path covers search for free.** Both fetch modes flow through the one controller and the one
  display derivation, so search-mode overlaps de-dup exactly like normal-mode ones, no second code
  path.
- **Cost, and why it's acceptable here:** the pass is O(loaded items) and re-runs on each state
  change. There is no cheaper seam without storing de-duped pages and carrying a parallel raw
  page-count side-channel for the end policy, because ISP re-materialises the whole page list on every
  change anyway (`copyWith` re-wraps every page in `List.unmodifiable`). Measured
  (`benchmark/micro/dedup_scaling.dart`, reference desktop, no real overlap so nothing collapses):
  ~0.3 ms at 1k loaded items, ~3.5 ms at 10k, ~40 ms at 100k. It is memoised on paging-state identity,
  so an ancestor rebuild that doesn't change the data (a keystroke before the search debounce commits)
  reuses the last view, and it is skipped entirely when `itemId` is null. Sub-millisecond for the
  lists most consumers build; the cliff is only at tens of thousands of items held in one live list,
  which strains widget count and memory regardless.
- **The side-channel design was rejected, for now.** Incremental de-dup in the fetch (a persistent
  seen-set, O(page size) per fetch) with a raw-count side-channel would erase the cost, but that
  parallel state has to snapshot/restore in lockstep with `KeepCachePolicy`, and a bug there corrupts
  pagination, not just display. Not worth the fragility while realistic lists stay well under the
  cliff; revisit if large-list jank is reported. `benchmark/micro/dedup_scaling.dart` is the tripwire.

---

<a id="explicit-end-signals"></a>
## Explicit end signals: an open policy plus a fetcher building block

- **Decision:** `PaginationEndPolicy` is an open `abstract class` a consumer can implement, not a
  sealed set. The end decision is a public `hasReachedEnd(EndContext)` on the policy. list_smith
  ships `StopOnEmptyPagesPolicy`, `FixedPageCountPolicy`, and `ExplicitHasMorePolicy`, and a
  consumer can add their own (a short-last-page or null-cursor rule) without a change here.
- **Why open, not sealed.** Issue #1 existed because a sealed policy forced list_smith to enumerate
  every end-detection strategy. Opening it flips that: the common page-derivable rules become a few
  lines of consumer code. It also deletes a workaround. The decision used to live in an unexported
  resolver extension so the policy could stay pure data while the shell reached it from another
  library; a public method on an open interface needs none of that, so the extension is gone and
  tests call `hasReachedEnd` directly.
- **The signal is a fetcher output, orthogonal to the policy.** A `hasMore` flag lives in the
  network response, which only the fetcher sees, so no policy shape can conjure it: the policy
  decides, the fetcher supplies. `PageFetcher` / `SearchPageFetcher` became small callable classes
  (were bare typedefs) with two constructors. The default `.new` returns items only; `.withSignal`
  returns `(items, Object? signal)`. The common path pays a one-constructor wrap and the signal
  rides the same return, so `T` stays the consumer's DTO, never a `Response<T>` wrapper.
- **The signal is erased to `Object?`.** `ExplicitHasMorePolicy` reads it as a `hasMore` bool; a
  consumer's cursor policy reads it as their cursor. Erasure (the trick grouping uses for its key)
  avoids a second type parameter on `ListSmith`. A return value beat a mutation channel (a
  `Completer` or sink) because it fits the package's value-object grain and, unlike a `void`
  completer, can carry a cursor.
- **list_smith owns the signal's lifecycle, so policies stay pure.** The last fetch's signal lives
  in `_lastPageSignal` (it is not derivable from the paging state). It feeds each
  `EndContext.lastPageSignal`, resets on refresh, and is snapshotted with the normal state across a
  `KeepCachePolicy` search toggle. Because the library owns that one field, every policy is a pure
  function of its `EndContext` and stays correct across refresh and the normal-search transition,
  with no consumer-side reset wiring. A guard asserts `ExplicitHasMorePolicy` is paired with a
  `.withSignal` fetcher, so a "never ends" mispairing fails at construction.
- **Scope: an end signal; cursor-driven paging came later.** #1 carried the cursor only as a stop
  signal (ending on a null cursor), not fed back as the next fetch's input, and the page key stayed
  the 0-based ordinal. Issue #14 made the signal bidirectional so it also drives the fetch, see
  [Cursor-driven pagination](#cursor-driven-pagination). The page key stayed the ordinal, so that
  follow-up was smaller than this bullet once expected.
- **Layout:** `PageFetcher` and `SearchPageFetcher` live under `models/` now that they are classes,
  not in `typedefs/` (which keeps only real typedefs, like `SyncSearchPredicate`).

---

<a id="cursor-driven-pagination"></a>
## Cursor-driven pagination: the signal, fed back

- **Decision (issue #14):** a cursor drives the next fetch, not just the end. The `withSignal`
  channel became bidirectional: the `Object?` a page returns is handed to the next fetch as
  `previousSignal` (null for the first page), so the next fetch uses the cursor the previous page
  returned. `StopOnNullSignalPolicy` ends the list on a null cursor.
- **No new constructor, fetcher type, or generic.** The page-key change #1 anticipated turned out not
  to be needed. list_smith keeps `PagingController<int, T>` (an ISP ordinal), and
  the cursor rides `_lastPageSignal`, the field that already tracked the signal for end-detection.
  `_fetchPage` passes it in; `_nextPageKey` still returns `pages.length`. `itemId`, grouping, and
  refresh are all item-based, so they were untouched: the whole new surface is the third `withSignal`
  argument plus `StopOnNullSignalPolicy`.
- **Retry and refresh fall out for free.** `_lastPageSignal` only advances after a fetch succeeds, so
  ISP retrying a failed page re-fetches it with the same cursor; refresh nulls the field, so the reload
  restarts from the initial null cursor. Neither needed new code.
- **The cursor stays `Object?`.** It is the same signal the end policy reads, so a real cursor generic
  on `ListSmith` would split the channel's typing and reintroduce the second generic #1 avoided. The
  consumer casts `previousSignal as MyCursor?` once, in their own fetch closure, where the type is
  known. `SearchPageFetcher.withSignal` took the same third argument, so cursor-driven search works
  with no separate seam (the two-view controller already snapshots the signal per stream); the
  `requiresSignal` guard keeps a signal end policy paired with `.withSignal` fetchers on both.

---

<a id="sync-searchable-fields"></a>
## Sync `searchableFields` convenience: a builder that returns the typedef

- **Decision (issue #25):** `SyncSearchPredicates.fields([...])`, a static factory on a namespace
  holder that returns a [SyncSearchPredicate], baking the predicate nearly every `.sync` list writes
  by hand: keep an item when any extracted field contains the query, case-insensitively. The raw
  `searchBy` primitive is untouched and stays the escape hatch. Anticipated when `.sync` shipped (see
  [#sync-search-shape](#sync-search-shape)).
- **A small family, one shared helper:** `fields` (contains) grew siblings that are the same loop
  with a different test: `prefix` (starts-with), `exact` (equals), and `allTerms` (every whitespace
  term must hit some field, the one multi-word case plain `contains` misses). `fields`, `prefix`, and
  `exact` share a private `_anyField(extractors, test)` (materialise, assert,
  `map().nonNulls.any(test)`), so each is a one-liner (refactor-first: `fields` moved onto the helper
  before the siblings landed). `any` (OR) and `every` (AND) combine predicates rather than fields.
  Each is knob-free and named for what it does, over a `mode:` enum that would reintroduce the knobs
  the primitive avoids.
- **Why a holder, not `SyncSearchPredicate.fields`:** the issue sketched the factory as a static on
  the type itself, but `SyncSearchPredicate` is a real function typedef (see the layout note under
  [explicit end signals](#explicit-end-signals): `typedefs/` keeps only real typedefs), and Dart
  typedefs cannot carry static members. Hanging `.fields` on the name would mean converting it to a
  callable class like `PageFetcher`, which breaks bare-closure `searchBy` (`(c, q) => ...` needs
  wrapping) and contradicts the typedef/class split. A separate holder that returns the typedef
  keeps closures working, stays purely additive (minor bump, no break), and matches how the
  package already namespaces builders (`Grouping.by`, `PageFetcher.withSignal`).
- **`abstract final class` namespace:** the holder has only a static `fields`, so it is
  `abstract final` (cannot be instantiated or subclassed). `avoid_classes_with_only_static_members`
  is off for exactly this. `prefer_constructors_over_static_methods` does not fire, because `fields`
  returns `SyncSearchPredicate<T>`, not the holder, so a named constructor is not even an option.
- **No case knob:** matching is case-insensitive substring only. The primitive bakes in zero matching
  policy on purpose; the convenience bakes in exactly the common one and nothing else, so there is no
  `caseSensitive` flag left sitting inert. Case-sensitive, diacritic-folded, or fuzzy matching drops
  back to a hand-written `searchBy`. A flag is a non-breaking optional param to add later if the need
  shows up.
- **`String?` extractors, nulls dropped:** each extractor is `String? Function(T)`, so a nullable
  field (`(c) => c.subtitle`) compiles with no `?? ''`. Nulls are removed with `.nonNulls` before
  matching (a null field never matches and never throws). Extractors are materialised once
  (`toList(growable: false)`) because the returned closure iterates them per item, and an empty list
  is a debug `assert` (it would silently match nothing on every search). The query arrives trimmed
  and past the min-length gate from `resolveSyncSearch`, so the builder neither re-trims nor
  special-cases the empty query, and it costs the same per item as the hand-written `contains` it
  replaces.
- **Inference caveat, pin the type on the list:** used inline as `ListSmith.sync(searchBy:
  SyncSearchPredicates.fields([...]))`, the widget's element type and the builder's type parameter
  infer together and the un-annotated extractor closures come out nullable. Pin it on the list,
  `ListSmith<City>.sync(...)`: naming it once there covers every builder passed, which reads better
  than annotating each `fields<City>` when combining builders. Inherent to any generic builder used
  inline (a top-level function or a `SyncSearchPredicate.fields` static would need it too), not the
  holder choice. The README, the dartdoc, and the example all show it.

---

**TODO (design pass and beyond).** Decisions still to be recorded here as they land, for example:
the SDK floor rationale, the public API surface and why it's shaped that way, how sync vs async
data sources are modelled, the search / cache interplay policy, and what `list_smith` deliberately
does *not* do (learning from the pitfalls of the package it replaces).
