import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith/list_smith.dart';

import '../support/support.dart';

void main() {
  feature('ListSmith.async EmptyPageBehaviour', () {
    // Serves `pages` by 0-based index (empty beyond the end) and records every index requested, so a
    // test can assert exactly how far the list paged on its own.
    ({PageFetcher<int> fetchPage, List<int> requested}) recordingFetcher(List<List<int>> pages) {
      final requested = <int>[];
      final fetchPage = PageFetcher<int>((pageIndex, _) async {
        requested.add(pageIndex);

        return pageIndex < pages.length ? pages[pageIndex] : const <int>[];
      });

      return (fetchPage: fetchPage, requested: requested);
    }

    scenarioWidgets('AdvanceToFirstNonEmpty pages past empty pages to the first with items', (
      tester,
    ) async {
      final fetcher = recordingFetcher(const <List<int>>[
        [],
        [],
        [1, 2],
      ]);

      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: fetcher.fetchPage,
          endPolicy: const StopOnEmptyPagesPolicy(emptyRunBeforeEnd: 5),
          onEmptyPage: const AdvanceToFirstNonEmpty(),
          refresh: const NoRefresh(),
          itemBuilder: (_, item, _) => Text('item $item'),
        ),
      );
      await drain(tester, frames: 12);

      // Advanced through the two empty pages (0, 1) to the first page with data (2) and rendered it.
      // (The pager may then fetch further on its own to fill the viewport; that tail isn't the point.)
      check(fetcher.requested.take(3)).deepEquals(const [0, 1, 2]);
      check(find.text('item 1').evaluate()).length.equals(1);
      check(find.text('item 2').evaluate()).length.equals(1);
    });

    scenarioWidgets('the default (ShowEmptySurface) stops on the first empty page', (tester) async {
      final fetcher = recordingFetcher(const <List<int>>[
        [],
        [1, 2],
      ]);

      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: fetcher.fetchPage,
          endPolicy: const StopOnEmptyPagesPolicy(emptyRunBeforeEnd: 5),
          // onEmptyPage omitted: defaults to ShowEmptySurface.
          refresh: const NoRefresh(),
          itemBuilder: (_, item, _) => Text('item $item'),
        ),
      );
      await drain(tester, frames: 12);

      // No advance: the empty page shows the empty surface and page 1's data is never requested.
      check(fetcher.requested).deepEquals(const [0]);
      check(find.text('item 1').evaluate()).length.equals(0);
    });

    scenarioWidgets('maxPages caps the advance, then shows the empty surface', (tester) async {
      final fetcher = recordingFetcher(const <List<int>>[
        [],
        [],
        [],
        [1, 2],
      ]);

      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: fetcher.fetchPage,
          endPolicy: const StopOnEmptyPagesPolicy(emptyRunBeforeEnd: 10),
          onEmptyPage: const AdvanceToFirstNonEmpty(maxPages: 2),
          refresh: const NoRefresh(),
          itemBuilder: (_, item, _) => Text('item $item'),
        ),
      );
      await drain(tester, frames: 12);

      // Gave up after fetching maxPages pages (0 and 1); the data on page 3 is never reached.
      check(fetcher.requested).deepEquals(const [0, 1]);
      check(find.text('item 1').evaluate()).length.equals(0);
    });

    scenarioWidgets('advancing is gated by the end policy, not just the behaviour', (tester) async {
      final fetcher = recordingFetcher(const <List<int>>[
        [],
        [1, 2],
      ]);

      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: fetcher.fetchPage,
          // The default policy ends on the first empty page, so there is no next page to advance to.
          onEmptyPage: const AdvanceToFirstNonEmpty(),
          refresh: const NoRefresh(),
          itemBuilder: (_, item, _) => Text('item $item'),
        ),
      );
      await drain(tester, frames: 12);

      check(fetcher.requested).deepEquals(const [0]);
      check(find.text('item 1').evaluate()).length.equals(0);
    });
  });
}
