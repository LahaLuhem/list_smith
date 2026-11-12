// Test-local fixtures share the file with the scenarios that use them.
// ignore_for_file: prefer-match-file-name

import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith/list_smith.dart';
import 'package:list_smith/src/widgets/defaults/defaults.dart';

import '../../../support/support.dart';

void main() {
  feature('ListSmith.async search() from code', () {
    scenarioOutlineWidgets<({Duration? searchDebounce, Duration waits})>(
      "a call waits its own searchDebounce, or the list's without one",
      examples: const {
        'its own': (searchDebounce: Duration(milliseconds: 50), waits: Duration(milliseconds: 50)),
        "the list's": (searchDebounce: null, waits: _listDebounce),
      },
      outline: (tester, example) async {
        final routes = _Routes();
        final controller = ListSmithController<String>();
        await _pumpList(tester, routes, controller: controller);
        await drain(tester);

        unawaited(
          controller.search(
            '123',
            fetchPage: routes.lookupFetcher,
            searchDebounce: example.searchDebounce,
          ),
        );
        await tester.pump(example.waits - const Duration(milliseconds: 1));
        check(routes.lookupRequests).isEmpty();

        await tester.pump(const Duration(milliseconds: 1));
        await drain(tester);
        check(find.text('lookup 123 #1').evaluate()).length.equals(1);
      },
    );

    scenarioOutlineWidgets<({int? minSearchLength, String shownText})>(
      "a call gates by its own minSearchLength, or the list's without one",
      examples: const {
        'its own': (minSearchLength: 0, shownText: 'lookup 12 #1'),
        // Under the list's 3, so no search, as typed.
        "the list's": (minSearchLength: null, shownText: 'feed'),
      },
      outline: (tester, example) async {
        final routes = _Routes();
        final controller = ListSmithController<String>();
        await _pumpList(tester, routes, controller: controller, minSearchLength: 3);
        await drain(tester);

        await _searchNow(
          tester,
          controller,
          '12',
          fetchPage: routes.lookupFetcher,
          minSearchLength: example.minSearchLength,
        );

        check(find.text(example.shownText).evaluate()).length.equals(1);
      },
    );

    scenarioWidgets(
      'calling again with the query showing runs it again, so a failed lookup retries',
      (tester) async {
        final routes = _Routes()..doesLookupFail = true;
        final controller = ListSmithController<String>();
        await _pumpList(tester, routes, controller: controller);
        await drain(tester);
        await _searchNow(tester, controller, '123', fetchPage: routes.lookupFetcher);
        // Premise: the lookup failed.
        check(find.byType(NeutralErrorIndicator).evaluate()).length.equals(1);

        routes.doesLookupFail = false;
        await _searchNow(tester, controller, '123', fetchPage: routes.lookupFetcher);

        check(find.text('lookup 123 #2').evaluate()).length.equals(1);
      },
    );

    scenarioOutlineWidgets<({bool passesLookup, String shownText})>(
      "a call fetches through the fetcher it passes, or the search's own without one",
      examples: const {
        'a fetcher': (passesLookup: true, shownText: 'lookup 123 #1'),
        'none': (passesLookup: false, shownText: 'search 123'),
      },
      outline: (tester, example) async {
        final routes = _Routes();
        final controller = ListSmithController<String>();
        await _pumpList(tester, routes, controller: controller);
        await drain(tester);

        await _searchNow(
          tester,
          controller,
          '123',
          fetchPage: !example.passesLookup ? null : routes.lookupFetcher,
        );

        check(find.text(example.shownText).evaluate()).length.equals(1);
      },
    );

    scenarioWidgets('a call reports as typing the same query does', (tester) async {
      final typedRoutes = _Routes()..doesSearchFindNothing = true;
      final typedObserver = RecordingListSmithObserver();
      final queryNotifier = ValueNotifier('');
      await _pumpList(tester, typedRoutes, queryNotifier: queryNotifier, observer: typedObserver);
      await drain(tester);
      await commitQuery(tester, queryNotifier, '123');
      await pumpListSmith(tester, const SizedBox.shrink());

      final calledRoutes = _Routes()..doesSearchFindNothing = true;
      final calledObserver = RecordingListSmithObserver();
      final controller = ListSmithController<String>();
      await _pumpList(tester, calledRoutes, controller: controller, observer: calledObserver);
      await drain(tester);
      await _searchNow(tester, controller, '123');

      check(calledObserver.events).deepEquals(typedObserver.events);
      check(calledRoutes.searchRequests.map((request) => request.trigger))
          .deepEquals(typedRoutes.searchRequests.map((request) => request.trigger));
      check(find.text('no results for 123').evaluate()).length.equals(1);
    });

    scenarioWidgets("an edit after a call goes through the search's own fetcher", (tester) async {
      final routes = _Routes();
      final controller = ListSmithController<String>();
      final queryNotifier = ValueNotifier('');
      await _pumpList(tester, routes, controller: controller, queryNotifier: queryNotifier);
      await drain(tester);
      await _searchNow(tester, controller, '123', fetchPage: routes.lookupFetcher);

      await commitQuery(tester, queryNotifier, '1234');

      check(find.text('search 1234').evaluate()).length.equals(1);
    });

    scenarioOutlineWidgets<Future<void> Function(ListSmithController<String> controller)>(
      "refresh() and reset() run a call's search again through its fetcher",
      examples: {
        'refresh()': (controller) => controller.refresh(),
        'reset()': (controller) => controller.reset(),
      },
      outline: (tester, reload) async {
        final routes = _Routes();
        final controller = ListSmithController<String>();
        await _pumpList(tester, routes, controller: controller);
        await drain(tester);
        await _searchNow(tester, controller, '123', fetchPage: routes.lookupFetcher);

        await reload(controller);
        await drain(tester);

        check(find.text('lookup 123 #2').evaluate()).length.equals(1);
        check(routes.searchRequests).isEmpty();
      },
    );

    scenarioOutlineWidgets<bool>(
      'a call completes once its page 0 is over, failed or not',
      examples: const {'it loads': false, 'it fails': true},
      outline: (tester, doesLookupFail) async {
        final lookupHoldCompleter = Completer<void>();
        final routes = _Routes()
          ..lookupHoldCompleter = lookupHoldCompleter
          ..doesLookupFail = doesLookupFail;
        final controller = ListSmithController<String>();
        await _pumpList(tester, routes, controller: controller);
        await drain(tester);

        var isSearchDone = false;
        unawaited(
          controller
              .search('123', fetchPage: routes.lookupFetcher, searchDebounce: Duration.zero)
              .then((_) => isSearchDone = true),
        );
        await tester.pump(Duration.zero);
        await drain(tester);
        // Premise: its page 0 was asked for, and waits.
        check(routes.lookupRequests).length.equals(1);
        check(isSearchDone).isFalse();

        await release(tester, [lookupHoldCompleter]);

        check(isSearchDone).isTrue();
      },
    );

    scenarioWidgets("a list going away lets a waiting call's caller go", (tester) async {
      final routes = _Routes();
      final controller = ListSmithController<String>();
      await _pumpList(tester, routes, controller: controller);
      await drain(tester);

      var isSearchDone = false;
      unawaited(
        controller.search('123', fetchPage: routes.lookupFetcher).then((_) => isSearchDone = true),
      );
      await pumpListSmith(tester, const SizedBox.shrink());

      check(isSearchDone).isTrue();
    });

    scenarioWidgets('a call on a list without search asserts', (tester) async {
      final controller = ListSmithController<String>();
      await _pumpList(tester, _Routes(), controller: controller, search: const NoSearch());
      await drain(tester);

      check(() => controller.search('123')).throws<AssertionError>();
    });

    scenarioWidgets("a call's fetcher without the signal the end policy reads asserts", (
      tester,
    ) async {
      final controller = ListSmithController<String>();
      await pumpListSmith(
        tester,
        ListSmith<String>.async(
          fetchPage: PageFetcher.withSignal((_) async => (const ['feed'], null)),
          itemIdGetter: (item) => item,
          endPolicy: const StopOnNullSignalPolicy(),
          search: AsyncSearch(
            fetchPage: SearchPageFetcher.withSignal((_) async => (const <String>[], null)),
          ),
          controller: controller,
          itemBuilder: (_, item, _) => Text(item),
        ),
      );
      await drain(tester);

      check(
        () => controller.search('123', fetchPage: SearchPageFetcher((_) async => const <String>[])),
      ).throws<AssertionError>();
    });

    scenarioWidgets('taking search away while a call shows lands on the feed', (tester) async {
      final routes = _Routes();
      final controller = ListSmithController<String>();
      await _pumpList(tester, routes, controller: controller);
      await drain(tester);
      await _searchNow(tester, controller, '123', fetchPage: routes.lookupFetcher);
      // Premise: the call shows, and the list's query stayed empty.
      check(find.text('lookup 123 #1').evaluate()).length.equals(1);

      await _pumpList(tester, routes, controller: controller, search: const NoSearch());
      await tester.pump(Duration.zero);
      await drain(tester);

      check(find.text('feed').evaluate()).length.equals(1);
    });
  });

  feature('ListSmith.async endSearch()', () {
    scenarioOutlineWidgets<({String fieldText, String shownText})>(
      "it lands on what the field holds, through the search's own fetcher",
      examples: const {
        'another query': (fieldText: 'abc', shownText: 'search abc'),
        // The same text, so only the route changes.
        "the call's query": (fieldText: '123', shownText: 'search 123'),
      },
      outline: (tester, example) async {
        final routes = _Routes();
        final controller = ListSmithController<String>();
        final queryNotifier = ValueNotifier('');
        await _pumpList(tester, routes, controller: controller, queryNotifier: queryNotifier);
        await drain(tester);
        await commitQuery(tester, queryNotifier, example.fieldText);
        await _searchNow(tester, controller, '123', fetchPage: routes.lookupFetcher);

        await _land(tester, controller.endSearch());

        check(find.text(example.shownText).evaluate()).length.equals(1);
      },
    );

    scenarioWidgets('it brings a kept feed back without a fetch', (tester) async {
      final routes = _Routes();
      final controller = ListSmithController<String>();
      await _pumpList(
        tester,
        routes,
        controller: controller,
        search: AsyncSearch(fetchPage: routes.searchFetcher, cachePolicy: const KeepCachePolicy()),
      );
      await drain(tester);
      await _searchNow(tester, controller, '123', fetchPage: routes.lookupFetcher);

      await _land(tester, controller.endSearch());

      check(find.text('feed').evaluate()).length.equals(1);
      check(routes.feedRequests).length.equals(1);
    });

    scenarioWidgets('it drops a call still waiting', (tester) async {
      final routes = _Routes();
      final controller = ListSmithController<String>();
      await _pumpList(tester, routes, controller: controller);
      await drain(tester);

      unawaited(controller.search('123', fetchPage: routes.lookupFetcher));
      await _land(tester, controller.endSearch());

      await settle(tester); // past the call's debounce
      check(routes.lookupRequests).isEmpty();
    });

    scenarioWidgets('it does nothing when a typed search shows', (tester) async {
      final routes = _Routes();
      final controller = ListSmithController<String>();
      final queryNotifier = ValueNotifier('');
      await _pumpList(tester, routes, controller: controller, queryNotifier: queryNotifier);
      await drain(tester);
      await commitQuery(tester, queryNotifier, 'abc');
      final requestCount = routes.requestCount;

      await _land(tester, controller.endSearch());

      check(routes.requestCount).equals(requestCount);
    });

    scenarioWidgets('it completes once its page 0 is over', (tester) async {
      final searchHoldCompleter = Completer<void>();
      final routes = _Routes();
      final controller = ListSmithController<String>();
      final queryNotifier = ValueNotifier('');
      await _pumpList(tester, routes, controller: controller, queryNotifier: queryNotifier);
      await drain(tester);
      await commitQuery(tester, queryNotifier, 'abc');
      await _searchNow(tester, controller, '123', fetchPage: routes.lookupFetcher);
      routes.searchHoldCompleter = searchHoldCompleter;

      var isEndDone = false;
      unawaited(controller.endSearch().then((_) => isEndDone = true));
      await tester.pump(Duration.zero);
      await drain(tester);
      // Premise: it went back to abc, whose answer waits.
      check(routes.searchRequests).length.equals(2);
      check(isEndDone).isFalse();

      await release(tester, [searchHoldCompleter]);

      check(isEndDone).isTrue();
    });
  });
}

