import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith/list_smith.dart';

import '../support/support.dart';

typedef _Item = ({String group, String label});

void main() {
  Grouping<_Item> byGroup({GroupOrderPolicy orderPolicy = const RepairHeadersPolicy()}) =>
      Grouping.by(
        groupBy: (item) => item.group,
        headerBuilder: (_, key) => Text('section $key'),
        orderPolicy: orderPolicy,
      );

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
            (request) async => request.pageIndex == 0
                ? const [
                    (group: 'A', label: 'apple'),
                    (group: 'A', label: 'avocado'),
                    (group: 'B', label: 'banana'),
                  ]
                : const <_Item>[],
          ),
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
          endPolicy: const FixedPageCountPolicy(pageCount: 2),
          refresh: const NoRefresh(),
          grouping: byGroup(),
          itemBuilder: (_, item, _) => Text(item.label),
        ),
      );
      await drain(tester, frames: 12);

      // B opens at the end of page 0 and runs into page 1. Headers come from every loaded page, so
      // B gets one. A page-local fold would draw two.
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
          endPolicy: const FixedPageCountPolicy(pageCount: 3),
          refresh: const NoRefresh(),
          grouping: byGroup(),
          itemBuilder: (_, item, _) => Text(item.label),
        ),
      );
      await drain(tester, frames: 16);

      // Page 1 is all B, so this reaches back past a whole page. A two-page case cannot tell
      // 'every page' from 'the last two'.
      check(find.text('section B').evaluate()).length.equals(1);
      check(find.text('section A').evaluate()).length.equals(1);
      check(find.text('section C').evaluate()).length.equals(1);
    });

    scenarioWidgets('an itemId duplicate inside a straddling group keeps the header single', (
      tester,
    ) async {
      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: pagedFetcher(const [
            [(group: 'A', label: 'a1'), (group: 'A', label: 'a2'), (group: 'B', label: 'b1')],
            [(group: 'B', label: 'b1'), (group: 'B', label: 'b2'), (group: 'C', label: 'c1')],
          ]),
          itemId: (item) => item.label,
          endPolicy: const FixedPageCountPolicy(pageCount: 2),
          refresh: const NoRefresh(),
          grouping: byGroup(),
          itemBuilder: (_, item, _) => Text(item.label),
        ),
      );
      await drain(tester, frames: 12);

      // De-dup runs before the view sees the state, so headers read the de-duped list. b1 collapses
      // and B still opens once.
      check(find.text('section B').evaluate()).length.equals(1);
      check(find.text('b1').evaluate()).length.equals(1);
      check(find.text('section A').evaluate()).length.equals(1);
      check(find.text('section C').evaluate()).length.equals(1);
    });

    scenarioWidgets('an itemId keeps groups contiguous when pages overlap across a boundary', (
      tester,
    ) async {
      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: pagedFetcher(const [
            [(group: 'A', label: 'a1'), (group: 'A', label: 'a2'), (group: 'B', label: 'b1')],
            [(group: 'A', label: 'a2'), (group: 'B', label: 'b1'), (group: 'B', label: 'b2')],
          ]),
          itemId: (item) => item.label,
          endPolicy: const FixedPageCountPolicy(pageCount: 2),
          refresh: const NoRefresh(),
          grouping: byGroup(),
          itemBuilder: (_, item, _) => Text(item.label),
        ),
      );
      await drain(tester, frames: 12);

      // Raw, page 1 reads back A, A, B, A, B, B and breaks group order. De-dup collapses the
      // overlap first, so grouping never sees it. itemId is load-bearing for grouping here.
      check(find.text('section A').evaluate()).length.equals(1);
      check(find.text('section B').evaluate()).length.equals(1);
      check(find.text('a2').evaluate()).length.equals(1);
    });

    scenarioWidgets('without an itemId, an overlap across a boundary trips the order assert', (
      tester,
    ) async {
      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: pagedFetcher(const [
            [(group: 'A', label: 'a1'), (group: 'A', label: 'a2'), (group: 'B', label: 'b1')],
            [(group: 'A', label: 'a2'), (group: 'B', label: 'b1'), (group: 'B', label: 'b2')],
          ]),
          endPolicy: const FixedPageCountPolicy(pageCount: 2),
          refresh: const NoRefresh(),
          grouping: byGroup(),
          itemBuilder: (_, item, _) => Text(item.label),
        ),
      );
      await drain(tester, frames: 12);

      // Same overlap, no itemId. Nothing collapses, A comes back after B opened, assert fires.
      check(tester.takeException()).isA<AssertionError>();
    });

    scenarioWidgets('FailOnUnorderedPolicy throws instead of asserting', (tester) async {
      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: pagedFetcher(const [
            [(group: 'A', label: 'a1'), (group: 'B', label: 'b1'), (group: 'A', label: 'a2')],
          ]),
          refresh: const NoRefresh(),
          grouping: byGroup(orderPolicy: const FailOnUnorderedPolicy()),
          itemBuilder: (_, item, _) => Text(item.label),
        ),
      );
      await drain(tester);

      // Default only asserts, so release would let this slide. This is the opt-in to fail loud.
      check(tester.takeException()).isA<StateError>();
    });

    scenarioWidgets('asserts when a page is not ordered by group key', (tester) async {
      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: PageFetcher(
            (request) async => request.pageIndex == 0
                ? const [
                    (group: 'A', label: 'apple'),
                    (group: 'B', label: 'banana'),
                    (group: 'A', label: 'avocado'),
                  ]
                : const <_Item>[],
          ),
          refresh: const NoRefresh(),
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
