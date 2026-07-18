[![Package checks](https://github.com/LahaLuhem/list_smith/actions/workflows/package.yml/badge.svg?branch=main)](https://github.com/LahaLuhem/list_smith/actions/workflows/package.yml)
[![Coverage Status](https://coveralls.io/repos/github/LahaLuhem/list_smith/badge.svg?branch=main)](https://coveralls.io/github/LahaLuhem/list_smith?branch=main)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/LahaLuhem/list_smith/pulls)
[![Pub Version](https://img.shields.io/pub/v/list_smith.svg)](https://pub.dev/packages/list_smith)
[![Pub Points](https://img.shields.io/pub/points/list_smith?logo=dart)](https://pub.dev/packages/list_smith/score)
[![License: BSD-3-Clause](https://img.shields.io/badge/License-BSD--3--Clause-blue.svg)](./LICENSE)
[![GitHub issues](https://img.shields.io/github/issues/LahaLuhem/list_smith.svg)](https://github.com/LahaLuhem/list_smith/issues)
[![GitHub closed issues](https://img.shields.io/github/issues-closed/LahaLuhem/list_smith.svg)](https://github.com/LahaLuhem/list_smith/issues?q=is%3Aissue+is%3Aclosed)
[![GitHub pull requests](https://img.shields.io/github/issues-pr/LahaLuhem/list_smith.svg)](https://github.com/LahaLuhem/list_smith/pulls)
[![GitHub closed pull requests](https://img.shields.io/github/issues-pr-closed/LahaLuhem/list_smith.svg)](https://github.com/LahaLuhem/list_smith/pulls?q=is%3Apr+is%3Aclosed)

<!-- TOC start (generated with https://github.com/derlin/bitdowntoc) -->

- [Install](#install)
- [A quick taste](#a-quick-taste)
- [Two kinds of list](#two-kinds-of-list)
- [Pagination](#pagination)
    * [Deciding where the data ends](#deciding-where-the-data-ends)
    * [De-duplicating overlapping pages](#de-duplicating-overlapping-pages)
- [Pull to refresh](#pull-to-refresh)
- [Search](#search)
    * [In memory, with `ListSmith.sync`](#in-memory-with-listsmithsync)
    * [Paged, with `ListSmith.async` and a search](#paged-with-listsmithasync-and-a-search)
        + [What happens to the feed while you search?](#what-happens-to-the-feed-while-you-search)
    * [You keep the search field](#you-keep-the-search-field)
- [Grouping](#grouping)
- [Make it look like your app](#make-it-look-like-your-app)
- [Watching what it does](#watching-what-it-does)
- [Scroll and layout](#scroll-and-layout)
- [Performance](#performance)
- [Roadmap](#roadmap)
- [The example app](#the-example-app)
- [Contributing](#contributing)

<!-- TOC end -->

**list_smith** wraps `ListView.builder` for the lists you actually ship: async pagination,
pull-to-refresh, and search (sync or async). You hand it a data source, an item builder, and a bit of
config. It takes care of the scrollable, the controller, and every fiddly loading, error, and empty
state in between, and never asks you to touch any of them.

Two things set it apart. It stays **fully out of your way**: you never see a `ScrollController`, a
`PagingController`, or the [`infinite_scroll_pagination`](https://pub.dev/packages/infinite_scroll_pagination)
it wraps and hides. And it brings **no design system**. Every surface it draws is a plain
`widgets`-layer default, so the list drops into a Material app, a Cupertino app, or your own bespoke
thing without dragging in a look you didn't choose.

## Install

```sh
flutter pub add list_smith
```

## A quick taste

Give it a function that fetches a page and a builder for each item. That really is the whole setup:

```dart
ListSmith.async(
  fetchPage: PageFetcher((pageIndex, pageSize) => api.fetchArticles(page: pageIndex, size: pageSize)),
  itemBuilder: (context, article, index) => ArticleTile(article),
)
```

That list already paginates as you scroll, pulls to refresh, shows a loader on the first page and a
smaller one while the next page comes in, surfaces errors with a retry button, and knows when it has
hit the end. No controller to wire up, no scroll listener, no `ListView` in sight.

## Two kinds of list

There are two constructors, and which one you reach for comes down to where your data lives.

| Constructor       | Best for                                | Handles                                                |
|-------------------|-----------------------------------------|--------------------------------------------------------|
| `ListSmith.async` | data fetched a page at a time (an API)  | pagination, pull-to-refresh, and optional async search |
| `ListSmith.sync`  | a list you already hold in memory       | client-side search, nothing to paginate                |

Each takes only the parameters that make sense for it, so nothing you pass is ever quietly ignored.

## Pagination

`ListSmith.async` calls your `fetchPage` with a 0-based page index and the page size, then asks for
the next page as the user nears the end. Return the items for that page (any `Iterable`; it gets
materialised once for you). When a page comes back empty, that is the end of the road:

```dart
ListSmith.async(
  pageSize: 30,
  fetchPage: PageFetcher((pageIndex, pageSize) => repo.load(pageIndex, pageSize)),
  itemBuilder: (context, item, index) => Text(item.title),
)
```

### Deciding where the data ends

An empty page meaning "the end" is the sensible default (a calendar feed can even have an empty day
mid-list, which `emptyRunBeforeEnd` allows for). When your backend signals the end another way, swap
the policy to match it. Pick by how your source behaves, not by mechanism:

| Policy                               | Reach for it when                                                    |
|--------------------------------------|----------------------------------------------------------------------|
| `StopOnEmptyPagesPolicy` *(default)* | your source just runs dry (a short, then empty, page). Do nothing.   |
| `FixedPageCountPolicy`               | you want a hard cap: a "top 100", or a teaser of N pages.            |
| `ExplicitHasMorePolicy`              | your backend returns a `hasMore` / `isLast` flag per response.       |
| `StopOnNullSignalPolicy`             | your backend is cursor-based, returning `null` when there's no more. |

The default needs no `endPolicy` at all. The two count-based tweaks are one line each:

```dart
endPolicy: const StopOnEmptyPagesPolicy(emptyRunBeforeEnd: 3),  // tolerate up to two empty pages
endPolicy: const FixedPageCountPolicy(pageCount: 5),            // stop after five pages
```

The two signal-based ones read a value off each fetch, so they need `PageFetcher.withSignal` (and
`SearchPageFetcher.withSignal` if the list searches). `ExplicitHasMorePolicy` stops the moment the
backend says it's the last page, instead of fetching one more empty page to find out:

```dart
ListSmith.async(
  fetchPage: PageFetcher.withSignal((pageIndex, pageSize, _) async {
    final response = await api.load(pageIndex, pageSize);
    return (response.items, response.hasMore);
  }),
  endPolicy: const ExplicitHasMorePolicy(),
  itemBuilder: (context, item, index) => Text(item.title),
)
```

`StopOnNullSignalPolicy` is the cursor case, shown just below. If none of the four fit,
`PaginationEndPolicy` is an open contract: implement `hasReachedEnd(EndContext)` and pass it as
`endPolicy`. The context carries the per-page counts, the page size, and the last fetch's signal, so
"stop when the last page came back short" is a few lines:

```dart
class ShortLastPage extends PaginationEndPolicy {
  @override
  bool hasReachedEnd(EndContext c) => c.lastPageItemCount < c.pageSize;
}
```

### Cursor pagination

Keyset/cursor APIs don't take a page number; you hand back the cursor the previous page returned.
That's the same `withSignal` channel: the signal a page returns is passed into the next fetch as
`previousSignal` (null for the first page), and `StopOnNullSignalPolicy` ends the list when the cursor
runs out.

```dart
ListSmith.async(
  fetchPage: PageFetcher.withSignal((_, pageSize, previousCursor) async {
    final page = await api.list(cursor: previousCursor as String?, limit: pageSize);
    return (page.items, page.nextCursor);   // null nextCursor ends it
  }),
  endPolicy: const StopOnNullSignalPolicy(),
  itemBuilder: (context, item, index) => Text(item.title),
)
```

The cursor is opaque to list_smith (an `Object?`), so cast it back to your type in the closure. It
works for search too: give `AsyncSearch` a `SearchPageFetcher.withSignal` and the search stream drives
its own cursor.

### De-duplicating overlapping pages

Offset-based sources can hand you the same row on two pages when the data shifts between fetches (a
new row is inserted, so page N's tail reappears as page N+1's head). By default list_smith renders
what your source returns, so those repeats show twice. Pass an `itemId` and it drops any item whose
key already appeared:

```dart
ListSmith.async(
  fetchPage: PageFetcher(...),
  itemId: (item) => item.id,
  itemBuilder: ...,
)
```

The key is compared by value (`==` / `hashCode`), so an `int` or `String` id works; compose one like
`'${item.a}:${item.b}'` for multi-field identity. Keyset/cursor pagination rarely needs it.

De-dup runs over every loaded item each time a page arrives (O(items loaded) per page, never per
scroll frame), and only when you pass `itemId`. That's well under a millisecond for the first few
thousand items and grows from there, so it's a non-issue for normal feeds. If a single list holds
tens of thousands of items, de-duplicate at the source (keyset/cursor pagination) instead of leaning
on `itemId`.

## Pull to refresh

On by default for `ListSmith.async`. Pull down, the list resets and reloads from the first page.
Nothing to set up.

Switch it off with `refresh: NoRefresh()`. Want your own indicator instead of the neutral one? Give
`PullToRefresh` a builder: `refresh: PullToRefresh(refreshBuilder: ...)`. It gets a small,
framework-free snapshot of the pull (a phase and a drag value), never the controller underneath.

## Search

This is where the two constructors part ways the most.

### In memory, with `ListSmith.sync`

Already holding the whole list? Give `.sync` the items and a predicate that decides whether an item
matches the current query. It filters client-side and shows a "no results" surface when nothing does:

```dart
ListSmith.sync(
  items: allCities,
  searchBy: (city, query) => city.name.toLowerCase().contains(query.toLowerCase()),
  query: searchQuery, // you own the field; more on that below
  itemBuilder: (context, city, index) => Text(city.name),
)
```

There's no pagination or pull-to-refresh here, because there's nothing to page or refresh over a list
that is already in memory. And if you don't need search at all, you don't need this: a plain
`ListView.builder` will do.

### Paged, with `ListSmith.async` and a search

Pass `search: AsyncSearch(...)` to an async list and it grows a second mode. An empty query shows the
normal paginated feed; a non-empty one switches to paginated *search results* fetched by your search
function, and back again once the query clears. One list, two views, with pagination and
pull-to-refresh still working in both:

```dart
ListSmith.async(
  fetchPage: PageFetcher((pageIndex, pageSize) => repo.feed(pageIndex, pageSize)),
  search: AsyncSearch(
    fetchPage: SearchPageFetcher((query, pageIndex, pageSize) => repo.search(query, pageIndex, pageSize)),
  ),
  query: searchQuery,
  itemBuilder: (context, item, index) => Text(item.title),
)
```

#### What happens to the feed while you search?

When the list flips between the feed and the search results, what should become of the feed you were
looking at? Another policy:

| Policy                           | Reach for it when                                                                            |
|----------------------------------|----------------------------------------------------------------------------------------------|
| `ReplaceCachePolicy` *(default)* | a clean reload each way is fine, or the feed should reflect changes made while searching.    |
| `KeepCachePolicy`                | returning to the feed should be instant: its pages and scroll position are kept, no refetch. |

```dart
search: AsyncSearch(fetchPage: mySearchFetcher, cachePolicy: const KeepCachePolicy()),
```

### You keep the search field

list_smith renders no text field. You keep your own (every app already has one), hold the query in
state, and pass it in as `query`. The whole loop is small:

```dart
// inside a StatefulWidget's State:
var _query = '';

@override
Widget build(BuildContext context) => Column(
  children: [
    // your field: a TextField, a CupertinoTextField, your design system's search bar, wherever
    TextField(onChanged: (value) => setState(() => _query = value)),
    Expanded(
      child: ListSmith.async(
        query: _query,
        fetchPage: PageFetcher((pageIndex, pageSize) => repo.feed(pageIndex, pageSize)),
        search: AsyncSearch(
          fetchPage: SearchPageFetcher((query, pageIndex, pageSize) => repo.search(query, pageIndex, pageSize)),
        ),
        itemBuilder: (context, item, index) => Text(item.title),
      ),
    ),
  ],
);
```

Prefer a `ValueNotifier` and a `ValueListenableBuilder` so you don't rebuild the whole widget? That
works too. The field can sit anywhere (an app bar, a sheet), as long as it feeds `query`. Clearing is
just `_query = ''`; list_smith flips back to the feed on its own.

Two knobs shape how the query is handled:

- **`searchDebounce`** waits for typing to settle before searching. Defaults to 300ms on async (go
  easy on your server) and to zero on sync, where an in-memory filter is instant anyway.
- **`minSearchLength`** ignores anything shorter than N characters.

The query is trimmed first, so a field full of spaces counts as empty.

## Grouping

Show the list in labelled sections instead of one flat run. Pass a `Grouping.by`: a `groupBy` that
returns each item's section key, plus a `headerBuilder` that draws the header. It works on both
constructors, and the header is stacked above the first item of each section:

```dart
ListSmith.sync(
  items: contacts,
  searchBy: (contact, query) => contact.name.toLowerCase().contains(query.toLowerCase()),
  query: searchQuery,
  grouping: Grouping.by(
    groupBy: (Contact contact) => contact.team,
    headerBuilder: (context, team) => SectionHeader(team),
  ),
  itemBuilder: (context, contact, index) => Text(contact.name),
)
```

Grouping runs over whatever is *visible*, so it composes with search: the sections re-form over the
matches as you type.

The two paths order their sections differently, and the difference matters:

- **`.sync` buckets for you.** It holds the whole list, so it gathers each group into one contiguous
  run (groups in the order they first appear, items kept in order within a group). Your input can
  arrive in any order.
- **`.async` groups in arrival order.** It can't reorder across pages, so your `fetchPage` (and the
  `AsyncSearch` fetcher) must return items *already grouped by key*, all of one group before the next.
  A key that comes back after its section ended repeats the header; a debug-mode assert flags it.

Two things worth knowing:

- **Type the `groupBy` parameter** or pass a typed function reference, so the key type is inferred
  instead of widening to `Object`.
- **Hold the `Grouping` stable** on a large `.sync` list. A `Grouping.by(...)` rebuilt every frame
  re-buckets every frame; keep it in a field (or `const NoGrouping()` when grouping is off) so the
  result stays cached.

What bucketing costs is in [Performance](#performance).

## Make it look like your app

Every surface list_smith draws (the loaders, the errors, the empty state, the "that's everything"
footer, the pull indicator) is a neutral `widgets`-layer default. Neutral on purpose: no
`CircularProgressIndicator`, nothing from Material or Cupertino, so nothing fights the app you've
built. When you want your own look, override the slot.

Two surfaces sit right on the constructor, because every list has them:

- **`emptyBuilder`**, when the source holds no items at all
- **`noResultsBuilder`**, when a search matched nothing (it is handed the query)

The rest are async-only, so they're gathered into an `AsyncListSurfaces` you can define once and reuse
across every list for one consistent house style:

```dart
ListSmith.async(
  fetchPage: PageFetcher(...),
  itemBuilder: ...,
  emptyBuilder: (context) => const Center(child: Text('Nothing here yet')),
  surfaces: AsyncListSurfaces(
    firstPageLoadingBuilder: (context) => const MySpinner(),
    firstPageErrorBuilder: (context, error, onRetry) => MyError(error, onRetry: onRetry),
    noMoreItemsBuilder: (context) => const Text("That's everything"),
  ),
)
```

<details>
<summary><b>The full set of surface slots</b></summary>

On the constructor (any list):

| Slot               | Shown when                                    |
|--------------------|-----------------------------------------------|
| `emptyBuilder`     | the source has no items                       |
| `noResultsBuilder` | a search matched nothing (receives the query) |

In `AsyncListSurfaces` (async lists only):

| Slot                      | Shown when                                                |
|---------------------------|-----------------------------------------------------------|
| `firstPageLoadingBuilder` | the first page is loading                                 |
| `newPageLoadingBuilder`   | a further page is loading                                 |
| `firstPageErrorBuilder`   | the first page failed (receives the error + a retry call) |
| `newPageErrorBuilder`     | a further page failed (receives the error + a retry call) |
| `noMoreItemsBuilder`      | every page has loaded                                     |

The pull-to-refresh indicator is set separately, on `PullToRefresh` (see the
[Pull to refresh](#pull-to-refresh) section above).

The error builders get `(context, error, onRetry)`, so a custom error view can offer a retry without
you reaching for a controller. Leave any slot out and its neutral default fills in.

</details>

## Watching what it does

Sometimes you want to know what the list is up to: log a load, report an error to your crash tool,
count how often people search. Pass an `observer` and those events come to you, with none of the
internals leaking out. Every callback hands you plain values (a page index, a count, the query, the
error), never a controller or a paging type:

```dart
final class MyObserver extends ListSmithObserver {
  const MyObserver();

  @override
  void onError(Object error, StackTrace stackTrace) => crashReporter.record(error, stackTrace);
}

ListSmith.async(
  fetchPage: PageFetcher(...),
  itemBuilder: ...,
  observer: const MyObserver(),
)
```

Override only the events you care about; the rest cost nothing. You get `onPageLoaded`, `onError`,
`onRefresh`, `onQueryCommitted`, and `onSearchModeChanged`. Just debugging, or in a hurry? Drop in the
ready-made `LoggingListSmithObserver()` and every event goes through `dart:developer`, so it shows up
in DevTools and stays `avoid_print`-clean. Whatever you override runs synchronously while a
page loads, so keep it light: a slow callback delays rendering (see [Performance](#performance)).

> Observers are async-only. A `.sync` list has no fetch, refresh, or controller to observe, and you
> already hold the query it filters on.

## Scroll and layout

Padding, physics, a scroll controller, reverse, direction, cache extent: the usual scrollable knobs
live together in a `ListScrollConfig`, kept clear of the behavioural parameters so neither crowds the
other.

```dart
scroll: const ListScrollConfig(
  padding: EdgeInsets.all(16),
  physics: BouncingScrollPhysics(),
),
```

## Performance

list_smith is a thin wrapper over `infinite_scroll_pagination` and `custom_refresh_indicator`, and
the wrapping is close to free. Measured on one machine (yours will differ), from the committed
[benchmark report](benchmark/reports/SUMMARY.md):

- **Scrolling costs what a bare list costs.** A `ListSmith.async` scroll runs within ~0.03 ms/frame
  of a plain `ListView.builder` over the same items, and neither drops a frame. The per-page
  bookkeeping (end-policy check, observer dispatch) is sub-microsecond to a few microseconds.
- **Pull-to-refresh is cheap.** A full custom_refresh_indicator cycle builds at ~0.4 ms/frame, with
  0 frames over the 16.67 ms budget.
- **Sync search is O(n) per committed query.** `ListSmith.sync` re-filters the whole list on each
  query. With a naive case-insensitive `contains` that's ~0.4 ms at 1k items, ~4 ms at 10k, and
  ~42 ms at 100k, where it crosses the frame budget. For big in-memory lists, lean on the built-in
  debounce or reach for the async path.
- **Grouping scales the same way, a bit cheaper.** A `Grouping` on `ListSmith.sync` buckets the
  filtered items into sections on each committed query: ~0.2 ms at 1k, ~2.4 ms at 10k, and ~27 ms at
  100k. Same "big list, lean on debounce or async" caveat as sync search.
- **`itemId` de-dup is O(loaded) per page.** Opt-in, and off the scroll path (it runs when a page
  arrives, not per frame). With no real overlap to collapse (the common case) it's ~0.3 ms at 1k
  loaded items, ~3.4 ms at 10k, ~39 ms at 100k. Past tens of thousands of items in one live list,
  de-duplicate at the source instead of leaning on `itemId`.
- **Observers are on the critical path.** list_smith calls your `observer` synchronously while
  a page loads, so a slow callback delays rendering roughly 1:1 (a 50 ms observer pushed render
  latency to ~68 ms). Keep them cheap: log, count, report; do heavy work elsewhere.

Numbers are per-machine and won't match yours; capture your own baseline before trusting a
delta. The suite (methodology, micro-benchmarks, profile-mode scenarios) lives in
[`benchmark/`](benchmark/), and `run.py compare` diffs two runs with a Mann-Whitney test to catch
regressions.

![Render latency vs observer delay](benchmark/reports/observer_latency.png)

![Per-frame build cost vs the 60 Hz budget](benchmark/reports/frame_costs.png)

![Sync-search cost vs list size](benchmark/reports/sync_search_scaling.png)

![Sync grouping cost vs list size](benchmark/reports/bucket_by_group_scaling.png)

![itemId de-dup cost vs loaded list size](benchmark/reports/dedup_scaling.png)

## Roadmap

- [x] Async pagination with swappable end-detection
- [x] Pull-to-refresh
- [x] Sync (in-memory) search
- [x] Async two-view search with a cache policy
- [x] Lifecycle observer
- [x] Explicit end signal from the fetcher: `ExplicitHasMorePolicy`, plus an open
  `PaginationEndPolicy` contract for custom end-detection (e.g. a null next-cursor)
- [x] Cursor-driven pagination: drive each fetch from the previous page's cursor, with
  `StopOnNullSignalPolicy` to end on a null cursor

## The example app

The [`example/`](example/) app is the best place to watch it all work: a basic feed, a cursor feed,
fully custom surfaces, a playground with live knobs, both flavours of search, and an observer demo
that streams every lifecycle event into a panel as you scroll, refresh, and type.

## Contributing

Issues and pull requests are welcome. Have a look at [`AGENTS.md`](.ai/AGENTS.md) for the conventions
and [`CODESTYLE.md`](CODESTYLE.md) for the code style before you start, and the reasoning behind the
bigger design decisions lives in [`APPENDIX.md`](APPENDIX.md).
