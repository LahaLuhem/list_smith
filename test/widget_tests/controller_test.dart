import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith/list_smith.dart';

import '../support/support.dart';

void main() {
  feature('ListSmith.async ListSmithController', () {
    // Each page yields one item stamped `page * 1000 + attempt`, so a test can tell a refetched
    // page from its first load; `attempts` records how many times each index was fetched.
    ({PageFetcher<int> fetchPage, Map<int, int> attempts}) valuedFetcher() {
      final attempts = <int, int>{};
      final fetchPage = PageFetcher<int>((pageIndex, _) async {
        final attempt = attempts[pageIndex] = (attempts[pageIndex] ?? 0) + 1;

        return [pageIndex * 1000 + attempt];
      });

      return (fetchPage: fetchPage, attempts: attempts);
    }

    Future<void> pumpList(
      WidgetTester tester, {
      required PageFetcher<int> fetchPage,
      required ListSmithController? controller,
      int pageCount = 1,
      Refresh refresh = const PullToRefresh(),
      Search<int> search = const NoSearch(),
      String query = '',
      ListSmithObserver? observer,
    }) => pumpListSmith(
      tester,
      ListSmith.async(
        fetchPage: fetchPage,
        endPolicy: FixedPageCountPolicy(pageCount: pageCount),
        refresh: refresh,
        search: search,
        query: query,
        searchDebounce: const Duration(milliseconds: 20),
        controller: controller,
        observer: observer,
        itemBuilder: (_, item, _) => Text('item $item'),
      ),
    );

    scenarioWidgets('refresh() reloads the list without a pull', (tester) async {
      final fetcher = valuedFetcher();
      final controller = ListSmithController();

      await pumpList(tester, fetchPage: fetcher.fetchPage, controller: controller);
      await drain(tester);
      check(fetcher.attempts).deepEquals({0: 1});

      await controller.refresh();
      await drain(tester);

      // Page 0 was fetched again, and the list now shows its fresh stamp.
      check(fetcher.attempts).deepEquals({0: 2});
      check(find.text('item 2').evaluate()).length.equals(1);
      check(find.text('item 1').evaluate()).length.equals(0);
    });

    scenarioWidgets('refresh() runs the configured reload, so it keeps depth', (tester) async {
      final fetcher = valuedFetcher();
      final controller = ListSmithController();

      await pumpList(
        tester,
        fetchPage: fetcher.fetchPage,
        controller: controller,
        pageCount: 3,
        refresh: const PullToRefresh(reload: ReloadToCurrentDepth(concurrency: null)),
      );
      await drain(tester, frames: 12);
      check(fetcher.attempts).deepEquals({0: 1, 1: 1, 2: 1});

      await controller.refresh();
      await drain(tester);

      // Every loaded page was refetched, not just the first: this is the pull's own path.
      check(fetcher.attempts).deepEquals({0: 2, 1: 2, 2: 2});
    });

    scenarioWidgets('refresh() works on a list with no pull gesture', (tester) async {
      final fetcher = valuedFetcher();
      final controller = ListSmithController();

      await pumpList(
        tester,
        fetchPage: fetcher.fetchPage,
        controller: controller,
        refresh: const NoRefresh(),
      );
      await drain(tester);

      await controller.refresh();
      await drain(tester);

      check(fetcher.attempts).deepEquals({0: 2});
    });

    scenarioWidgets('a second refresh joins the one in flight instead of rivalling it', (
      tester,
    ) async {
      final fetcher = valuedFetcher();
      final controller = ListSmithController();
      final observer = RecordingListSmithObserver();

      await pumpList(
        tester,
        fetchPage: fetcher.fetchPage,
        controller: controller,
        pageCount: 3,
        refresh: const PullToRefresh(reload: ReloadToCurrentDepth()),
        observer: observer,
      );
      await drain(tester, frames: 12);

      await [controller.refresh(), controller.refresh()].wait;
      await drain(tester);

      // One reload ran and one event fired: the second call rode the first.
      check(observer.events.where((event) => event == 'refresh')).length.equals(1);
      check(fetcher.attempts).deepEquals({0: 2, 1: 2, 2: 2});
    });

    scenarioWidgets('refresh() while searching reloads the search, not the normal list', (
      tester,
    ) async {
      final normal = valuedFetcher();
      final searchAttempts = <int, int>{};
      final controller = ListSmithController();
      final search = AsyncSearch<int>(
        fetchPage: SearchPageFetcher((_, pageIndex, _) async {
          searchAttempts[pageIndex] = (searchAttempts[pageIndex] ?? 0) + 1;

          return [pageIndex];
        }),
      );

      await pumpList(tester, fetchPage: normal.fetchPage, controller: controller, search: search);
      await drain(tester);
      check(normal.attempts).deepEquals({0: 1});

      await pumpList(
        tester,
        fetchPage: normal.fetchPage,
        controller: controller,
        search: search,
        query: 'ab',
      );
      await settle(tester);
      check(searchAttempts).deepEquals({0: 1});

      await controller.refresh();
      await drain(tester);

      // The search stream reloaded; the normal fetcher was left alone.
      check(searchAttempts).deepEquals({0: 2});
      check(normal.attempts).deepEquals({0: 1});
    });

    scenarioWidgets('refresh() before any list attaches the controller asserts', (tester) async {
      final controller = ListSmithController();

      check(controller.refresh).throws<AssertionError>();
    });

    scenarioWidgets('refresh() after the list is gone is inert', (tester) async {
      final fetcher = valuedFetcher();
      final controller = ListSmithController();

      await pumpList(tester, fetchPage: fetcher.fetchPage, controller: controller);
      await drain(tester);
      await pumpListSmith(tester, const SizedBox.shrink());

      await controller.refresh();
      await drain(tester);

      check(fetcher.attempts).deepEquals({0: 1});
    });

    scenarioWidgets('swapping the controller moves the handle to the new one', (tester) async {
      final fetcher = valuedFetcher();
      final first = ListSmithController();
      final second = ListSmithController();

      await pumpList(tester, fetchPage: fetcher.fetchPage, controller: first);
      await drain(tester);
      await pumpList(tester, fetchPage: fetcher.fetchPage, controller: second);
      await drain(tester);

      await first.refresh();
      await drain(tester);
      check(fetcher.attempts).deepEquals({0: 1});

      await second.refresh();
      await drain(tester);
      check(fetcher.attempts).deepEquals({0: 2});
    });
  });
}