/// The list's own debounce, the one [settle] waits out.
const _listDebounce = Duration(milliseconds: 20);

/// The routes a list fetches through. Each row names its route: `feed`, `search <query>` for the
/// search's own fetcher, and `lookup <query> #<attempt>` for one a call passes.
final class _Routes() {
  final feedRequests = <PageRequest>[];
  final searchRequests = <SearchPageRequest>[];
  final lookupRequests = <SearchPageRequest>[];

  /// Holds the search's own answers until completed.
  Completer<void>? searchHoldCompleter;

  /// Holds the lookup's answers until completed.
  Completer<void>? lookupHoldCompleter;

  var doesSearchFindNothing = false;
  var doesLookupFail = false;

  int get requestCount => feedRequests.length + searchRequests.length + lookupRequests.length;

  late final feedFetcher = PageFetcher<String>((request) async {
    feedRequests.add(request);

    return const ['feed'];
  });

  late final searchFetcher = SearchPageFetcher<String>((request) async {
    searchRequests.add(request);
    await searchHoldCompleter?.future;

    return doesSearchFindNothing ? const <String>[] : ['search ${request.query}'];
  });

  late final lookupFetcher = SearchPageFetcher<String>((request) async {
    lookupRequests.add(request);
    final attempt = lookupRequests.length;
    await lookupHoldCompleter?.future;
    if (doesLookupFail) throw Exception('lookup failed');

    return ['lookup ${request.query} #$attempt'];
  });
}

