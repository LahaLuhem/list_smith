# APPENDIX for `list_smith`

Design rationale: the "why" behind decisions the code and hard rules don't explain on their own. Hard
rules and workflow live in [`.ai/AGENTS.md`](.ai/AGENTS.md); code style in
[`CODESTYLE.md`](CODESTYLE.md). Each heading carries an `<a id="…">` anchor; link by anchor and keep
anchors stable across renames. A decision log, appended as decisions land.

<!-- TOC start -->

- [`AGENTS.md` and `CLAUDE.md` are symlinks into `.ai/`](#ai-files-symlinked)
- [Consumer-facing surfaces impose no design system](#design-system-agnostic)
- [`lib/src/` directory layout](#src-directory-layout)
- [Pull-to-refresh resets the list on V1](#pull-to-refresh-resets-v1)
- [Async override surfaces grouped; universal ones stay flat](#async-surfaces-holder)
- [Sync search: flat input, a pure resolver](#sync-search-shape)
- [Async search: one controller, two views](#async-two-view-search)
- [Unified opt-in idioms: every optional behaviour is a sealed, defaulted seam](#opt-in-idioms)
- [Observer seam: async-only, no-op-method sink](#observer-seam)
- [Grouping: erased key, sync buckets, async pre-sorted](#grouping-shape)
- [Grouping dispatches on the type; the views don't branch](#grouping-polymorphic-dispatch)
- [Overlap de-dup runs at the display layer, not before storage](#overlap-dedup)
- [Explicit end signals: open policy plus fetcher building block](#explicit-end-signals)
- [Cursor-driven pagination: the signal, fed back](#cursor-driven-pagination)
- [Sync predicate builders (`SyncSearchPredicates`)](#sync-searchable-fields)
- [A narrow controller: intents out, nothing back](#controller-handle)
- [Fetchers take a request object, not an argument list](#page-request-object)
- [Fetchers are told why they were called](#fetch-trigger)
- [The format gate runs Flutter's Dart, not standalone Dart](#ci-format-sdk)
- [Dependabot automerges the boring tier, behind six aggregate checks](#dependabot-automerge)

<!-- TOC end -->

<a id="ai-files-symlinked"></a>
## `AGENTS.md` and `CLAUDE.md` are symlinks into `.ai/`

- **Decision:** the canonical text lives under [`.ai/`](.ai/); the root holds symlinks
  (`AGENTS.md -> .ai/AGENTS.md`, `CLAUDE.md -> .ai/CLAUDE.md`).
- **Why:** agents auto-discover `CLAUDE.md` / `AGENTS.md` at the root, but loose files there add tree
  noise. `.ai/` keeps the agent docs together; the symlinks preserve discovery. `.gitignore` ignores
  the root symlinks and commits the `.ai/` targets; `.pubignore` excludes both, so none ships.
- **Cross-platform:** symlinks survive `git clone` on macOS and Linux. On a Windows host without
  symlink support they may show as a text file holding the target path; the fallback is real files at
  the root, hand-synced.

---

<a id="design-system-agnostic"></a>
## Consumer-facing surfaces impose no design system

- **Decision:** list_smith's code, and every default it ships for a visible surface (loading, error,
  empty, "no more items", the pull-to-refresh indicator, and the search field where we own it), build
  on `package:flutter/widgets.dart` only, never `material.dart` or `cupertino.dart`. Every surface
  stays overridable; our defaults are neutral, widgets-layer widgets.
- **Scope is our surfaces, not the dependency closure.** A dependency may import Material internally
  (`infinite_scroll_pagination`'s default indicators do). We neutralise it by overriding every default
  slot it exposes, so no Material appears in our own look. Migrating that dependency's internal
  Material once Flutter unbundles it is the dependency's problem, not ours.
- **Why:** developer experience, list_smith drops into a Material, Cupertino, or bespoke app without
  importing a look the consumer never chose; and forward-compatibility, Flutter is decoupling
  `material` / `cupertino` from core (<https://github.com/orgs/flutter/projects/220>), so the widgets
  layer is where a neutral package belongs.
- **Consequences:** the widgets layer ships no spinner, so our loading and refresh defaults are small
  widgets-layer implementations (for example a `CustomPainter`), not `CircularProgressIndicator`. When
  wrapping a dependency with Material defaults, a null default-builder slot is a defect (its Material
  default leaks onto our surface), so fill every slot.

---

<a id="src-directory-layout"></a>
## `lib/src/` directory layout

- **Decision:** organise `lib/src/` by kind at the top (`data/`, `widgets/`, `utils/`), then by
  feature (`data/pagination/`, `data/search/`, ...), then by kind again within a feature (`models/`,
  `typedefs/`, `enums/`, `extensions/`, `utils/`), one primary public symbol per file. Sealed cases
  nest one level under the base's kind as `part`s (`models/policies/`, `source/sources/`). A small
  feature stays flat until its vocabulary earns the third level.
- **Why:** it matches the maintainer's other Flutter packages (`platform_adaptive_widgets`), so a
  contributor moving between them meets the same shape. By-kind at the top separates data from
  behaviour; by-feature keeps a concern's pieces together; by-kind within a feature keeps a grown
  feature scannable.
- **Rejected:** top-level `enums/` / `typedefs/` folders, which scatter one feature's vocabulary across
  the tree. The by-kind split is scoped within a feature, and a typedef with a single home type lives
  in that type's file (`RefreshBuilder` with `ListSmithRefreshState`), never pulled out to fill a
  folder.
- **`data/` over `models/`:** the folder also holds enums and typedefs, which are not models.

---

<a id="pull-to-refresh-resets-v1"></a>
## Pull-to-refresh resets the list on V1

- **Decision (V1):** on refresh, the controller's `refresh()` resets the paging state, so the list
  clears and the first-page loader shows while the fresh page loads. `onRefresh` completes as soon as
  the refresh is triggered, so the pull indicator retracts right away (the standard
  infinite_scroll_pagination pattern).
- **Why not hold the indicator until fresh data:** awaiting the reload would show the pull indicator
  and the first-page loader at once, two spinners. Completing immediately keeps one visible at a time.
- **Deferred (WIP):** "keep the old items visible, hold the indicator until fresh data, then swap" is
  nicer, but needs a soft refresh that doesn't reset up front. Revisit post-V1; it likely rides a
  dedicated refresh-policy seam.

---

<a id="async-surfaces-holder"></a>
## Async override surfaces grouped; universal ones stay flat

- **Decision:** the async-only override surfaces (first/new-page loading and error, the end-of-list
  footer) bundle into one `AsyncListSurfaces` holder, passed as `surfaces:`. Surfaces every list has,
  `emptyBuilder` now (and `noResultsBuilder` with search), stay flat constructor parameters.
- **The rule (Rule X):** a surface is flat if every list has it, and moves into the async holder if
  only async lists have it. Behaviour config (`pageSize`, `endPolicy`, the `refresh` seam) is not a
  surface and stays flat regardless.
- **The pull-to-refresh indicator is the deliberate exception.** It rides the `PullToRefresh` case of
  the `refresh` seam, next to the on/off choice, so an indicator can only be set on a list that
  refreshes. In the holder, a `NoRefresh` list could set an indicator that never shows, the ghost this
  package removes. (Wider principle: [unified opt-in idioms](#opt-in-idioms).)
- **Why:** the `.async` constructor had grown a run of optional builders that buried the behavioural
  parameters. Grouping them mirrors `ListScrollConfig`, shortens the call site, and lets a consumer
  reuse one surface set across lists. Autocomplete still lists every slot inside `AsyncListSurfaces`.
- **Why not group `emptyBuilder` too:** the sync path has an empty state but none of the async
  surfaces. A shared holder would let a `.sync` list set async-only builders that do nothing, the
  ghost bug. Flat universal surfaces read the same on `.async` and `.sync`, and the holder stays
  honestly async-only.
- **Landed** in the Step 2a refactor (async engine extracted into the unexported `AsyncListView`,
  `ListSmith` a stateless dispatcher over the sealed `ListSource`). The indicator later moved onto the
  `refresh` seam with issue #3.

---

<a id="sync-search-shape"></a>
## Sync search: flat input, a pure resolver, universal surfaces stay flat

- **Decision:** `.sync` takes its search input (`query`, `minSearchLength`, `searchDebounce`) as flat
  parameters, not a `SearchConfig` holder, even though the override surfaces were grouped into
  `AsyncListSurfaces`.
- **Why flat:** `AsyncListSurfaces` groups builders a consumer sets once; `query` is the opposite,
  changing on nearly every rebuild, so burying it in a holder reads badly. The debounce default also
  diverges by path (`Duration.zero` sync, 300ms async), which flat per-constructor defaults express
  and a shared holder could not.
- **Pure resolver:** the trim + min-length gating and predicate filtering live in a widget-free
  `resolveSyncSearch(...)` returning `(visibleItems, isSearching)`, unit-tested directly (like
  `PaginationEndPolicy.hasReachedEnd`): an empty or too-short query shows everything, an active query
  with no matches is the no-results surface.
- **Surfaces stay flat:** `emptyBuilder` (source empty) and `noResultsBuilder` (search matched nothing)
  are flat and shared with the async path per Rule X ([#async-surfaces-holder](#async-surfaces-holder));
  a sync list carries no async surfaces, so `.sync` takes no `AsyncListSurfaces`.
- **Materialisation:** `SyncSource` keeps the consumer's raw iterable; `SyncListView` materialises it
  once and re-materialises only when the iterable identity changes, so an unchanged list is not
  re-copied or re-filtered per build.
- **`scrollCacheExtent`, not `cacheExtent`:** Flutter 3.44 deprecated `ScrollView.cacheExtent`
  (`double`) for `scrollCacheExtent` (`ScrollCacheExtent`). `ListScrollConfig.cacheExtent` stays a
  public `double?`; `SyncListView` wraps it via `ScrollCacheExtent.pixels(...)`, importing it from
  `package:flutter/rendering.dart` (the widgets layer's own foundation, not a design system). ISP's
  `PagedListView` has its own, non-deprecated `cacheExtent`, so the async path is untouched.

---

<a id="async-two-view-search"></a>
## Async search: one controller, two views

- **Decision:** async search rides a single `PagingController`. A mode-aware fetch closure reads the
  debounced committed query: empty runs the normal `fetchPage`, non-empty runs the `AsyncSearch`
  fetcher. Search is opt-in (default `NoSearch`), and search mode needs both a non-empty query and an
  `AsyncSearch`.
- **Why one controller:** pagination and pull-to-refresh compose for free, one end policy and one
  `refresh()` serve both modes, and there's no second controller to keep in sync. `refresh()` re-reads
  the query, so pulling to refresh in search mode reloads the current search.
- **Cache policy is a pure decision plus an impure execution.** On a committed-query change,
  `SearchCachePolicy.actionFor(wasSearching, isSearching)` returns a `CacheAction` (`refresh` /
  `snapshotThenRefresh` / `restoreNormal`), unit-tested directly; the view executes it against the
  controller. `Keep` snapshots `controller.value` on entering search and restores on leaving (an
  instant return, no refetch); `Replace` always refetches; a search-to-search change refetches under
  either policy.
- **Reading the search case:** search mode is `query.isNotEmpty && source.supportsSearch` (where
  `supportsSearch` is `search is AsyncSearch`), and the closure pattern-matches the `AsyncSearch` case
  to reach its fetcher, so there is no nullable fetcher to bang. A query set without an `AsyncSearch`
  trips an `assert` in debug and degrades to normal pagination in release.
- **Shared `QueryDebouncer`:** the debounce (timer, trim, skip-unchanged) was extracted from
  `SyncListView` into an unexported helper both views own (a 2c refactor-first step). The owner seeds
  the initial query synchronously and schedules later changes; a zero-debounce change commits on the
  next tick, which removed a `setState`-during-`didUpdateWidget` hazard the async path would hit.

---

<a id="opt-in-idioms"></a>
## Unified opt-in idioms: every optional behaviour is a sealed, defaulted seam

- **Decision (issue #3):** each optional async behaviour is opted into the same way, by passing a
  non-default case of a sealed, defaulted seam. Refresh is `Refresh` (`PullToRefresh` default,
  `NoRefresh` off); async search is `Search` (`NoSearch` default, `AsyncSearch` on); grouping and the
  end and cache policies already had this shape. The `.async` surface reads one way: a default you can
  ignore, or a named case for the feature.
- **What it replaced:** a default-on `bool pullToRefresh` and a nullable `searchFetchPage` whose
  presence was the opt-in. Three shapes for "turn a feature on" (a bool, a nullable callback, and
  sync's required `searchBy`) made the surface harder to learn than it needed to be.
- **It also removes ghosts:** the loose shapes leaked two inert params. `searchCachePolicy` sat on
  every `.async` list, doing nothing without a search fetcher; `AsyncListSurfaces.refreshBuilder` did
  nothing when `pullToRefresh` was false. Folding each feature's config into its own case means a knob
  can only be set on a list that uses it.
- **The rule:** an optional behaviour is a sealed, defaulted seam opted into by passing a case.
  Behaviour that is the whole reason a constructor exists stays a required parameter: `.sync`'s
  `searchBy`, since an in-memory list with no predicate is just a `ListView.builder`. Live input that
  changes every build (`query`, `minSearchLength`, `searchDebounce`) stays flat, since a holder rebuilt
  every frame buys nothing.
- **Pre-publish, so the break was free.** Not yet on pub.dev, so reshaping `.async` cost nothing
  downstream. `SyncSearchPredicate`, `SearchPageFetcher`, and the `SearchCachePolicy` cases stay
  public, now reached through `AsyncSearch(...)`.

---

<a id="observer-seam"></a>
## Observer seam: async-only, no-op-method sink

- **Decision:** an optional `ListSmithObserver` injected via `ListSmith.async(observer: ...)`, modelled
  on `better_internet_connectivity_checker`'s `ConnectivityObserver`: an `abstract base class` with
  a no-op default per event, so a subclass overrides only what it wants. Five async events:
  `onPageLoaded`, `onError`, `onRefresh`, `onQueryCommitted`, `onSearchModeChanged`. A default
  `LoggingListSmithObserver` logs each via `dart:developer`.
- **Discrete events only.** The seam fires from callbacks outside `build` (the page fetch, the
  refresh gesture, the debounced-query commit), never render-derived state. No-results, empty, and
  end-reached are excluded on purpose: they exist only as a function of paging/filter state during
  `build`, so firing there would re-fire on every rebuild and risk a `setState`-during-build.
  end-reached is worth revisiting, but needs a latched post-frame dispatch, more machinery than the
  discrete events carry.
- **Async-only.** The observer earns its place by surfacing what the hidden controller keeps out of
  reach (fetch results, errors, refresh, the debounced commit and mode flip). A sync list has no
  controller, fetch, or refresh, and the consumer owns the query it filters on, so there's nothing to
  observe; an observer on `.sync` would be the ghost Rule X
  ([#async-surfaces-holder](#async-surfaces-holder)) avoids. A `SyncListSmithObserver` stays additive
  if a real use case appears.
- **Fully hidden, non-generic.** Every callback takes plain values (`int` indices and counts, the
  `String` query, `Object` / `StackTrace`), never `PagingController`, `PagingState`, or the ISP
  generics, so wiring diagnostics can't reach an internal handle (holds decision 3). Non-generic
  because logging and analytics want counts and mode; a generic variant stays open (unpublished) if
  item payloads are ever wanted.
- **`abstract base`, extend-only.** A new lifecycle event can ship as a no-op method in a later minor
  release without breaking existing subclasses. It's a dispatch seam, not a decision seam (the only
  decision, the mode flip, is the transition `SearchCachePolicyResolver` owns), so it carries no new
  pure resolver; it is covered by widget tests driving a `RecordingListSmithObserver`.

---

<a id="grouping-shape"></a>
## Grouping: erased key, sync buckets, async pre-sorted

- **Decision:** an optional `Grouping<T>` on both constructors, default `NoGrouping`; opt in with
  `Grouping.by(groupBy:, headerBuilder:)`. A sealed, injected, defaulted seam like the end and cache
  policies. Chosen over a nullable `ListGrouping<T>?` (another inert nullable) and over flat `groupBy`
  + `headerBuilder` (which allow the ghost combo of a header builder with no grouper); the sealed seam
  makes "off" a real case. Unpublished, so the cleaner shape was free.
- **`NoGrouping<T>` is generic, defaulted per construction** via `grouping ?? NoGrouping<T>()`. It was
  once a single `const NoGrouping()` of type `Grouping<Never>` (assignable to any `Grouping<T>` since
  `Never <: T`), but the polymorphic dispatch below needs `NoGrouping` at the real `T`, which a
  `Grouping<Never>` can't give without a runtime crash. See
  [#grouping-polymorphic-dispatch](#grouping-polymorphic-dispatch). The cost is one small allocation
  per ungrouped list, off any hot path.
- **The key type is erased, so `ListSmith` stays single-generic.** `Grouping.by<T, K>` infers `K` from
  `groupBy`, keeps it typed in `headerBuilder`, then stores `Object`-keyed closures. A second generic
  `ListSmith<T, K>` was rejected: Dart can't default a type parameter, so every non-grouping list would
  carry a meaningless `K`. The `key as K` downcast is sound because each key reaching the header came
  from the same instance's `groupBy`. Caveat: an untyped inline `groupBy` closure widens `T` to
  `Object`, so type the parameter or pass a typed function.
- **Header rides on the group's first item, not a sticky sliver.** `KeyedGrouping.decorate` wraps each
  cell in a `GroupedItem` that stacks the header before the group's first item in a `Flex` along the
  scroll axis, so ISP keeps its single flat pager and list_smith keeps owning the scrollable
  (decision 3). A per-cell look-back at the previous key marks where a group starts, O(1) per built
  cell. Sticky headers would need a sliver `CustomScrollView` and, on async, splitting the pager plus
  scroll-offset tracking (the fragility the package rejects), so they are deferred.
- **Sync buckets; async trusts arrival order.** A sync list holds every item, so it reorders the
  filtered items into contiguous groups (`bucketByGroup` via `collection`'s `groupListsBy`;
  first-appearance order, item order kept within a group), and input can arrive in any order. An async
  list can't reorder across pages, so the fetcher must return items already grouped by key; a
  debug-only `groupsAreContiguous` assert flags a key that recurs after its section ended.
- **A presentation transform, not a source or policy.** `grouping` is a shared `ListSmith` param (like
  `itemBuilder` / `scroll`), passed to both engines, not a field on the sealed source. Its pure
  ordering and boundary logic stays widget-free and unit-tested (`bucketByGroup`, `isGroupStart`,
  `groupsAreContiguous`); the per-build wrapping lives on the type as `Grouping.decorate` (see
  [#grouping-polymorphic-dispatch](#grouping-polymorphic-dispatch)). `resolveSyncSearch` returns a lazy
  view so the grouped sync path buckets with one materialisation, re-resolving on an items or
  `grouping` identity change (hence "hold the `Grouping` stable" on a large list).

---

<a id="grouping-polymorphic-dispatch"></a>
## Grouping dispatches on the type; the views don't branch

- **Decision:** the flat-vs-grouped choice lives on the sealed `Grouping<T>` as two `@internal`
  methods, so the view calls one delegate instead of testing `is KeyedGrouping` in three places.
  `arrange(items)` is the sync display ordering (`NoGrouping` returns items as-is, no copy when already
  a `List`; `KeyedGrouping` buckets via `bucketByGroup`). `decorate(itemBuilder, flatItems:, axis:)`
  returns the per-build item builder (`NoGrouping` unchanged; `KeyedGrouping` wraps each cell in a
  `GroupedItem` and runs the debug contiguity assert). Same "delegate to the type, keep the shell
  branch-free" move as the open end-policy ([#explicit-end-signals](#explicit-end-signals)).
- **Sealed stays sealed.** Unlike `PaginationEndPolicy` (opened for consumer strategies), there's no
  compelling consumer-defined-grouping case and the methods return neutral types, so nothing leaks;
  opening it later is a one-line change. The methods are `@internal` (`package:meta`): callable across
  the package, not consumer API, since grouping is configured through `Grouping.by`.
- **`NoGrouping` had to become generic.** A `T`-typed parameter on an instance reified at `Never`
  rejects a real argument at runtime (Dart makes such parameters covariant and checks them):
  `arrange(<String>[...])` on a `Grouping<Never>` throws. The old `const NoGrouping()` default was
  exactly `Grouping<Never>`, so it would crash every ungrouped list the moment `arrange` or `decorate`
  ran. Hence `NoGrouping<T>` and the `grouping ?? NoGrouping<T>()` default
  ([#grouping-shape](#grouping-shape)). A bare `const NoGrouping()` in a consumer's own call still
  infers `NoGrouping<Foo>`; only the library's generic default couldn't name `T` inside a `const`.
- **The ungrouped path still does no flatten.** `decorate` takes `flatItems` as a callback that
  `NoGrouping.decorate` never invokes, so an ungrouped async list skips the O(loaded) page flatten.
  Only `KeyedGrouping.decorate` calls it, once per build, for the one-item look-back and the assert.
  Dispatch is per build, not per item (one virtual call replaces one `is` check), so the render
  path is unchanged, confirmed perf-neutral against the `benchmark/micro` baseline.
- **`GroupedItem` was decoupled from `KeyedGrouping`.** It takes the `groupOf` and `headerFor` closures
  directly, not the whole grouping, so `decorate` builds it without a cycle: the grouping model imports
  the `GroupedItem` widget, and a `KeyedGrouping` field would make the two files import each other.
  The trade is deliberate: `Grouping` gains a presentation method, so the model is no longer purely
  widget-free, though its ordering and boundary logic still is and the dependency graph stays acyclic.

---

<a id="overlap-dedup"></a>
## Overlap de-dup runs at the display layer, not before storage

- **Decision:** `itemId` de-dup (drop items whose key already appeared on an earlier page) is a
  computed view over the paging state, `_dedupedForDisplay` running ISP's `PagingState.filterItems`
  in the build, not a filter on the stored pages. The controller keeps the raw pages; only what
  renders is de-duped.
- **Why not de-dup before storage (the issue #2 bug):** the end policy reads each stored page's item
  count. De-dup before storage lets a fully-duplicate page collapse to empty, and
  `StopOnEmptyPagesPolicy` reads that as end-of-data and stops even though the backend had more past
  the overlap. Raw pages mean the policy sees what the backend returned; a page that de-dups to
  nothing on screen still counts as full. Partial-boundary overlap never hit this; a fully-duplicate
  mid-stream page, reachable with small page sizes, did.
- **One path covers search for free.** Both fetch modes flow through the one controller and one display
  derivation, so search-mode overlaps de-dup exactly like normal-mode ones.
- **Cost, and why it's acceptable:** O(loaded items), re-run on each state change. There's no cheaper
  seam without storing de-duped pages plus a parallel raw-count side-channel for the end policy,
  because ISP re-materialises the whole page list on every change anyway (`copyWith` re-wraps every
  page in `List.unmodifiable`). Measured (`benchmark/micro/dedup_scaling.dart`, no real overlap):
  ~0.3 ms at 1k items, ~3.5 ms at 10k, ~40 ms at 100k. Memoised on paging-state identity (a keystroke
  before the debounce commits reuses the last view), and skipped when `itemId` is null.
  Sub-millisecond for most lists; the cliff is only at tens of thousands held in one live list, which
  strains widget count and memory regardless.
- **The side-channel design was rejected, for now.** Incremental de-dup in the fetch (a persistent
  seen-set, O(page size) per fetch) with a raw-count side-channel would erase the cost, but that state
  must snapshot/restore in lockstep with `KeepCachePolicy`, and a bug there corrupts pagination, not
  just display. Not worth the fragility while realistic lists stay under the cliff;
  `benchmark/micro/dedup_scaling.dart` is the tripwire.

---

<a id="explicit-end-signals"></a>
## Explicit end signals: an open policy plus a fetcher building block

- **Decision:** `PaginationEndPolicy` is an open `abstract class` a consumer can implement, not a
  sealed set. The end decision is a public `hasReachedEnd(EndContext)`. list_smith ships
  `StopOnEmptyPagesPolicy`, `FixedPageCountPolicy`, and `ExplicitHasMorePolicy`; a consumer can add
  their own (a short-last-page or null-cursor rule) with no change here.
- **Why open, not sealed.** Issue #1 existed because a sealed policy forced list_smith to enumerate
  every strategy. Opening it makes the common page-derivable rules a few lines of consumer code, and
  deletes a workaround: the decision used to live in an unexported resolver extension so a pure-data
  policy could be reached from another library; a public method on an open interface needs none of
  that, so the extension is gone and tests call `hasReachedEnd` directly.
- **The signal is a fetcher output, orthogonal to the policy.** A `hasMore` flag lives in the network
  response, which only the fetcher sees, so the policy decides and the fetcher supplies. `PageFetcher`
  / `SearchPageFetcher` became small callable classes (were bare typedefs) with two constructors: the
  default `.new` returns items only; `.withSignal` returns `(items, Object? signal)`. The common path
  pays a one-constructor wrap, so `T` stays the consumer's DTO, never a `Response<T>` wrapper.
- **The signal is erased to `Object?`.** `ExplicitHasMorePolicy` reads it as a `hasMore` bool; a
  consumer's cursor policy reads it as their cursor. Erasure (grouping's key trick) avoids a second
  `ListSmith` generic. A return value beat a mutation channel (a `Completer` or sink): it fits the
  package's value-object grain and, unlike a `void` completer, can carry a cursor.
- **list_smith owns the signal's lifecycle, so policies stay pure.** The last fetch's signal lives in
  `_lastPageSignal` (not derivable from the paging state). It feeds each `EndContext.lastPageSignal`,
  resets on refresh, and is snapshotted with the normal state across a `KeepCachePolicy` toggle, so
  every policy is a pure function of its `EndContext`, with no consumer-side reset wiring. A guard
  asserts `ExplicitHasMorePolicy` is paired with a `.withSignal` fetcher.
- **Scope: an end signal; cursor-driven paging came later.** #1 carried the cursor only as a stop
  signal (ending on a null cursor), not fed back as the next fetch's input, and the page key stayed
  the 0-based ordinal. Issue #14 made the signal bidirectional so it also drives the fetch, see
  [cursor-driven pagination](#cursor-driven-pagination).
- **Layout:** `PageFetcher` and `SearchPageFetcher` live under `models/` now that they are classes,
  not in `typedefs/` (which keeps only real typedefs, like `SyncSearchPredicate`).

---

<a id="cursor-driven-pagination"></a>
## Cursor-driven pagination: the signal, fed back

- **Decision (issue #14):** a cursor drives the next fetch, not just the end. The `withSignal` channel
  became bidirectional: the `Object?` a page returns is handed to the next fetch as `previousSignal`
  (null for the first page). `StopOnNullSignalPolicy` ends the list on a null cursor.
- **No new constructor, fetcher type, or generic.** The page-key change #1 anticipated wasn't needed.
  list_smith keeps `PagingController<int, T>`, and the cursor rides `_lastPageSignal`, the field that
  already tracked the signal for end-detection. `_fetchPage` passes it in; `_nextPageKey` still returns
  `pages.length`. `itemId`, grouping, and refresh are item-based, so untouched: the whole new surface
  is the third `withSignal` argument plus `StopOnNullSignalPolicy`.
- **Retry and refresh fall out for free.** `_lastPageSignal` only advances after a fetch succeeds,
  so a retried page re-fetches with the same cursor; refresh nulls the field, so the reload restarts
  from the initial null cursor.
- **The cursor stays `Object?`.** It is the same signal the end policy reads, so a real cursor generic
  would split the channel's typing and reintroduce the second generic #1 avoided. The consumer casts
  `previousSignal as MyCursor?` once, in their own fetch closure. `SearchPageFetcher.withSignal` took
  the same argument, so cursor-driven search works with no separate seam (the two-view controller
  already snapshots the signal per stream); the `requiresSignal` guard keeps a signal end policy paired
  with `.withSignal` fetchers on both.

---

<a id="sync-searchable-fields"></a>
## Sync predicate builders (`SyncSearchPredicates`)

- **What (issue #25):** a namespace of static builders returning a [SyncSearchPredicate], so a `.sync`
  list skips hand-rolling the usual matching. `fields` (contains), `prefix` (starts-with), `exact`
  (equals), and `allTerms` (every whitespace term must hit some field, the multi-word case `contains`
  misses); `any` / `every` combine predicates. All case-insensitive, all skip `null` fields. The raw
  `searchBy` stays the escape hatch for case-sensitive, diacritic, or fuzzy matching. Anticipated when
  `.sync` shipped (see [#sync-search-shape](#sync-search-shape)).
- **Knob-free, named factories.** Each is named for what it does rather than a `mode:` flag, keeping
  the primitive's no-baked-in-policy stance: nothing sits inert, you pick the builder or drop to
  `searchBy`. `fields` / `prefix` / `exact` share a private `_anyField(extractors, test)`, so each is
  a one-liner (refactor-first: `fields` moved onto it before the siblings landed).
- **A holder, not `SyncSearchPredicate.fields`.** The issue sketched a static on the type, but
  `SyncSearchPredicate` is a real typedef (see [explicit end signals](#explicit-end-signals)) and Dart
  typedefs can't carry statics. Making it a callable class would break bare-closure `searchBy` and
  contradict the typedef/class split, so the holder returns the typedef instead: additive, closures
  still work, consistent with `Grouping.by` / `PageFetcher.withSignal`. It is `abstract final` (a pure
  namespace); `prefer_constructors_over_static_methods` stays quiet since the builders return the
  typedef, not the holder.
- **`String?` extractors.** `String? Function(T)` lets a nullable field (`(c) => c.subtitle`) compile
  with no `?? ''`; nulls are dropped with `.nonNulls`. The query is already trimmed and gated by
  `resolveSyncSearch`, so builders never re-trim or handle an empty query.
- **Inline, pin `T` on the list.** Used inline, the widget's element type and a builder's type
  parameter infer together and the closures come out nullable, so write `ListSmith<City>.sync(...)`:
  naming it once covers every builder, better than annotating each. Inherent to any generic builder
  used inline, not the holder choice.

---

<a id="controller-handle"></a>
## A narrow controller: intents out, nothing back

- **Decision (issue #23):** an optional `ListSmithController` on `ListSmith.async`, carrying one
  intent, `refresh()`. A bounded exception to the hidden pager; the line held is that no
  `PagingController`, `PagingState`, or other ISP type is reachable through it.
- **Only refresh was unreachable.** The issue also floated `scrollToTop` and `jumpTo(index)`, but a
  consumer can already scroll via `ListScrollConfig.controller`, so those are sugar and this is
  capability. Scroll intents follow separately; index-scrolling needs fixed extents, putting it with
  the sliver/grid work.
- **Intents, not state.** No `isRefreshing`, count, or `hasMore`: notification is the observer's job
  ([#observer-seam](#observer-seam)), and a state-bearing handle re-exposes the pager by the back door.
- **One refresh path.** The handle attaches the engine's own `_onRefresh`, the closure the gesture
  drives, so the configured `Reload` and search-mode behaviour are shared by construction rather than
  by a second implementation that could drift.
- **`NoRefresh` means no gesture, not no refresh**, so its previously-unreachable arm now runs
  `ResetToFirstPage`. A gesture-less list therefore can't pick a strategy; a per-call
  `refresh({Reload? using})` or a `Reload` getter on the `Refresh` seam is the build-upward path.
- **Silent.** Animating the indicator would flash it, then hand straight to the first-page loader
  under the default `ResetToFirstPage`: the two-spinner outcome
  [#pull-to-refresh-resets-v1](#pull-to-refresh-resets-v1) rejected. The button owns its progress.
- **Coalesced**, since a button can double-fire where the gesture can't (the indicator must be idle).
  Not a fix for the in-flight-fetch race in issue #36.
- **A callback, not a capability interface.** A one-method `abstract interface class` (the
  `ReloadContext` shape) trips `one_member_abstracts` and would have been the first `// ignore:` in
  `lib/`. It earns its place when item mutations (#24) add intents; swapping then is internal.
- **Detached is inert, never-attached asserts.** A refresh racing a navigation is harmless; one
  through a controller no list ever received is a wiring mistake.

---

<a id="page-request-object"></a>
## Fetchers take a request object, not an argument list

- **Decision (issue #45, step 1):** `PageFetcher` and `SearchPageFetcher` take one `PageRequest` /
  `SearchPageRequest` instead of three and four positional arguments. Structure only, no behaviour
  change: the same 147 tests pass unedited either side of it.
- **Why now.** #45 needs to tell the fetcher *why* it was called (scroll, refresh, retry), and the
  positional lists were already at three and four. A fourth and fifth positional argument reads badly
  at the call site, and the fetch-time fact after that would break the signature again. With an object,
  every later addition is a field.
- **Landed before the trigger, not with it.** Step 1 carries no `trigger` field at all. That keeps the
  ~60-site mechanical rewrite free of semantics, so it reviews as a rename; step 2 adds the field and
  the resolution and touches no call site, since adding a field is source-compatible for a consumer
  who only reads the request. The alternative (ship the field hardcoded to one value) would have put
  a wrong value through the mechanical diff and exported an enum whose other cases nothing produces.
- **`base` + `final`, not a sealed pair.** Consumers only ever read these, so the hierarchy needs no
  exhaustive switch; the shared base is there to declare the three common fields once. `SearchPageRequest`
  keeps `query` non-null rather than the normal path carrying a nullable one that is never set.
- **The return side is untouched.** `.new` still means items-only and `.withSignal` items-plus-signal:
  that split is about the *output* tuple ([#explicit-end-signals](#explicit-end-signals)), and
  unifying the input convention is no argument for reopening it. A `PageResult` wrapper stays rejected
  for the same reason it was the first time.
- **Breaking, deliberately.** Every consumer's fetch closure changes. Taken now because the request
  object is the last break this axis needs, and because a break is cheapest at 0.x.
- **A bulk rewrite needs a real check, not a green suite.** The 60-site pass silently turned
  `'cursor$pageIndex'` into `'cursor$request.pageIndex'`, interpolating the request and appending a
  literal `.pageIndex`. Analyzer clean, tests green, value wrong: the cursor was only ever checked
  for null in that scenario. Grep for `$request.` after any such rename.

---

<a id="fetch-trigger"></a>
## Fetchers are told why they were called

- **Decision (issue #45, step 2):** every `PageRequest` carries a `FetchTrigger`: `initialLoad`,
  `nextPage`, `refresh`, `retry`, `queryChanged`. A caching repository can now bypass its cache for
  a pull-to-refresh, which the single fetch lane made impossible.
- **A fact, not an instruction.** Rejected a `shouldBypassCache` bool: this package can't know whether
  the right answer is bypass, revalidate, or stale-while-revalidate, and a bool can't hold a
  five-valued fact without silently relabelling whatever is added later. Also rejected a second
  `onBypassCacheFetchPage`, which needs a mirror on `AsyncSearch`, has nothing keeping the two
  agreeing on paging semantics, and would be called for every page of a `ReloadToCurrentDepth` anyway.
- **Plain enum.** The one candidate for per-value config is "does this restart the cursor chain", and
  both reset paths already funnel through `_resetPaging()`, so attaching it would restate what that
  helper enforces. Trip-wire: the first trigger needing that reset elsewhere earns an enhanced-enum
  field.
- **A one-shot latch, because the default reload doesn't fetch through itself.**
  `PagingController.refresh()` only resets state; the view drives the re-fetch later. So `_resetPaging`
  latches the trigger and the next fetch consumes it, leaving the page after that derived again. A
  flag scoped to the refresh call would be cleared before page 0 was even requested.
  `ReloadToCurrentDepth` fetches through `ReloadContext.fetch` instead, so the engine settles
  `.refresh` inside its own implementation and the seam keeps its signature: no `Reload` has a reason
  to report anything else.
- **`retry` costs a field, and the alternative is a lie.** ISP clears `error` before re-invoking the
  fetch and wires Retry to the same callback as scroll, so it isn't derivable from paging state. One
  `_lastFailedPageIndex`, cleared on success and on restart. Without it a retry reports `nextPage` and
  the repository serves the cached miss that just failed; `queryChanged` is its own value for the same
  reason rather than folded into `initialLoad`.
- **`restoreNormal` latches nothing**, since it restores without fetching and a latch would leak into
  whatever the user did next. It still drops the retry marker, or a failed search page could mark the
  restored list's next page as a retry. `commit()` needs neither: a reload commits exactly `depth`
  pages, so the next fetch is `depth` and can't collide with a lower failed index.

---

<a id="ci-format-sdk"></a>
## The format gate runs Flutter's Dart, not standalone Dart

**What broke:** [`repo.yml`](.github/workflows/repo.yml)'s format job installed Dart stable directly,
skipping the `setup-flutter` composite to save a `pub get` it doesn't need. Dart stable runs ahead of
Flutter's bundled Dart and the formatter changed between them, so a tree clean locally met a red gate
reformatting files the pull request never touched.

**Why Flutter's Dart, not a pinned version:** whatever CI rejects, a local `dart format .` has to be
able to fix. Dart stable can't promise that once it drifts from Flutter's bundled Dart, and a literal
pin can't either once it drifts from [`.fvmrc`](.fvmrc). The SDK the package already targets is the
only version that stays in step by construction. The job still skips the composite, so it keeps the
speed.

**No job can go the other way, onto pure Dart.** The package depends on `flutter` from the SDK and its
tests are widget tests, so analyze, test, the dependency validator, the example, and the benchmark all
need Flutter to resolve at all. [`changelog.yml`](.github/workflows/changelog.yml) is the one
genuinely Dart-only job, and already runs `dart-lang/setup-dart`.

Hit first in [`minted`](https://github.com/LahaLuhem/minted) (commit `1293bbe`) and ported here.

---

<a id="dependabot-automerge"></a>
## Dependabot automerges the boring tier, behind six aggregate checks

[`dependabot-automerge.yml`](.github/workflows/dependabot-automerge.yml) arms GitHub's native
auto-merge (rebase) for every `github-actions` bump, majors included, and for patch and minor
bumps in `uv`; every `pub` bump and every `uv` major waits for a human. Dependabot has no
`automerge` config key the way Renovate does, so the mechanism is a workflow. Ported from
[`hive_box_manager`](https://github.com/LahaLuhem/hive_box_manager), which runs it behind four.

- **`pub` stays manual** because a root-pubspec bump reaches every consumer's resolution and is
  semver-relevant (hard rule 5), and bots are exempt from
  [`changelog.yml`](.github/workflows/changelog.yml), so it would land on pub.dev with no release
  note. `uv` is benchmark tooling and `github-actions` is CI wiring; neither reaches a published
  byte.
- **Minor, not just patch,** because `dependabot.yml` groups minor with patch and `fetch-metadata`
  reports a group's *highest* step. Patch-only would skip any batch holding one minor, which is
  most of them.
- **`github-actions` majors ride along; hard rule 8 is what pays for it.** A green check is a weak
  oracle here: Actions warns on an unknown input rather than failing, and majors in this ecosystem
  are default-flips more often than API breaks. `setup-uv` v9 flipped `prune-cache` to `false`, v10
  made `enable-cache: auto` skip `pull_request_target`, `workflow_run`, `release` and tag pushes;
  both would have merged green while quietly changing CI. v10 was a real no-op here only because
  every `setup-uv` step already wrote `enable-cache: true` instead of leaning on `auto`.
- **The ruleset is the load-bearing half.** Auto-merge waits only on *required* checks and ignores
  failing ones that aren't, so this is safe only while `main`'s ruleset is **active** and requires
  all six contexts. Keep `required_signatures` out of it: rebase-merge emits unsigned commits
  (`f280108` and its three neighbours), so it would block every rebase merge, bot or human.
- **Aggregates, not the real job names.** [`repo.yml`](.github/workflows/repo.yml) fans its lint
  matrix out of [`lint-checks.json`](.github/lint-checks.json), so those contexts move whenever a
  linter does; `package.yml` and `example.yml` both hold a job displayed as *Flutter analyze*, which
  no ruleset could tell apart, and `bench-app.yml` adds a third. Each workflow instead closes with
  one `*-ok` job that `needs` its siblings; six names are the contract, the jobs behind them are
  free to move. They inspect
  `needs.*.result` by hand because a skipped job passes a required check, which is what keeps
  `conventions-ok` green on bot PRs.
- **`bench-analyzer.yml` and `bench-app.yml` gave up their path filters to join them.** A filtered
  workflow never reports on a PR that misses its paths, so it cannot back a required check, and
  leaving the analyzer tests unrequired was worse: every `uv` bump touches `benchmark/python/**`,
  so its tests are what matters most on exactly the PRs being automated. ~20s with the uv cache, so
  it runs everywhere rather than behind bespoke change detection.
  [`bench-app.yml`](.github/workflows/bench-app.yml) takes the same trade for one `flutter analyze`
  on the host app, which nothing else covered: `package.yml` analyses `lib test` only.
  [`benchmark.yml`](.github/workflows/benchmark.yml) keeps its filter and stays unrequired: no
  Dependabot PR can touch `lib/**`, and it costs ~8 minutes a side.
- **`GITHUB_TOKEN`, not the changelog App.** The App sits in the ruleset's bypass list so it can
  push `CHANGELOG.md` to `main`, and a bypass covers the ruleset whole, status checks included. The
  cost is that a `GITHUB_TOKEN` merge triggers no further workflows, so
  [`package.yml`](.github/workflows/package.yml)'s push-to-main run is skipped on automerged PRs;
  for these two ecosystems that run only re-tests Dart neither touches.
- **`pull_request_target`** because Dependabot's `pull_request` token is read-only and arming
  auto-merge needs write. Safe as in `changelog.yml`: the workflow loads from `main` and PR code is
  never checked out.

---

**Still to record.** The SDK-floor rationale, and what `list_smith` deliberately does *not* do.
