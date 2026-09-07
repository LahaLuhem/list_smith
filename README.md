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
    * [Where the data ends](#where-the-data-ends)
- [Pull to refresh](#pull-to-refresh)
    * [Refreshing from code](#refreshing-from-code)
- [Search](#search)
    * [In memory, with `ListSmith.sync`](#in-memory-with-listsmithsync)
    * [Paged, with `ListSmith.async`](#paged-with-listsmithasync)
    * [You keep the search field](#you-keep-the-search-field)
- [Grouping](#grouping)
- [Make it look like your app](#make-it-look-like-your-app)
- [Watching what it does](#watching-what-it-does)
- [Scroll and layout](#scroll-and-layout)
- [Races and late answers](#races-and-late-answers)
- [Performance](#performance)
- [The example app](#the-example-app)
- [Contributing](#contributing)

<!-- TOC end -->

**list_smith** wraps `ListView.builder` for the lists you actually ship: async pagination,
pull-to-refresh, and search, sync or async. Hand it a data source, an item builder, and a bit of
config. It owns the scrollable, the controller, and every fiddly loading, error and empty state in
between.

Two things set it apart. It stays **out of your way**: no `ScrollController`, no `PagingController`,
no sign of the [infinite_scroll_pagination](https://pub.dev/packages/infinite_scroll_pagination) it
hides. And it brings **no design system**, so every surface it draws is a plain `widgets`-layer
default that drops into Material, Cupertino, or your own bespoke thing unchanged.

<p align="center">
  <img src="https://raw.githubusercontent.com/LahaLuhem/list_smith/main/doc/screenshots/1-overview.webp" width="260" alt="list_smith in action: pagination, pull-to-refresh, search, and grouping">
</p>

<table>
  <tr>
    <td align="center"><img src="https://raw.githubusercontent.com/LahaLuhem/list_smith/main/doc/screenshots/2-android-material.png" width="240" alt="Grouping demo on Android"><br><sub><b>Android</b> · Material</sub></td>
    <td align="center"><img src="https://raw.githubusercontent.com/LahaLuhem/list_smith/main/doc/screenshots/3-ios-cupertino.png" width="240" alt="The same demo on iOS"><br><sub><b>iOS</b> · Cupertino</sub></td>
  </tr>
</table>

## Install

```sh
flutter pub add list_smith
```

## A quick taste

A function that fetches a page, a builder for each item. That's the whole setup:

```dart
ListSmith.async(
  fetchPage: PageFetcher((request) => api.fetchArticles(page: request.pageIndex, size: request.pageSize)),
  itemBuilder: (context, article, index) => ArticleTile(article),
)
```

That already paginates as you scroll, pulls to refresh, loads, errors with a retry button, and knows
when it has hit the end.

## Two kinds of list

Which constructor you reach for comes down to where your data lives.

| Constructor       | Best for                                | Handles                                                |
|-------------------|-----------------------------------------|--------------------------------------------------------|
| `ListSmith.async` | data fetched a page at a time (an API)  | pagination, pull-to-refresh, and optional async search |
| `ListSmith.sync`  | a list you already hold in memory       | client-side search, nothing to paginate                |

Each takes only the parameters that make sense for it, so nothing you pass is ever quietly ignored.

## Pagination

`ListSmith.async` calls `fetchPage` with a `PageRequest` (0-based `pageIndex`, the `pageSize`, the
previous page's `previousSignal`), then asks for the next as the user nears the end. Return that
page's items, any `Iterable`, materialised once for you. An empty page is the end of the road:

```dart
ListSmith.async(
  pageSize: 30,
  fetchPage: PageFetcher((request) => repo.load(request.pageIndex, request.pageSize)),
  itemBuilder: (context, item, index) => Text(item.title),
)
```

<details>
<summary><b>Knowing why a page was fetched</b></summary>

A caching repository usually wants to treat the reasons differently, since serving a pull-to-refresh
out of the cache rather defeats the pull. `request.trigger` says which it was.

| `FetchTrigger` | What happened                                                         |
|----------------|-----------------------------------------------------------------------|
| `initialLoad`  | the first page of a cold list                                         |
| `nextPage`     | the user neared the end, so the next page was asked for               |
| `refresh`      | a pull-to-refresh, or `ListSmithController.refresh()`                 |
| `retry`        | this page's last attempt threw, and Retry was tapped                  |
| `queryChanged` | a committed search query changed, entering or leaving search included |

```dart
fetchPage: PageFetcher((request) => repo.load(
  request.pageIndex,
  request.pageSize,
  forceRefresh: switch (request.trigger) {
    FetchTrigger.refresh || FetchTrigger.retry => true,
    FetchTrigger.initialLoad || FetchTrigger.nextPage || FetchTrigger.queryChanged => false,
  },
)),
```

It reports the fact and stops there. Bypass, revalidate, or serve stale: your call.

</details>

### Where the data ends

An empty page meaning "the end" is the sensible default. When your backend signals it another way,
swap the policy. Pick by how your source behaves, not by mechanism:

| Policy                               | Reach for it when                                                    |
|--------------------------------------|----------------------------------------------------------------------|
| `StopOnEmptyPagesPolicy` *(default)* | your source just runs dry (a short, then empty, page). Do nothing.   |
| `FixedPageCountPolicy`               | you want a hard cap: a "top 100", or a teaser of N pages.            |
| `ExplicitHasMorePolicy`              | your backend returns a `hasMore` / `isLast` flag per response.       |
| `StopOnNullSignalPolicy`             | your backend is cursor-based, returning `null` when there's no more. |

The two count-based tweaks are one line each:

```dart
endPolicy: const StopOnEmptyPagesPolicy(emptyRunBeforeEnd: 3),  // tolerate up to two empty pages
endPolicy: const FixedPageCountPolicy(pageCount: 5),            // stop after five pages
```

The two signal-based ones read a value off each fetch, so they need `PageFetcher.withSignal` (and
`SearchPageFetcher.withSignal` if the list searches). Stopping on the flag saves the trailing empty
page a count-based policy fetches to find the end:

```dart
ListSmith.async(
  fetchPage: PageFetcher.withSignal((request) async {
    final response = await api.load(request.pageIndex, request.pageSize);
    return (response.items, response.hasMore);
  }),
  endPolicy: const ExplicitHasMorePolicy(),
  itemBuilder: (context, item, index) => Text(item.title),
)
```

None of the four fit? `PaginationEndPolicy` is an open contract. Its context carries the per-page
counts, the page size, and the last fetch's signal:

```dart
class ShortLastPage extends PaginationEndPolicy {
  @override
  bool hasReachedEnd(EndContext c) => c.lastPageItemCount < c.pageSize;
}
```

<details>
<summary><b>Cursor pagination</b></summary>

Keyset/cursor APIs don't take a page number, you hand back the cursor the previous page returned.
Same `withSignal` channel: a page's signal arrives on the next request as `previousSignal` (null for
the first page), and `StopOnNullSignalPolicy` ends the list when the cursor runs out.

```dart
ListSmith.async(
  fetchPage: PageFetcher.withSignal((request) async {
    final page = await api.list(cursor: request.previousSignal as String?, limit: request.pageSize);
    return (page.items, page.nextCursor);   // null nextCursor ends it
  }),
  endPolicy: const StopOnNullSignalPolicy(),
  itemBuilder: (context, item, index) => Text(item.title),
)
```

The cursor is opaque to list_smith (an `Object?`), so cast it back in the closure. Search gets its
own cursor the same way, through `SearchPageFetcher.withSignal`.

</details>

<details>
<summary><b>When a page in the middle comes back empty</b></summary>

The policies above decide *whether* more pages exist. A page with nothing to show is a different
problem: nothing on screen means nothing to scroll, so the pager never asks for the pages that do
have data. A calendar paged by day hits this on a quiet today.

`onEmptyPage` closes the gap. `AdvanceToFirstNonEmpty` pages past empty pages itself, to the first
one with items or the true end, showing the loading surface while it goes:

```dart
ListSmith.async(
  fetchPage: PageFetcher((request) => calendar.dayPage(request.pageIndex, request.pageSize)),
  // An empty day isn't the end...
  endPolicy: const StopOnEmptyPagesPolicy(emptyRunBeforeEnd: 31),
  // ...so page straight past empty days to the first with entries.
  onEmptyPage: const AdvanceToFirstNonEmpty(),
  itemBuilder: (context, item, index) => Text(item.title),
)
```

The two pair up, since advancing only bites under a policy that continues past an empty page. Cap
the scan with `AdvanceToFirstNonEmpty(maxPages: 31)` and it gives up after that many empty pages. A
pull re-scans.

</details>

<details>
<summary><b>De-duplicating overlapping pages</b></summary>

Offset-based sources can hand you the same row twice when the data shifts between fetches: a row is
inserted, so page N's tail reappears as page N+1's head. list_smith renders what your source
returns, so those repeats show. Pass an `itemId` and it drops any item whose key already appeared:

```dart
ListSmith.async(
  fetchPage: PageFetcher(...),
  itemId: (item) => item.id,
  itemBuilder: ...,
)
```

Keys compare by value, so an `int` or `String` id works. Compose one like `'${item.a}:${item.b}'`
for multi-field identity. Keyset/cursor pagination rarely needs any of this.

De-dup runs over every loaded item when a page arrives, never per scroll frame, and only when you
pass `itemId`. Under a millisecond for the first few thousand items. Past tens of thousands in one
live list, de-duplicate at the source instead.

</details>

## Pull to refresh

On by default for `ListSmith.async`. Pull down, the list resets and reloads from the first page.
Switch it off with `refresh: NoRefresh()`.

Want your own indicator? Give `PullToRefresh` a builder: `refresh: PullToRefresh(refreshBuilder:
...)`. It gets a small, framework-free snapshot of the pull (a phase and a drag value), never the
controller underneath.

Retry stays in your fetcher, not here. Wrap `fetchPage` with something like
[retry](https://pub.dev/packages/retry) so a transient blip is handled before the reload sees it:

```dart
import 'package:retry/retry.dart';

fetchPage: PageFetcher((request) =>
  retry(() => api.load(request.pageIndex, request.pageSize), retryIf: (e) => e is SocketException)),
```

<details>
<summary><b>Keeping the user's scroll depth across a pull</b></summary>

The default `ResetToFirstPage` clears the list, snaps to the top, and reloads page one. If the user
had scrolled deep, they lose their place. `ReloadToCurrentDepth` re-fetches every page they had
loaded instead:

```dart
refresh: const PullToRefresh(
  reload: ReloadToCurrentDepth(
    concurrency: 4,             // fetches in flight: 1 (default) serial, null all at once, K bounded
    onError: .commitSucceeded,  // best-effort default, or .allOrNothing
  ),
)
```

`concurrency` trades speed against backend load. `onError` handles a page-fetch that fails after
your fetcher's own retries: `commitSucceeded` keeps whatever reloaded and leaves the failed page as
it was, `allOrNothing` commits only if every page succeeds.

Three caveats:

- **Best-effort can seam.** A kept-old page beside fresh neighbours can duplicate or gap if the data
  shifted meanwhile. An `itemId` handles the duplicates, and gaps heal on the next refresh.
- **`withSignal` sources reload sequentially and atomically.** Page `k` needs page `k-1`, so the
  reload walks in order and any failure keeps the old list whole. `concurrency` and `onError` are
  ignored there. Scroll depth is still kept.
- **A page still loading when the pull happens is dropped and asked again.** Its answer was aimed at
  pre-refresh data. Costs one extra request.

</details>

### Refreshing from code

A toolbar button, a re-tapped tab, a reload after the user posts something. Pass a
`ListSmithController` and call `refresh()`.

```dart
final controller = ListSmithController();

ListSmith.async(fetchPage: PageFetcher(...), itemBuilder: ..., controller: controller)

await controller.refresh();  // from a button, a tab listener, wherever
```

It runs exactly what a pull runs, so your `PullToRefresh` config still applies, and an active search
reloads the search rather than the feed. Under `NoRefresh` it still works: that switches off the
*gesture*, not refreshing, and falls back to `ResetToFirstPage`.

No indicator: that belongs to the pull, and your button owns its progress, hence the future.
Awaiting follows the reload, so `ResetToFirstPage` completes as the list clears, not when fresh data
lands, while `ReloadToCurrentDepth` waits for the refetch. A call made while a refresh runs joins it
rather than starting a second.

Nothing to dispose, and async-only. To *watch* the list rather than drive it, use an
[observer](#watching-what-it-does).

## Search

This is where the two constructors part ways the most.

### In memory, with `ListSmith.sync`

Give `.sync` the items and a predicate that decides whether an item matches the current query. It
filters client-side and shows a "no results" surface when nothing does.

Most lists want "keep the item when any text field contains the query", so there's a builder for it:

```dart
ListSmith<City>.sync(
  items: allCities,
  searchBy: SyncSearchPredicates.fields([(city) => city.name, (city) => city.country]),
  query: searchQuery, // you own the field, more on that below
  itemBuilder: (context, city, index) => Text(city.name),
)
```

Case-insensitive substring over every field you list, `null` fields skipped so nullable ones need no
`?? ''`. Type the list (`ListSmith<City>.sync`) once and every builder's item type resolves.

Same idea, different match: `prefix` (starts-with, for type-ahead), `exact`, and `allTerms` (every
whitespace term must hit a field, so `"john smith"` finds `"Smith, John"`). Combine them, or your
own predicate, with `SyncSearchPredicates.any` (OR) and `.every` (AND).

Need case-sensitive or diacritic-folded matching? The predicate is yours, just a
`bool Function(item, query)`:

```dart
searchBy: (city, query) => city.name.toLowerCase().contains(query.toLowerCase()),
```

Or swap in [fuzzywuzzy](https://pub.dev/packages/fuzzywuzzy) so near-misses still hit:

```dart
searchBy: (city, query) => weightedRatio(city.name, query) >= 70, // 0-100, tune the cutoff
```

No pagination or pull-to-refresh here, since there's nothing to page or refresh over a list already
in memory. And if you don't need search at all, a plain `ListView.builder` will do.

### Paged, with `ListSmith.async`

Pass `search: AsyncSearch(...)` and the list grows a second mode. An empty query shows the normal
feed, a non-empty one switches to paginated *search results*, and back again once it clears. One
list, two views, with pagination and pull-to-refresh working in both:

```dart
ListSmith.async(
  fetchPage: PageFetcher((request) => repo.feed(request.pageIndex, request.pageSize)),
  search: AsyncSearch(
    fetchPage: SearchPageFetcher((r) => repo.search(r.query, r.pageIndex, r.pageSize)),
  ),
  query: searchQuery,
  itemBuilder: (context, item, index) => Text(item.title),
)
```

<details>
<summary><b>What happens to the feed while you search?</b></summary>

| Policy                           | Reach for it when                                                                            |
|----------------------------------|----------------------------------------------------------------------------------------------|
| `ReplaceCachePolicy` *(default)* | a clean reload each way is fine, or the feed should reflect changes made while searching.    |
| `KeepCachePolicy`                | returning to the feed should be instant: its pages and scroll position are kept, no refetch. |

```dart
search: AsyncSearch(fetchPage: mySearchFetcher, cachePolicy: const KeepCachePolicy()),
```

One caveat on "no refetch": a page still loading when the search started is dropped and asked again,
since its answer was aimed at the older feed.

</details>

### You keep the search field

list_smith renders no text field. Keep your own, hold the query in state, pass it in as `query`:

```dart
// inside a StatefulWidget's State:
var _query = '';

@override
Widget build(BuildContext context) => Column(
  children: [
    // your field: a TextField, a CupertinoTextField, your design system's search bar, wherever
    TextField(onChanged: (value) => setState(() => _query = value)),
    Expanded(child: ListSmith.async(query: _query, /* fetchPage, search, itemBuilder as above */)),
  ],
);
```

A `ValueNotifier` and a `ValueListenableBuilder` work too, and the field can sit anywhere. Clearing
is just `_query = ''`, and list_smith flips back to the feed on its own.

Two knobs shape the query. **`searchDebounce`** waits for typing to settle, 300ms on async and zero
on sync where an in-memory filter is instant. **`minSearchLength`** ignores anything shorter than N
characters. The query is trimmed first, so a field full of spaces counts as empty.

## Grouping

Labelled sections instead of one flat run. Pass a `Grouping.by`: a `groupBy` returning each item's
section key, plus a `headerBuilder` for the header. Works on both constructors:

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

Grouping runs over whatever is *visible*, so it composes with search: sections re-form over the
matches as you type.

<details>
<summary><b>How each path orders its sections, and what to watch</b></summary>

The two paths order differently, and the difference matters:

- **`.sync` buckets for you.** It holds the whole list, so it gathers each group into one contiguous
  run: groups in the order they first appear, items kept in order within a group. Your input can
  arrive any way round.
- **`.async` groups in arrival order.** It can't reorder across pages, so your `fetchPage` (and the
  `AsyncSearch` fetcher) must return items *already grouped by key*, all of one group before the
  next. A group spanning a page boundary still gets a single header.

If a key does come back after its section ended, `orderPolicy` decides. The default
`RepairHeadersPolicy` draws each header once and asserts in debug. `FailOnUnorderedPolicy` throws a
`StateError` in release too, for when a wrong-looking list is worse than a crash:

```dart
grouping: Grouping.by(
  groupBy: (Contact contact) => contact.team,
  headerBuilder: (context, team) => SectionHeader(team),
  orderPolicy: const FailOnUnorderedPolicy(),
),
```

Two more things:

- **Type the `groupBy` parameter**, or pass a typed function reference, so the key type infers
  instead of widening to `Object`.
- **Hold the `Grouping` stable** on a large `.sync` list. One rebuilt every frame re-buckets every
  frame, so keep it in a field and the result stays cached. What that costs is in
  [Performance](#performance).

</details>

## Make it look like your app

Every surface list_smith draws (loaders, errors, the empty state, the "that's everything" footer,
the pull indicator) is a neutral `widgets`-layer default. No `CircularProgressIndicator`, nothing
from Material or Cupertino, so nothing fights the app you've built. Override the slot for your own.

Two sit on the constructor, because every list has them: **`emptyBuilder`** for a source with no
items, **`noResultsBuilder`** for a search that matched nothing (it gets the query). The rest are
async-only, gathered into an `AsyncListSurfaces` you define once and reuse for a house style:

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

The pull indicator is set separately, on `PullToRefresh`. The error builders get
`(context, error, onRetry)`, so a custom error view can offer retry without you reaching for a
controller. Leave any slot out and its neutral default fills in.

</details>

## Watching what it does

Log a load, report an error to your crash tool, count how often people search. Pass an `observer`
and every callback hands you plain values (a page index, a count, the query, the error), never a
controller or a paging type:

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

Override only what you care about, the rest cost nothing: `onPageLoaded`, `onError`, `onReload`,
`onQueryCommitted`, `onSearchModeChanged`. `onReload` carries the trigger its pages will report and
fires before the first of them is asked for, so anything you start there is under way by the time
your fetcher runs. In a hurry? `LoggingListSmithObserver()` pushes every event through
`dart:developer`, so it lands in DevTools and stays `avoid_print`-clean. Overrides run synchronously
while a page loads, so keep them light (see [Performance](#performance)).

> Observers are async-only. A `.sync` list has no fetch, refresh, or controller to observe, and you
> already hold the query it filters on.

## Scroll and layout

Padding, physics, a scroll controller, reverse, direction, cache extent: the usual knobs live
together in a `ListScrollConfig`, clear of the behavioural parameters so neither crowds the other.

```dart
scroll: const ListScrollConfig(
  padding: EdgeInsets.all(16),
  physics: BouncingScrollPhysics(),
),
```

## Races and late answers

Lists race. The user types while an old query's page is still loading, or pulls to refresh while a
page is in the air. list_smith settles those, and each guarantee below has a test behind it.

<details>
<summary><b>The three guarantees</b></summary>

**A query change drops the pages still in flight.** They're discarded, not appended. Cursors too, so
the next page starts from the new query's cursor and not one an abandoned request returned.
Otherwise hits for a query you deleted turn up under the ones you asked for.

**Group headers come from the whole loaded list, not per page.** A group spanning a page boundary
gets one header, and isn't split. For out-of-order pages see [Grouping](#grouping).

**A refresh drops the pages still in flight**, on both reload strategies, so a page requested before
the pull can't land after it and duplicate rows or leave a hole. It's asked again, so you keep what
the refresh committed. Same when the feed returns after a search.

</details>

## Performance

list_smith is a thin wrapper over `infinite_scroll_pagination` and `custom_refresh_indicator`, and
the wrapping is close to free. Measured on one machine (yours will differ), from the committed
[benchmark report](benchmark/reports/SUMMARY.md):

| What                                                 | Cost                                                                          |
|------------------------------------------------------|-------------------------------------------------------------------------------|
| Scrolling                                            | within ~0.03 ms/frame of a plain `ListView.builder`, neither dropping a frame |
| Per-page bookkeeping (end policy, observer dispatch) | sub-microsecond to a few microseconds                                         |
| A full pull-to-refresh cycle                         | ~0.4 ms/frame, 0 frames over the 16.67 ms budget                              |
| Sync search, per committed query                     | ~0.4 ms at 1k items, ~4 ms at 10k, ~42 ms at 100k                             |
| Sync grouping, per committed query                   | ~0.2 ms at 1k, ~2.4 ms at 10k, ~27 ms at 100k                                 |
| `itemId` de-dup, per page arriving                   | ~0.3 ms at 1k loaded, ~3.4 ms at 10k, ~39 ms at 100k                          |
| A 50 ms observer callback                            | pushes render latency to ~68 ms                                               |

Sync search and grouping are O(n) per query and cross the frame budget around 100k items, so lean
on the debounce or go async. De-dup is opt-in and off the scroll path, but past tens of thousands in
one live list, de-duplicate at the source. Observers are called synchronously while a page loads:
log, count, report, and do heavy work elsewhere.

Numbers are per-machine, so capture your own baseline before trusting a delta. The suite lives in
[`benchmark/`](benchmark/), and `run.py compare` diffs two runs with a Mann-Whitney test.

![Render latency vs observer delay](benchmark/reports/observer_latency.png)

![Per-frame build cost vs the 60 Hz budget](benchmark/reports/frame_costs.png)

![Sync-search cost vs list size](benchmark/reports/sync_search_scaling.png)

![Sync grouping cost vs list size](benchmark/reports/bucket_by_group_scaling.png)

![itemId de-dup cost vs loaded list size](benchmark/reports/dedup_scaling.png)

## The example app

The [`example/`](example/) app is the best place to watch it all work: a basic feed, a cursor feed,
fully custom surfaces, a playground with live knobs, both flavours of search, and an observer demo
that streams every lifecycle event into a panel as you scroll, refresh, and type.

## Contributing

Issues and pull requests are welcome. Have a look at [`AGENTS.md`](.ai/AGENTS.md) for the
conventions and [`CODESTYLE.md`](CODESTYLE.md) for the code style before you start. The reasoning
behind the bigger design decisions lives in [`APPENDIX.md`](APPENDIX.md).
