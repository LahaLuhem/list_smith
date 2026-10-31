import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith/list_smith.dart';

import '../../../../support/support.dart';

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
          itemIdGetter: (item) => item.label,
          searchBy: (item, query) => item.label.contains(query),
          grouping: byGroup(),
          itemBuilder: (_, item, _) => Text(item.label),
        ),
      );
      await tester.pump();

      // Input order A, B, A is bucketed to A, A, B: exactly 1 header per group.
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
            (request) async => request.pageIndex == 0
                ? const [
                    (group: 'A', label: 'apple'),
                    (group: 'A', label: 'avocado'),
                    (group: 'B', label: 'banana'),
                  ]
                : const <_Item>[],
          ),
          itemIdGetter: (item) => item.label,
          refresh: const NoRefresh(),
          grouping: byGroup(),
          itemBuilder: (_, item, _) => Text(item.label),
        ),
      );
      await drain(tester);

      check(find.text('section A').evaluate()).length.equals(1);
      check(find.text('section B').evaluate()).length.equals(1);
      check(find.text('banana').evaluate()).length.equals(1);
    });

    scenarioWidgets('a group straddling a page boundary gets one header, not one per page', (
      tester,
    ) async {
      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: pagedFetcher(const [
            [(group: 'A', label: 'a1'), (group: 'A', label: 'a2'), (group: 'B', label: 'b1')],
            [(group: 'B', label: 'b2'), (group: 'B', label: 'b3'), (group: 'C', label: 'c1')],
          ]),
          itemIdGetter: (item) => item.label,
          endPolicy: const FixedPageCountPolicy(pageCount: 2),
          refresh: const NoRefresh(),
          grouping: byGroup(),
          itemBuilder: (_, item, _) => Text(item.label),
        ),
      );
      await drain(tester, frames: 12);

      // B opens at the end of page 0 and runs into page 1. Headers come from every loaded page, so B
      // gets one. A page-local fold would draw 2.
      check(find.text('section B').evaluate()).length.equals(1);
      check(find.text('section A').evaluate()).length.equals(1);
      check(find.text('section C').evaluate()).length.equals(1);
      check(find.text('b3').evaluate()).length.equals(1);
    });

    scenarioWidgets('a group spanning three pages still gets one header', (tester) async {
      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: pagedFetcher(const [
            [(group: 'A', label: 'a1'), (group: 'B', label: 'b1')],
            [(group: 'B', label: 'b2'), (group: 'B', label: 'b3')],
            [(group: 'B', label: 'b4'), (group: 'C', label: 'c1')],
          ]),
          itemIdGetter: (item) => item.label,
          endPolicy: const FixedPageCountPolicy(pageCount: 3),
          refresh: const NoRefresh(),
          grouping: byGroup(),
          itemBuilder: (_, item, _) => Text(item.label),
        ),
      );
      await drain(tester, frames: 16);

      // Page 1 is all B, so this reaches back past a whole page. A two-page case cannot tell 'every
      // page' from 'the last 2'.
      check(find.text('section B').evaluate()).length.equals(1);
      check(find.text('section A').evaluate()).length.equals(1);
      check(find.text('section C').evaluate()).length.equals(1);
    });

    scenarioWidgets('pages overlapping across a group boundary show each row once', (tester) async {
      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: pagedFetcher(const [
            [(group: 'A', label: 'a1'), (group: 'A', label: 'a2'), (group: 'B', label: 'b1')],
            [(group: 'A', label: 'a2'), (group: 'B', label: 'b1'), (group: 'B', label: 'b2')],
          ]),
          itemIdGetter: (item) => item.label,
          endPolicy: const FixedPageCountPolicy(pageCount: 2),
          refresh: const NoRefresh(),
          grouping: byGroup(),
          itemBuilder: (_, item, _) => Text(item.label),
        ),
      );
      await drain(tester, frames: 12);

      // Page 1 repeats a2 and b1. Grouping reads the list after de-dup, so a2 isn't gathered twice.
      check(find.text('a2').evaluate()).length.equals(1);
    });

    scenarioWidgets('FailOnUnorderedPolicy throws instead of gathering', (tester) async {
      await pumpListSmith(
        tester,
        ListSmith<_Item>.async(
          fetchPage: pagedFetcher(const [
            [(group: 'A', label: 'a1'), (group: 'B', label: 'b1'), (group: 'A', label: 'a2')],
          ]),
          itemIdGetter: (item) => item.label,
          refresh: const NoRefresh(),
          grouping: Grouping.by(
            groupBy: (item) => item.group,
            headerBuilder: (_, key) => Text('section $key'),
            orderPolicy: const FailOnUnorderedPolicy(),
          ),
          itemBuilder: (_, item, _) => Text(item.label),
        ),
      );
      await drain(tester);

      check(tester.takeException()).isA<StateError>();
    });

    scenarioWidgets('a key that comes back on a later page joins its section', (tester) async {
      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: pagedFetcher(const [
            [(group: 'A', label: 'a1'), (group: 'B', label: 'b1')],
            [(group: 'A', label: 'a2'), (group: 'C', label: 'c1')],
          ]),
          itemIdGetter: (item) => item.label,
          endPolicy: const FixedPageCountPolicy(pageCount: 2),
          refresh: const NoRefresh(),
          grouping: byGroup(),
          itemBuilder: (_, item, _) => Text(item.label),
        ),
      );
      await drain(tester, frames: 12);

      check(tester.getTopLeft(find.text('a2')).dy)
          .isLessThan(tester.getTopLeft(find.text('section B')).dy);
    });

    scenarioWidgets('the row being read holds still while a later page joins a section above it', (
      tester,
    ) async {
      final server = FakeServer<_Item>([
        (group: 'A', label: 'a1'),
        (group: 'A', label: 'a2'),
        for (var index = 1; index <= 8; index++) (group: 'B', label: 'b$index'),
        (group: 'A', label: 'a3'),
      ]);
      final pageHoldCompleter = server.hold(1, attempt: 1);
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: server.offsetLateFetcher,
          pageSize: 10,
          itemIdGetter: (item) => item.label,
          refresh: const NoRefresh(),
          grouping: byGroup(),
          scroll: ListScrollConfig(controller: scrollController),
          itemBuilder: (_, item, _) => SizedBox(height: 100, child: Text(item.label)),
        ),
      );
      await drain(tester);
      scrollController.jumpTo(300);
      await tester.pump();
      final readRowTop = tester.getTopLeft(find.text('b3')).dy;

      await release(tester, [pageHoldCompleter]);

      check(scrollController.offset).isGreaterThan(300); // a3 did land above
      check(tester.getTopLeft(find.text('b3')).dy).equals(readRowTop);
    });
  });
}
