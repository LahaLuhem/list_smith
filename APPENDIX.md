# APPENDIX for `list_smith`

Design rationale: the "why" behind decisions the code and hard rules don't explain on their own.
Hard rules and workflow live in [`.ai/AGENTS.md`](.ai/AGENTS.md), code style in
[`CODESTYLE.md`](CODESTYLE.md), the map of parts and seams in
[`doc/how-it-works.md`](doc/how-it-works.md). A decision log, appended as decisions land.

Every heading carries an `<a id="…">` anchor. Link by anchor and keep anchors stable across
renames.

<!-- TOC start -->

- [`AGENTS.md` and `CLAUDE.md` are symlinks into `.ai/`](#ai-files-symlinked)
- [Consumer-facing surfaces impose no design system](#design-system-agnostic)
- [`lib/src/` directory layout](#src-directory-layout)
- [Pull-to-refresh resets the list on V1](#pull-to-refresh-resets-v1)
- [Async override surfaces group, universal ones stay flat](#async-surfaces-holder)
- [Sync search: flat input, a pure resolver](#sync-search-shape)
- [Async search: one paging state, 2 views](#async-two-view-search)
- [Unified opt-in idioms: every optional behaviour is a sealed, defaulted seam](#opt-in-idioms)
- [Observer seam: async-only, no-op-method sink](#observer-seam)
- [Grouping: erased key, sync buckets, async pre-sorted](#grouping-shape)
- [Grouping dispatches on the type, so the views don't branch](#grouping-polymorphic-dispatch)
- [Overlap de-dup runs at the display layer, not before storage](#overlap-dedup)
- [Explicit end signals: an open policy plus a fetcher building block](#explicit-end-signals)
- [Cursor-driven pagination: the signal, fed back](#cursor-driven-pagination)
- [Sync predicate builders (`SyncSearchPredicates`)](#sync-searchable-fields)
- [A narrow controller: intents out, nothing back](#controller-handle)
- [Each reload is a run that knows its stream](#reload-run)
- [Fetchers take a request object, not an argument list](#page-request-object)
- [Fetchers are told why they were called](#fetch-trigger)
- [Per-item scans on the build path stay loops, and pack their flags](#scan-loops)
- [The format gate runs Flutter's Dart, not standalone Dart](#ci-format-sdk)
- [The root analysis skips `benchmark/app`](#root-analysis-skips-bench-app)
- [Dependabot's PRs auto-merge through dartender](#dependabot-automerge)
- [Local edits live beside the pages, not in them](#edit-layer)
- [list_smith places the pull indicator, the builder only draws it](#pull-indicator-layout)
- [`itemIdGetter` is required](#item-id-required)
- [Async rows follow their item, not their index](#row-identity)
- [Edit transitions animate the rows edits add and take](#edit-transitions)
- [list_smith pages on its own](#own-paging)
- [Where a pull can start](#pull-surfaces)

<!-- TOC end -->

<a id="ai-files-symlinked"></a>
## `AGENTS.md` and `CLAUDE.md` are symlinks into `.ai/`

- **Decision:** the canonical text lives under [`.ai/`](.ai/), the root holds symlinks
  (`AGENTS.md -> .ai/AGENTS.md`, `CLAUDE.md -> .ai/CLAUDE.md`).
- **Why:** agents auto-discover `CLAUDE.md` / `AGENTS.md` at the root, but loose files there add
  tree noise. `.ai/` keeps them together and the symlinks preserve discovery. `.gitignore` ignores
  the root symlinks and commits the `.ai/` targets, `.pubignore` excludes both, so nothing ships.
- **Cross-platform:** symlinks survive `git clone` on macOS and Linux. A Windows host without
  symlink support may show a text file holding the target path instead, where the fallback is real
  files at the root, hand-synced.

---

<a id="design-system-agnostic"></a>
## Consumer-facing surfaces impose no design system

- **Decision:** list_smith's code, and every default it ships for a visible surface, builds on
  `package:flutter/widgets.dart` only, never `material.dart` or `cupertino.dart`. Every surface
  stays overridable and the defaults are neutral widgets-layer widgets.
- **Scope is our surfaces, not what a dependency does inside.** A dependency may import Material
  internally, as `custom_refresh_indicator` does. We neutralise it by filling every slot it draws
  in, so no Material appears in our own look. Migrating that dependency's internals once Flutter
  unbundles Material is its problem, not ours.
- **Why:** developer experience, since list_smith drops into a Material, Cupertino or bespoke app
  without importing a look the consumer never chose. And forward-compatibility, since Flutter is
  decoupling `material` / `cupertino` from core
  (<https://github.com/orgs/flutter/projects/220>), which makes the widgets layer where a neutral
  package belongs.
- **Consequences:** the widgets layer ships no spinner, so the loading and refresh defaults are
  small widgets-layer implementations (a `CustomPainter`), not `CircularProgressIndicator`. When
  wrapping a dependency that has Material defaults, a null default-builder slot is a defect, since
  its Material default leaks onto our surface. Fill every slot.

---

<a id="src-directory-layout"></a>
## `lib/src/` directory layout

- **Decision:** by kind at the top (`data/`, `widgets/`, `utils/`), then by feature
  (`data/pagination/`, `data/search/`, ...), then by kind again inside a feature (`models/`,
  `typedefs/`, `enums/`, `extensions/`, `utils/`), one primary public symbol per file. Sealed cases
  nest one level under the base's kind as `part`s. A small feature stays flat until its vocabulary
  earns the 3rd level.
- **Why:** it matches the maintainer's other Flutter packages, so a contributor moving between them
  meets the same shape. By-kind at the top separates data from behaviour, by-feature keeps a
  concern's pieces together, and by-kind inside a feature keeps a grown one scannable.
- **Rejected:** top-level `enums/` / `typedefs/` folders, which scatter a feature's vocabulary
  across the tree. A typedef with one home type lives in that type's file.
- **`data/` over `models/`:** the folder also holds enums and typedefs, which are not models.

---

<a id="pull-to-refresh-resets-v1"></a>
## Pull-to-refresh resets the list on V1

- **Decision (V1):** a pull resets the paging state, so the list clears and the first-page loader
  shows while the fresh page loads. The pull indicator retracts as the loader shows.
- **Why not hold the indicator until fresh data:** it would spin beside the loader. A `refresh()`
  from code still waits for the fresh page, since a button has no loader to hand over to.
- **Since landed as an option:** `ReloadToCurrentDepth` keeps the old items and holds the indicator
  until the re-fetch is done ([#reload-run](#reload-run)).

---

<a id="async-surfaces-holder"></a>
## Async override surfaces group, universal ones stay flat

- **Decision:** the async-only override surfaces (first and new-page loading and error, the
  end-of-list footer) bundle into one `AsyncListSurfaces` passed as `surfaces:`. Surfaces every list
  has, `emptyBuilder` and `noResultsBuilder`, stay flat constructor parameters.
- **The rule, flat if universal:** a surface is flat if every list has it, and moves into the async
  holder if only async lists do. Behaviour config (`pageSize`, `endPolicy`, the `refresh` seam) is
  not a surface and stays flat regardless.
- **The pull-to-refresh indicator is the deliberate exception.** It rides the `PullToRefresh` case
  of the `refresh` seam, next to the on/off choice, so an indicator can only be set on a list that
  refreshes. In the holder, a `NoRefresh` list could set one that never shows, exactly the ghost
  this package removes. Wider principle: [unified opt-in idioms](#opt-in-idioms).
- **Why:** the `.async` constructor had grown a run of optional builders that buried the behavioural
  parameters. Grouping them mirrors `ListScrollConfig`, shortens the call site, and lets a consumer
  reuse one surface set across lists. Autocomplete still lists every slot inside the holder.
- **Why not group `emptyBuilder` too:** the sync path has an empty state but none of the async
  surfaces, so a shared holder would let a `.sync` list set builders that do nothing.

---

<a id="sync-search-shape"></a>
## Sync search: flat input, a pure resolver

- **Decision:** `.sync` takes its search input (`query`, `minSearchLength`, `searchDebounce`) as
  flat parameters, not a `SearchConfig` holder, even though the override surfaces were grouped.
- **Why flat:** `AsyncListSurfaces` groups builders a consumer sets once. `query` is the opposite,
  changing on nearly every rebuild, so burying it in a holder reads badly. The debounce default also
  diverges by path (zero on sync, 300ms on async), which flat per-constructor defaults express and a
  shared holder could not.
- **Pure resolver:** the trim, the min-length gate and the predicate filtering live in a widget-free
  `resolveSyncSearch(...)` returning `(visibleItems, isSearching)`, unit-tested directly. An empty
  or too-short query shows everything, an active query with no matches is the no-results surface.
- **Surfaces stay flat:** `emptyBuilder` and `noResultsBuilder` are shared with the async path, per
  the [flat-if-universal rule](#async-surfaces-holder). A sync list carries no async surfaces, so
  `.sync` takes no `AsyncListSurfaces` at all.
- **The iterable is copied once:** `SyncSource` keeps the consumer's raw iterable, and
  `SyncListView` turns it into a list once, again only when the iterable identity changes, so an
  unchanged list is never re-copied or re-filtered per build.
- **`scrollCacheExtent`, not `cacheExtent`:** Flutter deprecated `ScrollView.cacheExtent` (`double`)
  for `scrollCacheExtent` (`ScrollCacheExtent`). `ListScrollConfig.cacheExtent` stays a public
  `double?`, and both views read it through an unexported extension that wraps it in
  `ScrollCacheExtent.pixels(...)`, from `package:flutter/rendering.dart` rather than a design
  system.

---

<a id="async-two-view-search"></a>
## Async search: one paging state, 2 views

- **Decision:** async search rides a single paging state. A mode-aware fetch reads the debounced
  committed query: empty runs the normal `fetchPage`, non-empty runs the `AsyncSearch` fetcher.
  Search is opt-in, and search mode needs both a non-empty query and an `AsyncSearch`.
- **Why one state:** pagination and pull-to-refresh compose for free, one end policy and one
  `refresh()` serve both modes, and there is no 2nd state to keep in sync. `refresh()` re-reads the
  query, so pulling in search mode reloads the current search.
- **Cache policy is a pure decision plus an impure execution.** On a committed-query change,
  `actionFor(wasSearching, isSearching)` returns a `CacheAction` (`refresh` / `snapshotThenRefresh`
  / `restoreNormal`), unit-tested directly, and the engine executes it. Keep snapshots the paging
  state on the way in and restores it on the way out, an instant return with no refetch. Replace
  always refetches. A search-to-search change refetches under either.
- **The kept feed carries a debt.** A pull, `refresh()` or `invalidate()` made while searching can't
  reach the parked feed, so the snapshot books the ask (`.refresh` outranks `.invalidated`) and the
  restore pays it: pages back as they were, then a `ReloadToCurrentDepth` over them reporting that
  trigger. A snapshot taken under a live feed run is born owing what a caller asked of it, since the
  reset that follows strands it. `reset()` drops the snapshot instead, page 0 being the verb.
- **Reading the search case:** search mode is `query.isNotEmpty && source.supportsSearch`, and the
  fetch pattern-matches the `AsyncSearch` case to reach its fetcher, so there is no nullable
  fetcher to bang. A query set without an `AsyncSearch` asserts in debug and degrades to normal
  pagination in release.
- **Shared `QueryDebouncer`:** the timer, trim and skip-unchanged logic was extracted from
  `SyncListView` into an unexported helper both views own. The owner seeds the initial query
  synchronously and schedules later changes, and a zero-debounce change commits on the next tick,
  which removed a `setState`-during-`didUpdateWidget` hazard the async path would have hit.

---

<a id="opt-in-idioms"></a>
## Unified opt-in idioms: every optional behaviour is a sealed, defaulted seam

- **Decision:** each optional async behaviour is opted into the same way, by passing a non-default
  case of a sealed, defaulted seam. Refresh is `Refresh` (`PullToRefresh` default, `NoRefresh` off),
  async search is `Search` (`NoSearch` default, `AsyncSearch` on), and grouping plus the end and
  cache policies already had this shape. The `.async` surface then reads one way: a default you can
  ignore, or a named case for the feature.
- **What it replaced:** a default-on `bool pullToRefresh` and a nullable `searchFetchPage` whose
  presence was the opt-in. 3 shapes for "turn a feature on" made the surface harder to learn
  than it needed to be.
- **It also removes ghosts:** the loose shapes leaked 2 inert params. `searchCachePolicy` sat on
  every `.async` list doing nothing without a search fetcher, and `refreshBuilder` did nothing when
  `pullToRefresh` was false. Folding a feature's config into its own case means a knob can only be
  set on a list that uses it.
- **The rule:** an optional behaviour is a sealed, defaulted seam opted into by passing a case.
  Behaviour that is the whole reason a constructor exists stays required, like `.sync`'s `searchBy`,
  since an in-memory list with no predicate is just a `ListView.builder`. Live input that changes
  every build stays flat, since a holder rebuilt every frame buys nothing.

---

<a id="observer-seam"></a>
## Observer seam: async-only, no-op-method sink

- **Decision:** an optional `ListSmithObserver` injected via `ListSmith.async(observer: ...)`,
  modelled on `better_internet_connectivity_checker`'s `ConnectivityObserver`. An
  `abstract base class` with a no-op default per event, so a subclass overrides only what it wants,
  plus a `LoggingListSmithObserver` that logs each via `dart:developer`.
- **Discrete events only.** The seam fires from callbacks outside `build`: the page fetch, a
  reload's start, the debounced-query commit. No-results, empty and end-reached are excluded on
  purpose, since they exist only as a function of paging and filter state *during* `build`, so
  firing there would re-fire on every rebuild and risk a `setState`-during-build. End-reached is
  worth revisiting, but needs a latched post-frame dispatch, more machinery than the discrete events
  carry.
- **One reload event, carrying the reason.** `onReload(FetchTrigger)` replaced `onRefresh()` once a
  2nd reload-shaped intent was on the way. One event per reload the engine starts, with the
  trigger its pages report, instead of a no-op method per verb. Query-driven reloads fire it too. A
  `KeepCache` restore fires nothing unless it pays a debt
  ([#async-two-view-search](#async-two-view-search)).
- **Async-only.** The observer earns its place by surfacing what the hidden engine keeps out of
  reach. A sync list has no paging, fetch or refresh, and the consumer owns the query it filters
  on, so an observer there would be exactly the ghost that the
  [flat-if-universal rule](#async-surfaces-holder) rules out. A `SyncListSmithObserver` stays
  additive if a real use case turns up.
- **Fully hidden, non-generic.** Every callback takes plain values, never the paging state, so
  wiring up diagnostics can't reach an internal handle.
  Non-generic because logging and analytics want counts and mode. A generic variant stays open if
  item payloads are ever wanted.
- **`abstract base`, extend-only,** so a new lifecycle event can ship as a no-op method in a later
  minor release without breaking existing subclasses. It is a dispatch seam, not a decision seam, so
  it carries no pure resolver of its own and is covered by widget tests driving a
  `RecordingListSmithObserver`.
- **No-op bodies, not commented ones.** The class dartdoc says once that every default is a no-op,
  and a file-level `ignore_for_file: no-empty-block` carries the reason, rather than a comment in
  each body.

---

<a id="grouping-shape"></a>
## Grouping: erased key, sync buckets, async pre-sorted

- **Decision:** an optional `Grouping<T>` on both constructors, default `NoGrouping`, opted into
  with `Grouping.by(groupBy:, headerBuilder:)`. A sealed, defaulted seam like the end and cache
  policies. Chosen over a nullable `ListGrouping<T>?`, another inert nullable, and over flat
  `groupBy` + `headerBuilder`, which allows the ghost combo of a header builder with no grouper.
  The sealed seam makes "off" a real case.
- **`NoGrouping<T>` is generic, defaulted per construction** via `grouping ?? NoGrouping<T>()`,
  rather than one shared `const NoGrouping()`. Why it has to be is under
  [#grouping-polymorphic-dispatch](#grouping-polymorphic-dispatch). The cost is one small allocation
  per ungrouped list, off any hot path.
- **The key type is erased, so `ListSmith` stays single-generic.** `Grouping.by<T, K>` infers `K`
  from `groupBy`, keeps it typed in `headerBuilder`, then stores `Object`-keyed closures. A 2nd
  generic `ListSmith<T, K>` was rejected because Dart can't default a type parameter, so every
  non-grouping list would carry a meaningless `K`. The `key as K` downcast is sound: every key
  reaching the header came from the same instance's `groupBy`. Caveat: an untyped inline `groupBy`
  widens `T` to `Object`, so type the parameter or pass a typed function.
- **The header rides the group's 1st item, not a sticky sliver.** `KeyedGrouping.decorate` wraps
  each cell in a `GroupedItem` that stacks the header before the group's 1st item in a `Flex`
  along the scroll axis, so the pager stays flat and list_smith keeps owning the scrollable. One
  pass per build flags where each group starts ([#scan-loops](#scan-loops)). Sticky headers would
  need a sliver `CustomScrollView` and, on async, a split pager plus scroll-offset tracking, exactly
  the fragility this package rejects. Deferred.
- **Sync buckets, async trusts arrival order.** A sync list holds every item, so it reorders the
  filtered ones into contiguous groups (`bucketByGroup` over `collection`'s `groupListsBy`,
  first-appearance order, item order kept within a group) and input can arrive any way round. An
  async list can't reorder across pages, so the fetcher must return items already grouped by key,
  with a debug-only `groupsAreContiguous` assert flagging a key that recurs after its section ended.
- **A presentation transform, not a source or policy.** `grouping` is a shared `ListSmith` param
  passed to both engines, not a field on the sealed source. Its ordering and boundary logic stays
  widget-free and unit-tested (`bucketByGroup`, `resolveHeaderFlags`, `groupsAreContiguous`), while
  the per-build wrapping lives on the type as `Grouping.decorate`. `resolveSyncSearch` returns a
  lazy view so the grouped sync path buckets with one copy, re-resolving on an items or `grouping`
  identity change. Hence "hold the `Grouping` stable" on a large list.

---

<a id="grouping-polymorphic-dispatch"></a>
## Grouping dispatches on the type, so the views don't branch

- **Decision:** the flat-vs-grouped choice lives on the sealed `Grouping<T>` as 2 `@internal`
  methods, so the view calls one delegate instead of testing `is KeyedGrouping` in 3 places.
  `arrange(items)` is the sync display ordering, `decorate(itemBuilder, flattenItems:, axis:)`
  returns the per-build item builder. Same "delegate to the type, keep the shell branch-free" move
  as the open end-policy ([#explicit-end-signals](#explicit-end-signals)).
- **Sealed stays sealed.** Unlike `PaginationEndPolicy`, opened for consumer strategies, there is no
  compelling consumer-defined-grouping case, and the methods return neutral types so nothing leaks.
  Opening it later is a one-line change. `@internal` makes them callable across the package but not
  consumer API, since grouping is configured through `Grouping.by`.
- **`NoGrouping` had to become generic.** A `T`-typed parameter on an instance reified at `Never`
  rejects a real argument at runtime, since Dart makes such parameters covariant and checks them, so
  `arrange(<String>[...])` on a `Grouping<Never>` throws. The old `const NoGrouping()` default was
  exactly that, and would have crashed every ungrouped list the moment `arrange` or `decorate` ran.
  Hence `NoGrouping<T>` and the `grouping ?? NoGrouping<T>()` default. A bare `const NoGrouping()`
  in a consumer's own call still infers `NoGrouping<Foo>`. Only the library's generic default
  couldn't name `T` inside a `const`.
- **The ungrouped path still does no flatten.** `decorate` takes `flattenItems` as a callback
  `NoGrouping.decorate` never invokes, so an ungrouped async list skips the O(loaded) page flatten.
  Only `KeyedGrouping.decorate` calls it, once per build, for the header flags and the assert.
  Dispatch is per build rather than per item, one virtual call replacing one `is` check, so the
  render path is unchanged. Confirmed perf-neutral against the `benchmark/micro` baseline.
- **`GroupedItem` was decoupled from `KeyedGrouping`.** It takes `groupOf` and `headerFor` directly
  rather than the whole grouping, so `decorate` can build it without a cycle: the grouping model
  imports the widget, and a `KeyedGrouping` field would make the 2 files import each other. The
  trade is deliberate. `Grouping` gains a presentation method, so the model is no longer purely
  widget-free, though its ordering and boundary logic still is and the graph stays acyclic.

---

<a id="overlap-dedup"></a>
## Overlap de-dup runs at the display layer, not before storage

- **Decision:** de-dup by id is a computed view over the paging state, `_displayFor` running
  `PagingState.filterItems` in the build, not a filter on the stored pages. The state keeps the raw
  pages, and only what renders is de-duped.
- **Why not de-dup before storage:** the end policy reads each stored page's item count. De-dup
  first lets a fully-duplicate page collapse to empty, which `StopOnEmptyPagesPolicy` reads as
  end-of-data even though the backend had more past the overlap. Partial-boundary overlap never hit
  this. A fully-duplicate mid-stream page, reachable with small page sizes, did.
- **One path covers search for free.** Both fetch modes flow through one paging state and one
  display derivation, so search-mode overlaps de-dup exactly like normal-mode ones.
- **Cost, and why it's acceptable:** O(loaded items), re-run on each state change. There is no
  cheaper seam without storing de-duped pages plus a parallel raw-count side-channel for the end
  policy. The [benchmark report](benchmark/reports/SUMMARY.md) measures it with no real overlap.
  Memoised on paging-state identity, so a keystroke before the debounce commits reuses the last
  view. Sub-millisecond for most lists, with the cliff only at tens of thousands in one live list,
  which strains widget count and memory regardless.
- **The side-channel design was rejected, for now.** Incremental de-dup in the fetch plus a
  raw-count side-channel would erase the cost, but that state has to snapshot and restore in
  lockstep with `KeepCachePolicy`, and a bug there corrupts pagination rather than just display.
  Not worth it while realistic lists stay under the cliff. `benchmark/micro/dedup_scaling.dart` is
  the tripwire.

---

<a id="explicit-end-signals"></a>
## Explicit end signals: an open policy plus a fetcher building block

- **Decision:** `PaginationEndPolicy` is an open `abstract class` a consumer can implement, not a
  sealed set, and the end decision is a public `hasReachedEnd(EndContext)`. A consumer can add a
  policy of their own with no change here.
- **Why open, not sealed.** A sealed policy forced list_smith to enumerate every strategy. Opening
  it makes the common page-derivable rules a few lines of consumer code, and tests call
  `hasReachedEnd` directly.
- **The signal is a fetcher output, orthogonal to the policy.** A `hasMore` flag lives in the
  network response, which only the fetcher sees, so the policy decides and the fetcher supplies.
  `PageFetcher` and `SearchPageFetcher` are small callable classes with 2 constructors: `.new`
  returns items only, `.withSignal` returns `(items, Object? signal)`. The common path pays a
  one-constructor wrap, so `T` stays the consumer's DTO rather than a `Response<T>` wrapper.
- **The signal is erased to `Object?`.** `ExplicitHasMorePolicy` reads it as a bool, a consumer's
  cursor policy as their cursor. Erasure, grouping's key trick, avoids a 2nd `ListSmith` generic.
  A return value beat a mutation channel (a `Completer` or sink): it fits the package's
  value-object grain and, unlike a `void` completer, can carry a cursor.
- **list_smith owns the signal's lifecycle, so policies stay pure.** The last fetch's signal lives
  in `_lastPageSignal`, which is not derivable from the paging state. It feeds each
  `EndContext.lastPageSignal`, resets on refresh, and snapshots with the normal state across a
  `KeepCachePolicy` toggle, so every policy is a pure function of its `EndContext` with no
  consumer-side reset wiring. A guard asserts a signal policy is paired with a `.withSignal`
  fetcher.
- **Layout:** `PageFetcher` and `SearchPageFetcher` live under `models/` now that they are classes.
  `typedefs/` keeps only real typedefs.

---

<a id="cursor-driven-pagination"></a>
## Cursor-driven pagination: the signal, fed back

- **Decision:** a cursor drives the next fetch, not just the end. The `withSignal` channel became
  bidirectional, so the `Object?` a page returns reaches the next fetch as `previousSignal`, null
  for the 1st page. `StopOnNullSignalPolicy` ends the list on a null cursor.
- **No new constructor, fetcher type or generic.** A page is still found by its index, and the
  cursor rides `_lastPageSignal`, the field already tracking the signal for end-detection.
- **Retry and refresh fall out for free.** `_lastPageSignal` only advances after a fetch succeeds,
  so a retried page re-fetches with the same cursor, and refresh nulls the field so the reload
  restarts from the initial null.
- **The cursor stays `Object?`,** for the reason the end signal does
  ([#explicit-end-signals](#explicit-end-signals)). The consumer casts `previousSignal as MyCursor?`
  once, in their own closure. `SearchPageFetcher.withSignal` took the same argument, so
  cursor-driven search needs no separate seam: the two-view engine already snapshots the signal per
  stream, and the `requiresSignal` guard covers both fetchers.

---

<a id="sync-searchable-fields"></a>
## Sync predicate builders (`SyncSearchPredicates`)

- **What:** a namespace of static builders returning a `SyncSearchPredicate`, so a `.sync` list
  skips hand-rolling the usual matching. `fields` (contains), `prefix` (starts-with), `exact`
  (equals), `allTerms` (every whitespace term must hit some field, the multi-word case `contains`
  misses), plus `any` / `every` to combine. All case-insensitive, all skipping `null` fields. The
  raw `searchBy` stays the escape hatch for case-sensitive, diacritic or fuzzy matching.
- **Knob-free, named factories.** Each is named for what it does rather than taking a `mode:` flag,
  which keeps the primitive's no-baked-in-policy stance: nothing sits inert, you pick a builder or
  drop to `searchBy`. `fields` / `prefix` / `exact` share a private `_anyField(extractors, test)`,
  so each is a one-liner.
- **A holder, not `SyncSearchPredicate.fields`.** `SyncSearchPredicate` is a real typedef and Dart
  typedefs can't carry statics. Making it a callable class would break bare-closure `searchBy` and
  contradict the typedef/class split, so the holder returns the typedef instead: additive, closures
  still work, consistent with `Grouping.by` and `PageFetcher.withSignal`. `abstract final`, a pure
  namespace, and `prefer_constructors_over_static_methods` stays quiet because the builders return
  the typedef rather than the holder.
- **`String?` extractors** let a nullable field compile with no `?? ''`, with nulls dropped via
  `.nonNulls`. The query arrives trimmed and gated by `resolveSyncSearch`, so a builder never
  re-trims or handles an empty query.
- **Used inline, pin `T` on the list.** The widget's element type and a builder's type parameter
  infer together, so the un-annotated extractor closures come out nullable. `ListSmith<City>.sync`
  names it once and covers every builder, which beats annotating each. Inherent to any generic
  builder used inline, not a consequence of the holder.

---

<a id="controller-handle"></a>
## A narrow controller: intents out, nothing back

- **Decision:** an optional `ListSmithController` on `ListSmith.async`, carrying intents:
  `refresh()`, `invalidate()`, `reset()` and the [edits](#edit-layer). A bounded exception to the
  hidden pager, and the line held is that no paging state is reachable through it.
- **No scrolling verbs.** A consumer already scrolls through `ListScrollConfig.controller`, and
  index-scrolling needs fixed extents, which puts it with the sliver and grid work.
- **Intents, not state.** No `isRefreshing`, count or `hasMore`. Notification is the observer's job
  ([#observer-seam](#observer-seam)), and a state-bearing handle re-exposes the pager by the back
  door.
- **One refresh path.** The engine implements `ListSmithControllerHost` and attaches itself, so the
  gesture and the handle run the same `refresh()`. The configured `Reload` and the search-mode
  behaviour are shared by construction rather than by a 2nd implementation that could drift.
- **`NoRefresh` means no gesture, not no refresh**, so its previously-unreachable arm now runs
  `ResetToFirstPage`. A gesture-less list therefore can't pick a strategy. A per-call
  `refresh({Reload? using})`, or a `Reload` getter on the `Refresh` seam, is the build-upward path.
- **Silent.** Animating the indicator would flash it and then hand straight to the first-page loader
  under the default `ResetToFirstPage`, the two-spinner outcome
  [#pull-to-refresh-resets-v1](#pull-to-refresh-resets-v1) rejected. The button owns its progress.
- **Coalesced.** A 2nd `refresh()` while one runs joins it, page 0 included, so a double-tapped
  button sends 1 request.
- **A host interface, not a callback.** `ListSmithControllerHost` is `@internal`, the
  `ReloadContext` shape, so each intent is a method on the host and a forwarding verb on the handle.
- **Detached is inert, never-attached asserts.** A refresh racing a navigation is harmless. One
  through a controller no list ever received is a wiring mistake.

---

<a id="reload-run"></a>
## Each reload is a run that knows its stream

- **Decision:** a `Reload` runs through a per-run `_ReloadRun`, not the State. The run carries the
  trigger its pages report and the generation it was born into, and `isStale` compares the two.
- **Why:** the depth reload is the one long writer, and it bumped the generation without ever reading
  it. A reset, a query change, a `KeepCache` restore or a dispose during its awaits was overwritten
  by its late `commit()`. A stale run now drops its commit, skips its remaining fetches, and is never
  joined.
- **Own writes don't stale a run.** Its commit and its reset move the epoch along, so a refresh asked
  while a `ResetToFirstPage` run fetches its page 0 still joins it.
- **The join rule.** 2 refreshes coalesce. Any other pair books one more run after the live one,
  `.refresh` winning, because a write landing on a page the run already read would otherwise never
  be re-read. A joiner's future completes with the run it joined. `reset()` never joins: it takes the
  slot, so the next caller meets its page 0.
- **Every page-0 load is a run,** so the join rule sees it: the 1st load, a restart's page 0, a
  1st-page retry, an owed restore. The engine's own loads are nobody's ask, so a feed parked during
  one owes nothing for it.
- **The verbs wait for the fresh page, the pull for the hand-over,** so the indicator retracts as the
  loader shows ([#pull-to-refresh-resets-v1](#pull-to-refresh-resets-v1)).
- **`invalidate()` has its own strategy,** always `ReloadToCurrentDepth`. A pull snapping back to
  the start is a convention, a local write doing it is a bug, and a `NoRefresh` list has no pull
  config to lean on.
- **Accepted edge:** the pull indicator spins through a superseded run until its fetches finish.
- **Build upward: a run that owns its stream.** A feed reload cut off by entering search burns its
  fetches and the restore re-reads the same pages. Correct and safe, just wasteful. A run that
  commits into the parked stream fixes it, worth taking when a 2nd parked stream, a reactive
  source or `reloadPage` arrives.

---

<a id="page-request-object"></a>
## Fetchers take a request object, not an argument list

- **Decision:** `PageFetcher` and `SearchPageFetcher` take one `PageRequest` / `SearchPageRequest`
  instead of a positional argument list.
- **Why:** a fetch-time fact like the [trigger](#fetch-trigger) becomes a field, which a consumer who
  only reads the request never has to change for, where another positional argument breaks every
  closure.
- **`base` plus `final`, not a sealed pair.** Consumers only ever read these, so the hierarchy needs
  no exhaustive switch, and the shared base is there to declare the 3 common fields once.
  `SearchPageRequest` keeps `query` non-null rather than the normal path carrying a nullable one
  that is never set.
- **The return side is untouched.** `.new` still means items-only and `.withSignal`
  items-plus-signal. That split is about the *output* tuple
  ([#explicit-end-signals](#explicit-end-signals)), and unifying the input convention is no argument
  for reopening it. A `PageResult` wrapper stays rejected for the same reason as the 1st time.
- **A bulk rewrite needs a real check, not a green suite.** The 60-site pass silently turned
  `'cursor$pageIndex'` into `'cursor$request.pageIndex'`, interpolating the request and appending a
  literal `.pageIndex`. Analyzer clean, tests green, value wrong, because the cursor was only ever
  checked for null in that scenario. Grep for `$request.` after any such rename.

---

<a id="fetch-trigger"></a>
## Fetchers are told why they were called

- **Decision:** every `PageRequest` carries a `FetchTrigger` saying why it was asked for, so a
  caching repository can bypass its cache for a pull-to-refresh.
- **A fact, not an instruction.** A `shouldBypassCache` bool was rejected: this package can't know
  whether the right answer is bypass, revalidate or stale-while-revalidate, and a bool can't hold a
  many-valued fact. A 2nd `onBypassCacheFetchPage` was rejected too: it needs a mirror on
  `AsyncSearch`, and nothing would keep the two agreeing.
- **Plain enum.** The one candidate for per-value config is "does this restart the cursor chain",
  and both reset paths already funnel through `_resetPaging()`, so attaching it would restate what
  that helper enforces. Trip-wire: the 1st trigger needing that reset elsewhere earns an
  enhanced-enum field.
- **`retry` costs a field, and the alternative is a lie.** A fetch clears `error` as it starts, and
  so does a depth reload's commit, so a retry isn't derivable from paging state.
  One `_lastFailedPageIndex`, cleared on success and on restart. Without it a retry reports
  `nextPage` and the repository serves the cached miss that just failed. `queryChanged` is its own
  value for the same reason, rather than folded into `initialLoad`.
- **`restoreNormal` drops the retry marker,** or a failed search page could mark the restored list's
  next page as a retry. `commit()` needn't: a reload commits exactly `depth` pages, so the next fetch
  is `depth` and can't collide with a lower failed index.

---

<a id="scan-loops"></a>
## Per-item scans on the build path stay loops, and pack their flags

- **Decision:** `headerFlagsByFirstSighting` and `groupsAreContiguous` are single-pass loops over
  the lazy flatten of the loaded pages, and the flags come back as a `BoolList`.
- **Why:** both run on every `PagedView` build. Against the loop, a chain on one stateful closure
  costs about 3x and a `splitBetween` chain 7x to 9x: an iterator per element, plus a list per run.
  The indexed `List.generate` form paid for its flatten and still lost.
- **`BoolList`:** a bit per flag instead of a reference, so tens of times less memory and about 3x
  faster reads, for about 20% more build time than a growable `List<bool>`. Never
  `BoolList.of(iterable)` over a stateful chain: it reads `.length` and then `setAll`, so the chain
  runs twice and every key reads as already seen.
- **Tripwire:** the `header_flags_scaling` micro.

---

<a id="ci-format-sdk"></a>
## The format gate runs Flutter's Dart, not standalone Dart

Whatever CI rejects, a local `dart format .` has to fix. Standalone Dart stable runs ahead of
Flutter's bundled Dart and the formatter changed between them, so a tree that was clean locally
once met a red gate reformatting files the pull request never touched.

dartender's Format job runs Flutter's Dart, on the stable channel like the rest of its jobs. It
doesn't read [`.fvmrc`](.fvmrc), which only picks the SDK FVM gives you locally.

---

<a id="root-analysis-skips-bench-app"></a>
## The root analysis skips `benchmark/app`

`benchmark/app` is its own Flutter package, and the root `flutter pub get` resolves only the package
and `example/`. So CI's `dart analyze .` at the root would fail on the app's unresolved
`integration_test` imports. The shared lints the root includes exclude `benchmark/app/**`, and
[`bench-app.yml`](.github/workflows/bench-app.yml) analyses it after a `pub get` of its own. The
app gets the same exclude through its own `include:`, where it matches nothing, so its run still
analyses every file.

---

<a id="dependabot-automerge"></a>
## Dependabot's PRs auto-merge through dartender

Every Dependabot PR, majors included, auto-merges through the `Auto-merge` job in
[dartender](https://github.com/LahaLuhem/dartender)'s shared `ci.yml`. What still bites here:

- **The rulesets are the load-bearing half.** Auto-merge only waits on required checks, so it's
  safe only while `main` requires every check in [hard rule 6](.ai/AGENTS.md#hard-rules). Keep
  `required_signatures` out: GitHub's rebase-merge makes unsigned commits, so that rule would block
  every merge, bot or human.
- **An Actions major can change CI and still pass, which is what hard rule 8 is for.** dartender's
  Action inputs check fails on an input an action no longer takes, but not on a default it flipped.
  `setup-uv` v9 flipped `prune-cache` to `false`, and v10 made `enable-cache: auto` skip
  `pull_request_target`, `workflow_run`, `release` and tag pushes. v10 was a no-op here only because
  every `setup-uv` step already wrote `enable-cache: true`.
- **A required workflow can't have a `paths:` filter.** A filtered run never reports on a PR outside
  its paths, so the PR waits forever. That's why `bench-app.yml` runs on every PR, as the only
  analysis of a host app that gets bumps of its own ([why](#root-analysis-skips-bench-app)).
  [`benchmark.yml`](.github/workflows/benchmark.yml) keeps its filter and stays unrequired, since no
  Dependabot PR touches the `lib/**` it measures.
- **Auto-merge uses `GITHUB_TOKEN`, not the changelog App.** The App sits in both rulesets' bypass
  lists so its changelog commit gets through, and merging as the App would skip the checks. The
  cost: a `GITHUB_TOKEN` merge starts no workflows, so `main`'s push run is skipped for auto-merged
  PRs.

---

<a id="edit-layer"></a>
## Local edits live beside the pages, not in them

- **Decision:** the edit verbs book an edit beside the loaded pages, applied in the display pass
  de-dup already runs. The pages keep saying what the backend returned, because the end policy
  counts them and a depth reload or `KeepCachePolicy` writes them back. An edit made inside them
  would end the list early, or be undone.
- **Each page carries a read stamp,** the edit counter when its fetch went out, and an edit
  covers only pages read before it. A page read after already has the server's answer. Once every
  loaded and parked page was read after an edit, the edit is forgotten.
- **Values, not transforms.** An edit is re-applied over whatever the server sends until it
  expires, so a `likes + 1` would count twice.
- **`upsert` and `remove` are sync and `void`,** since the change is already true on the server or
  in the store. `upsertAsync` and `removeAsync` are for one that isn't yet.
- **A failed save never throws.** `onFailure` gets the exception and the future completes, like the
  other verbs, so a call nobody awaits needs no try/catch. An `Error` is undone too, then goes on to
  the app.
- **A pending edit counts as true from the far future,** `2^53 - 1`, the web's largest exact int, so
  it covers every page, read before it or after. Its save's answer stamps it from the counter then,
  so the display pass, expiry and new-item placement need nothing new.
- **Each item keeps its edits in the order they were made.** A failed one drops out and the newest
  left shows, so a rollback can't wipe an edit under it. An answer settles its own edit in place, so
  a create doesn't jump when it saves.
- **The saved item keeps the draft's id,** asserted. A swapped temp id is a removal plus a new item,
  which reorders new items and loses the row's state.
- **`reset()` clears every edit,** pending ones too, so a logout can't show the old account's draft.
- **Never bumps `_generation`.** That counter means the stream restarted, and bumping it drops the
  in-flight page's cursor, so the next page repeats. The edit store moves its own counter instead,
  on every change that shows, since the display memo keys on it.
- **New items** join the start of their group, else the top, since async groups have to stay
  together. They stay out of search results: only the server knows what matches.
- **Edits that empty the screen load the next page,** whatever `EmptyPageBehaviour` says. That
  setting is about the server sending an empty page, not the user deleting rows.
- **A removal can land late.** Under an `EditTransition` it's booked when the row's exit ends
  ([#edit-transitions](#edit-transitions)), so a page read during the exit still counts as read
  before it.

---

<a id="pull-indicator-layout"></a>
## list_smith places the pull indicator, the builder only draws it

- **Decision:** `indicatorBuilder` returns just the indicator. `RefreshBinding` owns the slot and
  the push, and only builds the indicator while a pull is in progress, so `ListSmithRefreshPhase`
  has no resting phase.
- **Why:** when each indicator owned the whole pull layout, each had to get its own lifetime right.
  The neutral one kept a spinner mounted at rest, asking for a frame on every screen refresh. Now
  nothing is built at rest, ours or a consumer's, and placement lives in one spot.
- **Placement follows the pull:** the slot hugs the edge the pull starts from, read off its
  direction, and the list is pushed only by what its own bounce hasn't opened. Clamping physics get
  the push, bouncing ones keep their native look, and no platform is special-cased.

---

<a id="item-id-required"></a>
## `itemIdGetter` is required

- **Decision:** `ListSmith.async` takes an `itemIdGetter`, with no default, because de-dup, edits and
  [row identity](#row-identity) all find items by it. It's there for correctness, not speed.
- **Why not `(item) => item` as the default:** most JSON models have no `==`, so an upserted copy
  never matches the loaded one and shows as a 2nd row, and a re-read hands every row a new identity,
  wiping its state. The README suggests it for values that do.
- **Cost:** the display pass now runs on every list, at the price
  [#overlap-dedup](#overlap-dedup) measures.

---

<a id="row-identity"></a>
## Async rows follow their item, not their index

- **Decision:** each async row is keyed by its item's id, and the list finds a row that moved through
  `findChildIndexCallback`. So a row keeps its state, and anything it's animating, while rows above
  it come and go.
- **The lookup:** a row's key carries the index it was last built at, and that's checked first. Only
  a row that moved builds the id-to-index map, once per rebuild. The
  [`row_lookup_scaling`](benchmark/micro/row_lookup_scaling.dart) micro tracks both cases.
- **`GroupedItem` keeps one shape,** a `Flex` with keyed header and item slots, so a row gaining or
  losing its header keeps its state too.

---

<a id="edit-transitions"></a>
## Edit transitions animate the rows edits add and take

- **Decision:** an `EditTransition(duration:, transitionBuilder:)` seam, `NoEditTransition()` by
  default. The builder is Flutter's `AnimatedSwitcherTransitionBuilder`, run forward for a row coming
  in and in reverse for one going out. list_smith brings the timing, never a look of its own. Only
  an `upsert` of a new, shown id, a `remove` of a shown one, or a rollback of either starts one, so
  page loads can't.
- **A removal lands when its exit ends.** Until then the row is still in the display, exactly where
  it was, so there's no leaving copy to keep in step, and an upsert meanwhile turns the same
  controller round.
- **Each exit holds what to do when it ends:** book a removal, a pending one, or drop a failed
  create. A restart's settle runs the same thing, so it can't turn a pending delete plain.
- **Rollbacks animate.** A failed create leaves like a `remove`, a failed delete comes back like an
  `upsert`, so the user sees the change didn't stick. The gaps are in
  [how-it-works](doc/how-it-works.md#known-gaps).
- **A row that shrank itself skips the exit.** A frame after `remove()`, a row that isn't built or
  has no extent left goes at once. Dismissible and Slidable collapse themselves and throw if kept in
  the tree after, and this way `remove()` needs no flag for them.
- **Wrapped only while it animates,** with the child under a `GlobalKey` so its state survives the
  wrapper coming and going. Around the consumer's widget only, never the header, or a group-first
  row that shrank itself would still read the header's height.
- **Restarts settle** (`reset()`, a query change, a pull that starts over, a `KeepCachePolicy`
  restore), booking what the exits held back so nothing animates onto a fresh list. A depth
  reload's commit doesn't, so a pull that keeps depth lets running animations finish.

---

<a id="own-paging"></a>
## list_smith pages on its own

- **Decision:** the paging state, the next-page fetch and the near-end trigger are list_smith's own.
  `infinite_scroll_pagination` is gone, its dependencies with it.
- **Why:** its view asked for page 0 a frame after a reset, and only if the new state differed by
  value, so 2 restarts a frame apart left the list on its loader for good
  ([upstream #382](https://github.com/EdsonBueno/infinite_scroll_pagination/issues/382), closed
  as not planned). A page 0 nobody owned also slipped past the [run slot](#reload-run).
- **Only the engine fetches,** never a listener reacting to the state, and every write is a new
  object, compared by identity.
- **Not leftovers of the old package:** the retry marker ([#fetch-trigger](#fetch-trigger)) and the
  microtask that pages past an empty page. Both are list_smith's own.

---

<a id="pull-surfaces"></a>
## Where a pull can start

- **Decision:** on the rows, and on the error and empty surfaces while
  `PullToRefresh.pullableSurfaces` lists them, as it does by default. Never on the 1st-page loader,
  whose page is already on its way.
- **Only a drag's start is refused,** so a pull the list changes under still ends and lets go.
- **While a surface shows, the list moves past its ends only into a pull it takes.** It asks whether
  a surface shows, not whether anything overflows, so short rows still bounce away from the pull on
  iOS, like a plain `ListView`.
- **One set of physics for every surface:** always-scrollable under pull-to-refresh, below the app's
  physics so a `NeverScrollableScrollPhysics` still wins. Swapping them per surface cancels a held
  drag inside layout, where the indicator's `setState` asserts, so the rule above reads what shows
  as the drag goes.
- **Every surface sits in the list and gets its visible space,** unmeasured, so a `LayoutBuilder` or
  `Expanded` works and a short one can't scroll. A taller one scrolls itself. Built outside it, a
  surface would take the list out of the tree and detach the app's `ScrollController`.

---

**Still to record.** The SDK-floor rationale, and what list_smith deliberately does *not* do.
