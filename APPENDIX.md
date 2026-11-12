# APPENDIX for `list_smith`

Why list_smith is built the way it is, where the code and the rules don't say. Hard rules live in
[`.ai/AGENTS.md`](.ai/AGENTS.md), style in [`CODESTYLE.md`](CODESTYLE.md), what each part does in
[`doc/how-it-works.md`](doc/how-it-works.md). New decisions append.

<!-- TOC start -->

- [`AGENTS.md` and `CLAUDE.md` are symlinks into `.ai/`](#ai-files-symlinked)
- [Consumer-facing surfaces impose no design system](#design-system-agnostic)
- [`lib/src/` directory layout](#src-directory-layout)
- [A pull resets the list by default](#pull-to-refresh-resets-v1)
- [Async override surfaces group, universal ones stay flat](#async-surfaces-holder)
- [Sync search: flat input, a pure resolver](#sync-search-shape)
- [Async search: one paging state, 2 views](#async-two-view-search)
- [Unified opt-in idioms: every optional behaviour is a sealed, defaulted seam](#opt-in-idioms)
- [Observer seam: async-only, no-op-method sink](#observer-seam)
- [Grouping: erased key, gathered sections](#grouping-shape)
- [Grouping dispatches on the type, so the views don't branch](#grouping-polymorphic-dispatch)
- [Overlap de-dup runs at the display layer, not before storage](#overlap-dedup)
- [Explicit end signals: an open policy plus a fetcher building block](#explicit-end-signals)
- [Cursor-driven pagination: the signal, fed back](#cursor-driven-pagination)
- [Sync predicate builders (`SyncSearchPredicates`)](#sync-searchable-fields)
- [A narrow controller: intents out, nothing back](#controller-handle)
- [Each reload is a run that knows its stream](#reload-run)
- [Fetchers take a request object, not an argument list](#page-request-object)
- [Fetchers are told why they were called](#fetch-trigger)
- [Per-item scans on the build path stay loops](#scan-loops)
- [The format gate runs Flutter's Dart, not standalone Dart](#ci-format-sdk)
- [The root analysis skips `benchmark/app`](#root-analysis-skips-bench-app)
- [Dependabot's PRs auto-merge through dartender](#dependabot-automerge)
- [Local edits live beside the pages, not in them](#edit-layer)
- [list_smith places the pull indicator, the builder only draws it](#pull-indicator-layout)
- [`itemIdGetter` is required](#item-id-required)
- [Rows follow their item, not their index](#row-identity)
- [Edit transitions animate the rows edits add and take](#edit-transitions)
- [list_smith pages on its own](#own-paging)
- [Where a pull can start](#pull-surfaces)
- [A removal reads the page before again](#removal-reread)
- [A depth reload commits a whole list, lined up](#depth-reload-whole)
- [The edit store walks its edits by stamp, unsorted](#edit-store-scans)
- [An order places edits where the server sorts them](#sorted-placement)
- [The row the user is reading holds still](#keep-position)
- [A new search starts at the top](#search-starts-at-top)
- [Code starts the one search, as typing does](#search-from-code)

<!-- TOC end -->

<a id="ai-files-symlinked"></a>
## `AGENTS.md` and `CLAUDE.md` are symlinks into `.ai/`

Agents look for them at the root, so the root holds symlinks and `.ai/` holds the text, keeping the
tree tidy. `.gitignore` commits only the `.ai/` targets, and `.pubignore` ships neither. A Windows
checkout without symlinks gets a file holding the path, where the fallback is hand-synced copies.

---

<a id="design-system-agnostic"></a>
## Consumer-facing surfaces impose no design system

- **Decision:** list_smith builds on `package:flutter/widgets.dart` only, never Material or
  Cupertino, and every visible default is a neutral widget the app can override.
- **Why:** it drops into any app without a look nobody chose, and Flutter is moving Material and
  Cupertino out of core (<https://github.com/orgs/flutter/projects/220>).
- **Our surfaces, not a dependency's insides.** `custom_refresh_indicator` imports Material, so we
  fill every slot it draws: an empty one leaks its Material default onto our surface.
- **The widgets layer has no spinner,** so the loading and refresh defaults are small
  `CustomPainter`s.

---

<a id="src-directory-layout"></a>
## `lib/src/` directory layout

- **Decision:** by kind (`data/`, `widgets/`, `utils/`), then feature, then kind again inside a
  feature, one primary public symbol per file, sealed cases as `part`s. A small feature stays flat
  until it needs the 3rd level.
- **Why:** it matches the maintainer's other packages. Kind at the top splits data from behaviour,
  and feature keeps a concern's pieces together.
- **`data/`, not `models/`,** since it holds enums and typedefs too. Top-level `enums/` and
  `typedefs/` would scatter a feature's vocabulary.

---

<a id="pull-to-refresh-resets-v1"></a>
## A pull resets the list by default

- **Decision:** a pull resets the paging state, so the 1st-page loader shows while the fresh page
  loads. Holding the indicator instead would spin it beside the loader.
- **`refresh()` from code waits for the fresh page,** since a button has no loader to hand over to.
- **`ReloadToCurrentDepth`** keeps the old items and holds the indicator until it's done
  ([#reload-run](#reload-run)).

---

<a id="async-surfaces-holder"></a>
## Async override surfaces group, universal ones stay flat

- **Decision:** the async-only surfaces (1st- and new-page loading and error, the end footer) group
  into `AsyncListSurfaces`, passed as `surfaces:`. Surfaces every list has, `emptyBuilder` and
  `noResultsBuilder`, stay flat, so a `.sync` list can't set a builder that never shows. Behaviour
  config (`pageSize`, `endPolicy`) isn't a surface and stays flat.
- **The pull indicator rides `PullToRefresh`,** so only a list that refreshes can set one
  ([#opt-in-idioms](#opt-in-idioms)).
- **Why:** a run of optional builders buried the `.async` behaviour parameters. The holder shortens
  the call site, and one set serves many lists.

---

<a id="sync-search-shape"></a>
## Sync search: flat input, a pure resolver

- **Decision:** `.sync` takes `query`, `minSearchLength` and `searchDebounce` flat. `query` changes
  nearly every build, and the debounce default differs by path (zero on sync), which a shared holder
  couldn't say.
- **A pure resolver:** `resolveSyncSearch(...)` filters without a widget and returns
  `(visibleItems, isSearching)`. Trim and min length come first, in the `QueryDebouncer` both lists
  share, so the committed query is the one that searches.
- **The iterable is copied once,** and again only when its identity changes, so an unchanged list
  never re-filters. A change comes as a new object, and editing the old one in place asserts in
  debug.
- **`ListScrollConfig.cacheExtent` stays a `double?`,** wrapped as `ScrollCacheExtent.pixels(...)`
  for Flutter's `scrollCacheExtent`.

---

<a id="async-two-view-search"></a>
## Async search: one paging state, 2 views

- **Decision:** async search shares the one paging state. The fetch reads the committed search: an
  empty query runs `fetchPage`, anything else the `AsyncSearch` fetcher, or the one a
  [`search()`](#search-from-code) call passed. Search mode needs both.
- **Why one state:** paging, pull-to-refresh, the end policy and `refresh()` serve both modes, with
  no 2nd state to keep in step. `refresh()` while searching reloads the search.
- **Cache policy is a pure decision the engine runs.** `actionFor(wasSearching, isSearching)`
  returns a `CacheAction`. Keep snapshots the feed on the way in and restores it on the way out,
  with no refetch. Replace always refetches, and so does a search-to-search change under either.
- **The kept feed carries a debt.** A pull, `refresh()` or `invalidate()` while searching can't
  reach the parked feed, so the snapshot books it (`.refresh` outranks `.invalidated`) and the
  restore pays it with a `ReloadToCurrentDepth` reporting that trigger. A snapshot taken under a
  live feed run is born owing, since the reset strands that run. `reset()` drops the snapshot.
- **No nullable fetcher.** The fetch pattern-matches `AsyncSearch` to reach it. A query without one
  asserts in debug and pages normally in release.
- **A shared `QueryDebouncer`** owns the timer, trim, skip-unchanged and a commit from code on its
  way, but not the committed query: each list keeps its own and passes it in. A list seeds its 1st
  query synchronously, and a zero-debounce change commits on the next tick, so no `setState` lands
  during `didUpdateWidget`.

---

<a id="opt-in-idioms"></a>
## Unified opt-in idioms: every optional behaviour is a sealed, defaulted seam

- **Decision:** an optional behaviour is a sealed seam with a default, opted into by passing a case:
  `Refresh` (`PullToRefresh`, `NoRefresh`), `Search` (`NoSearch`, `AsyncSearch`), grouping, the end
  and cache policies. The `.async` surface reads one way.
- **It removes ghosts.** A knob lives on its feature's case, so it can only be set where it works.
  The bool and nullable shapes it replaced left `searchCachePolicy` and `refreshBuilder` inert.
- **Not everything is a seam.** A constructor's whole reason stays required (`.sync`'s `searchBy`),
  and live input that changes every build stays flat.

---

<a id="observer-seam"></a>
## Observer seam: async-only, no-op-method sink

- **Decision:** an optional `ListSmithObserver` on `ListSmith.async(observer: ...)`, an
  `abstract base` class with a no-op per event, plus the ready-made `LoggingListSmithObserver`.
- **Discrete events only,** fired outside `build`: a fetch, a reload's start, a query commit. Empty,
  no-results and end-reached exist only as `build`-time state, where firing would repeat every
  rebuild. End-reached would need a latched post-frame dispatch.
- **One reload event with its reason,** `onReload(FetchTrigger)`, for every reload the engine
  starts, query-driven ones included. A `KeepCache` restore fires nothing unless it pays a debt
  ([#async-two-view-search](#async-two-view-search)).
- **Async-only.** A sync list has no paging or fetch, and the app owns its query, so an observer
  there would be a ghost.
- **Plain values, non-generic.** No callback hands out paging state, and logging wants counts and
  modes, not items.
- **`abstract base`, extend-only,** so a new event ships as a no-op method in a minor. The logging
  sink `implements` it from inside its library instead, so a new event won't compile until it's
  logged.
- **No-op bodies,** with one file-level `ignore_for_file: no-empty-block` and its reason.

---

<a id="grouping-shape"></a>
## Grouping: erased key, gathered sections

- **Decision:** an optional `Grouping<T>` on both constructors, `NoGrouping` by default, opted into
  with `Grouping.by(groupBy:, headerBuilder:)`. The seam makes "off" a real case, where a header
  builder without a grouper would be a ghost.
- **The key type is erased,** so `ListSmith` keeps one generic. `Grouping.by<T, K>` keeps `K` typed
  for `headerBuilder` and stores `Object`-keyed closures, and `key as K` is sound since every key
  came from that instance's `groupBy`. Dart can't default a type parameter, so `ListSmith<T, K>`
  would burden every list. An untyped inline `groupBy` widens `T` to `Object`, so type it.
- **Headers are cells,** not part of a row or a sticky sliver. A header inside a row changed its
  size and moved the row being read. Sticky headers need a `CustomScrollView` and, on async, a split
  pager: deferred.
- **Each group gathers into one run.** Sync buckets its filtered items on every query
  (`bucketByGroup`: groups by 1st appearance, items in order). Async gathers only once a key comes
  back after its run, which the header pass already spots, so grouped pages are never copied
  ([#scan-loops](#scan-loops)).
- **`orderPolicy` is deprecated** for the next major, since gathering left it nothing to choose.
  Until then `FailOnUnorderedPolicy` keeps arrival order and throws.
- **Sections form where the data lands,** from `_displayFor`'s result on async and in `_resolve` on
  sync, so a rebuild with the same items runs no pass. Async keeps them in their own memo cell, so
  an inline `Grouping.by` doesn't redo de-dup. A new `Grouping` still re-resolves sync, so hold it
  stable on a large list.

---

<a id="grouping-polymorphic-dispatch"></a>
## Grouping dispatches on the type, so the views don't branch

- **Decision:** `Grouping<T>` carries 2 `@internal` methods, `arrange(items)` for the sync order and
  `sectionsOver(pagedItems)` for rows plus headers, so the views call one delegate instead of
  testing `is KeyedGrouping` ([CODESTYLE](CODESTYLE.md#patterns-behaviour-in-the-type)).
- **Sealed stays sealed.** No app needs its own grouping yet, and opening it is one line.
- **`NoGrouping` is generic** (`grouping ?? NoGrouping<T>()`). A `T` parameter on an instance
  reified at `Never` rejects real arguments at runtime, so a `const NoGrouping()` library default
  would crash every ungrouped list. An app's own `const NoGrouping()` still infers its `T`.
- **The ungrouped path skips the pass,** since only `KeyedGrouping` walks the pages. Dispatch runs
  once per change of the shown items, measured neutral.

---

<a id="overlap-dedup"></a>
## Overlap de-dup runs at the display layer, not before storage

- **Decision:** de-dup by id is a view over the paging state (`_displayFor` running
  `PagingState.filterItems`), not a filter on the stored pages.
- **Why not before storage:** the end policy reads each stored page's count, and a fully duplicate
  page de-duped to empty reads as the data's end.
- **Search gets it free,** since both modes share the state and the view.
- **Cost:** a pass over the loaded items per state change, memoised on the state, so a keystroke
  before the debounce reuses the last view. The [benchmark report](benchmark/reports/SUMMARY.md)
  measures it. It only bites at tens of thousands of live items, where widget count bites anyway.
- **Rejected for now:** de-dup in the fetch plus a raw-count side-channel, which would have to
  snapshot and restore in lockstep with `KeepCachePolicy`, where a bug corrupts paging.
  `dedup_scaling` is the tripwire.

---

<a id="explicit-end-signals"></a>
## Explicit end signals: an open policy plus a fetcher building block

- **Decision:** `PaginationEndPolicy` is an open `abstract class` with a public
  `hasReachedEnd(EndContext)`, so an app adds its own policy and a test calls it directly.
- **The signal comes from the fetcher,** which alone sees the response. `PageFetcher` and
  `SearchPageFetcher` are callable classes: `.new` for items, `.withHasMore` for
  `(items, hasMore:)`, `.withSignal` for `(items, Object? signal)`. `T` stays the app's DTO.
- **`hasMore` ends the list by itself.** It means one thing, so `withHasMore` acts on it with no
  policy to pair, and `ExplicitHasMorePolicy` is deprecated. It pages by number, so a depth reload
  fetches its pages in parallel.
- **The signal is `Object?`,** erased like grouping's key to spare a 2nd generic. A return value
  beat a mutation channel: it fits the value-object grain and can carry a cursor.
- **list_smith owns the signal's lifecycle.** `_lastPageSignal` feeds `EndContext.lastPageSignal`,
  resets on refresh and snapshots with the feed, so every policy is a pure function of its context.
  A signal policy paired with a signal-less fetcher asserts.

---

<a id="cursor-driven-pagination"></a>
## Cursor-driven pagination: the signal, fed back

- **Decision:** the signal a page returns reaches the next fetch as `previousSignal`, null for the
  1st page, and `StopOnNullSignalPolicy` ends on a null cursor. No new constructor, fetcher or
  generic: the cursor rides `_lastPageSignal`.
- **Retry and refresh come free.** `_lastPageSignal` only moves after a success, so a retry reuses
  its cursor, and refresh nulls it.
- **The cursor stays `Object?`,** cast once in the app's closure. `SearchPageFetcher.withSignal`
  works the same, and the two-view engine already snapshots the signal per stream.

---

<a id="sync-searchable-fields"></a>
## Sync predicate builders (`SyncSearchPredicates`)

- **What:** builders for the common `SyncSearchPredicate`s: `fields` (contains), `prefix`, `exact`,
  `allTerms` (every word hits some field), and `any` / `every` to combine. Case-insensitive,
  skipping `null` fields. `searchBy` stays the escape hatch.
- **Named builders, no `mode:` flag,** so nothing sits inert.
- **A holder, since a typedef can't carry statics.** A callable class would break bare-closure
  `searchBy`. `abstract final`, a pure namespace.
- **`String?` extractors,** nulls dropped. The query arrives trimmed and gated, so a builder never
  sees an empty one.
- **Used inline, pin `T` on the list** (`ListSmith<City>.sync`), or the extractors infer nullable.

---

<a id="controller-handle"></a>
## A narrow controller: intents out, nothing back

- **Decision:** an optional `ListSmithController` on `.async` carrying intents: `refresh()`,
  `invalidate()`, `reset()`, the [search verbs](#search-from-code) and the [edits](#edit-layer). No
  paging state is reachable through it.
- **No scrolling verbs.** Apps scroll through `ListScrollConfig.controller`, and index scrolling
  needs fixed extents.
- **Intents, not state.** No `isRefreshing`, count or `hasMore`: notifying is the
  [observer's](#observer-seam) job, and state would re-expose the pager.
- **One path.** The engine attaches itself as the `ListSmithControllerHost`, so the gesture and the
  handle run the same `refresh()`.
- **`NoRefresh` means no gesture, not no refresh,** so `refresh()` there runs `ResetToFirstPage`. A
  per-call `refresh({Reload? using})` is the build-upward path.
- **Silent.** Animating the indicator would flash it before the 1st-page loader
  ([#pull-to-refresh-resets-v1](#pull-to-refresh-resets-v1)). The button owns its progress.
- **Coalesced.** A 2nd `refresh()` while one runs joins it, so a double tap sends 1 request.
- **Detached is inert, never-attached asserts where the intent is lost.** A refresh racing a
  navigation is harmless, one through a controller no list received is wiring. `endSearch()` has
  nothing to lose there, so it stays silent.

---

<a id="reload-run"></a>
## Each reload is a run that knows its stream

- **Decision:** a `Reload` runs as a `_ReloadRun` carrying its trigger and the generation it was
  born into, and `isStale` compares the two.
- **Why:** the depth reload's late `commit()` overwrote any reset, query change, restore or dispose
  during its awaits. A stale run drops its commit, skips its remaining fetches and is never joined.
- **Its own writes don't stale it,** so a refresh during a `ResetToFirstPage` run's page 0 joins.
- **Any other pair runs once more,** `.refresh` winning, or a write on a page the run already read
  would never be re-read. A joiner completes with the run it joined, and `reset()` takes the slot.
- **Page-0 loads are runs,** so the join rule sees them. The engine's own are nobody's ask, so a
  feed parked during one owes nothing.
- **`invalidate()` always reloads to depth.** A pull jumping to the start is a convention, a local
  write doing it is a bug.
- **Accepted:** the indicator spins through a superseded run until its fetches finish.
- **Build upward:** a feed reload cut off by entering search wastes its fetches. A run that commits
  into the parked stream fixes it, once a 2nd parked stream, a reactive source or `reloadPage`
  arrives.

---

<a id="page-request-object"></a>
## Fetchers take a request object, not an argument list

- **Decision:** a fetcher takes one `PageRequest` or `SearchPageRequest`, so a new fact like the
  [trigger](#fetch-trigger) is a field no closure breaks over.
- **`base` plus `final`, not sealed.** Apps only read them, and the base declares the shared fields
  once. `SearchPageRequest.query` is non-null.
- **The return side stays** ([#explicit-end-signals](#explicit-end-signals)), and a `PageResult`
  wrapper stays rejected.

---

<a id="fetch-trigger"></a>
## Fetchers are told why they were called

- **Decision:** every `PageRequest` carries a `FetchTrigger` saying why, so a caching repository
  can bypass its cache on a pull.
- **A fact, not an instruction.** Bypass, revalidate or stale-while-revalidate is the app's call,
  which a `shouldBypassCache` bool can't hold. A 2nd fetcher for bypassing would need a mirror on
  `AsyncSearch`.
- **A plain enum.** Both reset paths go through `_resetPaging()`, so a "restarts the cursor" field
  would restate it. The 1st trigger needing that elsewhere earns one.
- **`retry` costs a field.** A fetch clears the error as it starts, so a retry isn't derivable.
  `_lastFailedPageIndex` clears when that page succeeds and on restart. Without it a retry reports
  `nextPage` and the cache serves the miss that just failed. `queryChanged` stays apart from
  `initialLoad` for the same reason.
- **`restoreNormal` drops the retry marker,** or a failed search page could mark the restored
  feed's next page. A reload's `commit()` needn't, since its next fetch is `depth`, past any failed
  index.

---

<a id="scan-loops"></a>
## Per-item scans on the build path stay loops

- **Decision:** a scan that walks every loaded item on each change, like `groupHeadersIfContiguous`,
  is a single-pass loop over the pages, not a chain or a flatten.
- **Why:** a chain costs an iterator per element, and `splitBetween` a list per run, several times
  the loop. A lazy flatten adds calls per item too.
- **`RowLookup.itemAt`** is a typed binary search, which beat `lowerBound`. It runs several times
  per moved row.
- **Tripwires:** the `group_headers_scaling` and `row_lookup_scaling` micros.

---

<a id="ci-format-sdk"></a>
## The format gate runs Flutter's Dart, not standalone Dart

A local `dart format .` has to fix whatever CI rejects. Standalone Dart stable runs ahead of
Flutter's, and its formatter once failed files no PR had touched. So dartender's Format job runs
Flutter's Dart on stable, ignoring [`.fvmrc`](.fvmrc), which only picks your local SDK.

---

<a id="root-analysis-skips-bench-app"></a>
## The root analysis skips `benchmark/app`

`benchmark/app` is a package of its own that the root `flutter pub get` doesn't resolve, so a root
`dart analyze .` would fail on its imports. The shared lints exclude `benchmark/app/**`, and
[`bench-app.yml`](.github/workflows/bench-app.yml) analyses it after its own `pub get`. The app
inherits the exclude too, where it matches nothing.

---

<a id="dependabot-automerge"></a>
## Dependabot's PRs auto-merge through dartender

Every Dependabot PR, majors included, auto-merges through dartender's `ci.yml`. What bites here:

- **The rulesets carry it.** Auto-merge waits only on required checks, so it's safe while `main`
  requires every check in [hard rule 6](.ai/AGENTS.md#hard-rules). No `required_signatures`:
  rebase-merge makes unsigned commits.
- **An action major can flip a default and stay green,** which dartender's input check can't see.
  Hence hard rule 8: `setup-uv` flipped `prune-cache` and `enable-cache` that way.
- **A required workflow can't filter `paths:`,** or it never reports on a PR outside them and blocks
  it. So `bench-app.yml` runs on every PR, and [`benchmark.yml`](.github/workflows/benchmark.yml)
  keeps its filter and stays unrequired.
- **Auto-merge uses `GITHUB_TOKEN`,** since merging as the changelog App, which the rulesets let
  past, would skip the checks. A `GITHUB_TOKEN` merge starts no workflows, so an auto-merged PR gets
  no push run on `main`.

---

<a id="edit-layer"></a>
## Local edits live beside the pages, not in them

- **Edits live beside the pages.** The end policy counts what the server sent, and a depth reload or
  `KeepCachePolicy` writes pages back, so an edit inside them would end the list early or be undone.
- **Each page carries a read stamp,** the edit counter when its fetch went out, and an edit covers
  only pages read before it. Once every loaded and parked page was read after an edit, it's
  forgotten.
- **Values, not transforms.** An edit re-applies over every server copy until it expires, so a
  `likes + 1` would count twice.
- **`upsert` and `remove` are sync `void`,** for a change already true. `upsertAsync` and
  `removeAsync` are for one that isn't yet.
- **A failed save never throws.** `onFailure` gets the exception and the future completes, so a
  fire-and-forget call needs no try/catch. An `Error` is undone, then goes on to the app.
- **A pending edit is stamped in the far future** (`2^53 - 1`, the web's largest exact int), so it
  covers every page. Its answer restamps it from the counter, so nothing downstream changes.
- **Each item keeps its edits in order.** A failed one drops out and the newest left shows, so a
  rollback can't wipe an edit under it. An answer settles its edit in place, so a create doesn't
  jump.
- **The saved item keeps the draft's id,** asserted. A swapped temp id would be a removal plus a new
  item.
- **`reset()` clears every edit,** pending ones too, so a logout can't show the last account's
  draft.
- **Never bumps `_generation`,** which means the stream restarted and drops the in-flight cursor.
  The edit store moves its own counter, which the display memo keys on.
- **New items join the start of their group, else the top,** unless an order places them
  ([#sorted-placement](#sorted-placement)), and a new grouping places them again. They stay out of
  search results, since only the server knows what matches.
- **Edits that empty the screen load the next page,** whatever `EmptyPageBehaviour` says, which is
  about the server.
- **A removal under an `EditTransition` is booked when its exit ends**
  ([#edit-transitions](#edit-transitions)), so a page read during the exit counts as before it.

---

<a id="pull-indicator-layout"></a>
## list_smith places the pull indicator, the builder only draws it

- **Decision:** `indicatorBuilder` draws only the indicator. `RefreshBinding` owns the slot and the
  push, and builds the indicator only mid-pull, so `ListSmithRefreshPhase` has no resting phase.
- **Why:** each indicator owning the layout had to get its lifetime right, and the neutral one kept
  a spinner asking for frames at rest. Now nothing is built at rest.
- **Placement follows the pull:** the slot hugs the edge it starts from, and the list is pushed only
  by what its own bounce hasn't opened, so no platform is special-cased.

---

<a id="item-id-required"></a>
## `itemIdGetter` is required

- **Decision:** `ListSmith.async` requires `itemIdGetter`, since de-dup, edits and
  [row identity](#row-identity) all find items by it.
- **Why no `(item) => item` default:** most JSON models have no `==`, so an upsert would show as a
  2nd row and a re-read would wipe every row's state. The README suggests it for values that do.
- **Cost:** the display pass runs on every list ([#overlap-dedup](#overlap-dedup)).
- **`.sync` takes it optional for now,** since requiring it breaks every call. It asserts in debug
  while `shouldKeepPosition` is on, rather than sliding unnoticed.

---

<a id="row-identity"></a>
## Rows follow their item, not their index

- **Decision:** rows are keyed by their item's id, and `findChildIndexCallback` finds a moved one,
  so a row keeps its state, and its animations, while rows above it change.
- **The lookup** tries the index a row was last built at first. Only a move builds the id map, once
  per rebuild ([`row_lookup_scaling`](benchmark/micro/row_lookup_scaling.dart)).
- **A repeated id keeps its 1st item,** since 2 rows on one key fail Flutter's child-order assert
  and blank the list. `.async`'s de-dup drops repeats, and `.sync` does too, reporting it in debug.

---

<a id="edit-transitions"></a>
## Edit transitions animate the rows edits add and take

- **Decision:** `EditTransition(duration:, transitionBuilder:)`, `NoEditTransition()` by default.
  The builder is Flutter's `AnimatedSwitcherTransitionBuilder`, run forward for a row coming in and
  backward for one going out, so list_smith brings the timing, never a look. Only an edit that adds
  or takes a shown row, or its rollback, animates, never a page load.
- **A removal lands when its exit ends.** Until then the row stays in the display where it was, so
  there's no leaving copy to keep in step, and an upsert meanwhile turns the same controller round.
- **Each exit holds what to do at its end:** book a removal, a pending one, or drop a failed create.
  A restart's settle runs the same, so a pending delete stays pending.
- **Rollbacks animate,** so the user sees the change didn't stick
  ([known gaps](doc/how-it-works.md#known-gaps)).
- **A row that shrank itself skips its exit.** One unbuilt or with no extent a frame after
  `remove()` goes at once, so Dismissible and Slidable, which throw if kept, need no flag.
- **Wrapped only while it animates,** the child under a `GlobalKey` so its state survives. Never
  around the header, whose height would hide a group-first row's shrink.
- **Restarts settle** (`reset()`, a query change, a resetting pull, a `KeepCachePolicy` restore), so
  nothing animates onto a fresh list. A depth reload's commit doesn't, so its animations finish.

---

<a id="own-paging"></a>
## list_smith pages on its own

- **Decision:** the paging state, the next-page fetch and the near-end trigger are list_smith's own,
  with no `infinite_scroll_pagination`.
- **Why:** its view asked for page 0 a frame after a reset, and only if the state differed by value,
  so 2 restarts a frame apart left the list loading for good
  ([upstream #382](https://github.com/EdsonBueno/infinite_scroll_pagination/issues/382), closed as
  not planned). Its page 0 also slipped past the [run slot](#reload-run).
- **Not leftovers:** the retry marker ([#fetch-trigger](#fetch-trigger)) and the microtask that
  pages past an empty page are list_smith's own.

---

<a id="pull-surfaces"></a>
## Where a pull can start

- **Decision:** on the rows, and on the error and empty surfaces while
  `PullToRefresh.pullableSurfaces` lists them, as it does by default. Never on the 1st-page loader,
  whose page is on its way.
- **Only a drag's start is refused:** a pull the list changes under still ends and lets go.
- **The scroll rule asks whether a surface shows,** not whether anything overflows, so short rows
  still bounce on iOS like a `ListView`.
- **One set of physics,** since swapping them per surface cancels a held drag mid-layout, where the
  indicator's `setState` asserts. They sit below the app's, so `NeverScrollableScrollPhysics` wins.
- **Surfaces sit in the list, unmeasured,** so a `LayoutBuilder` or `Expanded` works, a short one
  can't scroll and a tall one scrolls. Built outside, a surface would detach the app's
  `ScrollController`.

---

<a id="removal-reread"></a>
## A removal reads the page before again

- **Decision:** after rows the list holds were removed, the next page also re-reads the page or
  pages before it and keeps the rows that moved up. An index or offset names a row only while
  nothing above it changes, or the rows it skipped would never reach the app.
- **Moves and new items count,** judged by the row's loaded copy, or a new item's replaced one, so
  an edit that keeps its place reads nothing more.
- **Removals still saving or animating out count,** since the server may have them. While one is
  out, the page before is read after the page lands, not beside it, or a save between the 2 reads
  could lose a row.
- **The re-read reports `invalidated`,** since a cache would answer `nextPage` with its old copy.
- **Always on, cursors included,** since list_smith can't tell a cursor naming a row from an offset.
  Each page read again gets the signal it first went out with. A list whose pages don't shift pays
  a wasted read per page after a removal.
- **Another writer's deletes still shift an offset,** since list_smith never hears of them. The
  README points at paging by the last row.

---

<a id="depth-reload-whole"></a>
## A depth reload commits a whole list, lined up

- **Why whole:** an old page kept beside fresh ones was read at another time, so rows repeat or go
  missing where they meet. `onError` and `ReloadOnError` do nothing now, and go at the next major.
- **Lined up before it commits.** A removal booked any time after page `k - 1` went out could pull
  rows up past page `k`'s start. So once every page landed, page `k - 1` is read again, and each row
  the fresh pages lack goes in front of the page after the fresh row it follows.
- **Moves are judged against the fresh pages,** since the old list may lack a new item. A row read
  either side of its move sits in 2 pages, and the 1st copy is where it was. A new item on no page
  counts above every boundary.
- **"Any time after" has no end:** a slow `remove()` reaches list_smith after the server had it, so
  stopping the count at page `k` lost rows.
- **Line-up reads report the run's trigger.**

---

<a id="edit-store-scans"></a>
## The edit store walks its edits by stamp, unsorted

- **Decision:** edits stay in one map by item id, and "which edits came after this read" walks them
  all, comparing stamps. The display pass needs the map, and a stamp-sorted copy would have to stay
  in step on every write.
- **Sorting buys little:** stamps come from a counter, and one walk serves until the next edit, well
  under a frame at thousands of live edits. Look again past about 1 ms.
- **The walk is a loop** ([#scan-loops](#scan-loops)).
- **`ItemEdit` is a class,** since a `T`-typed record costs several times as much to build, once per
  live edit.

---

<a id="sorted-placement"></a>
## An order places edits where the server sorts them

- **Decision:** `ListSmith.async(order: SortedBy(comparator))`, `UnknownOrder` by default, a seam
  like the others ([#opt-in-idioms](#opt-in-idioms)).
- **What moves:** a new item, and an edit the comparator doesn't rank equal to its loaded copy. Each
  goes into the 1st page that doesn't end before it, by binary search.
- **A row sorting after every loaded one waits for its page** while more may follow.
  `PaginationEndPolicy.stopsAtDataEnd` says whether a reported end is the data's, so a cap doesn't
  show rows past it.
- **The feed only.** Search results come by relevance.
- **Each page read is checked in debug** to be strictly in order, ties included, and reported rather
  than thrown. Not across pages, where another writer's edit between reads would trip it.
- **Groups gather after placement,** so the order needn't sort by group.
- **Moves jump.** Animating one would need 2 copies of one keyed row.

---

<a id="keep-position"></a>
## The row the user is reading holds still

- **Decision:** a proxy sliver around the rows answers a row's move with a `scrollOffsetCorrection`
  of the same size, so no frame shows the slide.
- **Why a sliver:** the scroll position counts from the start, so any change above moves the view.
  Layout sees every row's new offset before paint, so one anchor there covers every cause.
- **Not at offset 0,** so a new row at the start shows, like a chat's newest message.
- **The pull's room counts,** or a reload ending while scrolled away would move every row by it.
- **Known gaps:** a change during `animateTo` still slides, a frame late
  ([flutter#193339](https://github.com/flutter/flutter/issues/193339)). A `jumpTo(0)` after an
  unbuilt change above lands short, since unbuilt rows are placed by estimate, where `animateTo(0)`
  or a 2nd `jumpTo(0)` lands exactly. Undoing the list's own corrections at 0 loops past the
  viewport's 10-cycle limit.
- **On `.sync` it needs `itemIdGetter`** ([#item-id-required](#item-id-required)).
- **No cost measured:** every bench scenario stayed within the regression gate on Android, with iOS
  too noisy to decide.

---

<a id="search-starts-at-top"></a>
## A new search starts at the top

- **Decision:** the engine hands the list its committed search, a new one per commit, and a proxy
  sliver around the rows or surface corrects the offset to 0 at layout when it changes. So a repeat
  `search()` starts at the top too.
- **Why the top:** the results are a different list, so the old offset points at whatever sits there
  now, and the row being read is usually outside the built rows.
- **Clearing loses the place.** Returning to it is the build-upward path, which only `.sync` could
  land, since a replaced `.async` feed reloads from page 0.
- **A sliver, not `jumpTo(0)`:** no frame shows the old offset, and no scroll controller is needed.
- **It corrects once.** The short landing [keep-position](#keep-position) warns of never showed
  after a query change. If it does, stay armed while the list corrects itself at the start.

---

<a id="search-from-code"></a>
## Code starts the one search, as typing does

- **Decision:** `search()` and `endSearch()` reach the commit step typing does, so past it only a
  fetcher the call passed tells them apart. A barcode scan was the case: a lookup's hits replace the
  list, as typing the code would.
- **The route comes with the call,** null meaning the search's own, so any number of endpoints need
  nothing declared on the list. Declaring them on `AsyncSearch` is the build-upward path.
- **Typing's debounce and gate by default,** so a call behaves like typing unless it passes its own.
- **Each call is its own event,** so a repeat runs, and a failed lookup retries.
- **It reports as typing does.** `FetchTrigger` names what happened to the list, not who did it, as
  `refresh` does for the pull and `refresh()`. A new value would break every exhaustive switch.
- **`endSearch()` lands on what `query` holds,** like clearing, so a kept feed comes back without a
  fetch.
- **A passed fetcher's signal is asserted at the call,** since it never meets the constructor.

---

**Still to record:** the SDK-floor rationale, and what list_smith deliberately doesn't do.