/// A `.async` list over [routes], one page per stream, typed into through [queryNotifier].
Future<void> _pumpList(
  WidgetTester tester,
  _Routes routes, {
  ListSmithController<String>? controller,
  ValueNotifier<String>? queryNotifier,
  Search<String>? search,
  int minSearchLength = 0,
  ListSmithObserver? observer,
}) {
  Widget build(String query) => ListSmith<String>.async(
    fetchPage: routes.feedFetcher,
    itemIdGetter: (item) => item,
    endPolicy: const FixedPageCountPolicy(pageCount: 1),
    search: search ?? AsyncSearch(fetchPage: routes.searchFetcher),
    query: query,
    minSearchLength: minSearchLength,
    searchDebounce: _listDebounce,
    controller: controller,
    observer: observer,
    noResultsBuilder: (_, query) => Text('no results for $query'),
    itemBuilder: (_, item, _) => Text(item),
  );

  return pumpListSmith(
    tester,
    queryNotifier == null
        ? build('')
        : ValueListenableBuilder(
            valueListenable: queryNotifier,
            builder: (_, query, _) => build(query),
          ),
  );
}

/// Calls `search()` with no debounce, and checks it landed.
Future<void> _searchNow(
  WidgetTester tester,
  ListSmithController<String> controller,
  String query, {
  SearchPageFetcher<String>? fetchPage,
  int? minSearchLength,
}) => _land(
  tester,
  controller.search(
    query,
    fetchPage: fetchPage,
    searchDebounce: Duration.zero,
    minSearchLength: minSearchLength,
  ),
);

/// Lets the call behind [callFuture] land on the next tick, and checks it did.
Future<void> _land(WidgetTester tester, Future<void> callFuture) async {
  var isDone = false;
  unawaited(callFuture.then((_) => isDone = true));
  await tester.pump(Duration.zero); // its timer, there even at zero
  await drain(tester);
  // Checked, not awaited: a call still waiting fails here instead of hanging the test.
  check(isDone).isTrue();
}
