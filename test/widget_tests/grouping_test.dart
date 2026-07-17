import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith/list_smith.dart';

import '../support/support.dart';

typedef _Item = ({String group, String label});

void main() {
  Grouping<_Item> byGroup() =>
      Grouping.by(groupBy: (item) => item.group, headerBuilder: (_, key) => Text('section $key'));

  feature('ListSmith.sync grouping', () {
    scenarioWidgets('buckets unsorted items into sections, one header per group', (tester) async {
      await pumpListSmith(
        tester,
        ListSmith.sync(
          items: const [
            (group: 'A', label: 'apple'),
            (group: 'B', label: 'banana'),
            (group: 'A', label: 'avocado'),
          ],
          searchBy: (item, query) => item.label.contains(query),
          grouping: byGroup(),
          itemBuilder: (_, item, _) => Text(item.label),
        ),
      );
      await tester.pump();

      // Input order A, B, A is bucketed to A, A, B: exactly one header per group.
      check(find.text('section A').evaluate()).length.equals(1);
      check(find.text('section B').evaluate()).length.equals(1);
      check(find.text('avocado').evaluate()).length.equals(1);
    });
  });

  feature('ListSmith.async grouping', () {
    scenarioWidgets('adds a header at each group boundary of a pre-sorted page', (tester) async {
      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: PageFetcher(
            (pageIndex, _) async => pageIndex == 0
                ? const [
                    (group: 'A', label: 'apple'),
                    (group: 'A', label: 'avocado'),
                    (group: 'B', label: 'banana'),
                  ]
                : const <_Item>[],
          ),
          pullToRefresh: false,
          grouping: byGroup(),
          itemBuilder: (_, item, _) => Text(item.label),
        ),
      );
      await drain(tester);

      check(find.text('section A').evaluate()).length.equals(1);
      check(find.text('section B').evaluate()).length.equals(1);
      check(find.text('banana').evaluate()).length.equals(1);
    });

    scenarioWidgets('asserts when a page is not ordered by group key', (tester) async {
      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: PageFetcher(
            (pageIndex, _) async => pageIndex == 0
                ? const [
                    (group: 'A', label: 'apple'),
                    (group: 'B', label: 'banana'),
                    (group: 'A', label: 'avocado'),
                  ]
                : const <_Item>[],
          ),
          pullToRefresh: false,
          grouping: byGroup(),
          itemBuilder: (_, item, _) => Text(item.label),
        ),
      );
      await drain(tester);

      // The A, B, A page breaks the pre-sorted contract, so the debug assert fires during build.
      check(tester.takeException()).isA<AssertionError>();
    });
  });
}
