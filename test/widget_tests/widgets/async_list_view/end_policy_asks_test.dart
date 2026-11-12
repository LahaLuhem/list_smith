// Test-local fixtures share the file with the scenarios that use them.
// ignore_for_file: prefer-match-file-name

import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith/list_smith.dart';

import '../../../support/support.dart';

void main() {
  feature('ListSmith.async asking its end policy', () {
    scenarioWidgets('a drag over the rows asks nothing', (tester) async {
      final countingPolicy = await _pumpCounting(
        tester,
        pages: _twoPages,
        refresh: const NoRefresh(),
      );

      final callCountsPerUpdate = await _dragCounting(
        tester,
        countingPolicy,
        const Offset(0, -20),
        onLastUpdate: () =>
            check(tester.state<ScrollableState>(listScrollableFinder).position.pixels)
                .isGreaterThan(0),
      );

      check(callCountsPerUpdate).every((callCount) => callCount.equals(0));
    });

    scenarioWidgets('a drag over a surface asks nothing', (tester) async {
      final refreshPhases = <ListSmithRefreshPhase>{};
      final countingPolicy = await _pumpCounting(
        tester,
        pages: const [<int>[]],
        refresh: PullToRefresh(
          indicatorBuilder: (_, state) {
            refreshPhases.add(state.phase);

            return const SizedBox.shrink();
          },
        ),
      );

      // Too short to arm.
      final callCountsPerUpdate = await _dragCounting(tester, countingPolicy, const Offset(0, 4));

      check(refreshPhases).contains(.dragging);
      check(callCountsPerUpdate).every((callCount) => callCount.equals(0));
    });

    scenarioWidgets('an edit asks once', (tester) async {
      final controller = ListSmithController<int>();
      final countingPolicy = await _pumpCounting(
        tester,
        pages: _twoPages,
        refresh: const NoRefresh(),
        controller: controller,
      );
      final callCountBefore = countingPolicy.callCount;

      controller.upsert(5);
      await drain(tester, frames: 10);

      check(countingPolicy.callCount - callCountBefore).equals(1);
    });
  });
}

const _twoPages = [
  [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19],
  [20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39],
];

/// Settled, so only the shown state asks the policy.
Future<_CountingEndPolicy> _pumpCounting(
  WidgetTester tester, {
  required List<List<int>> pages,
  required Refresh refresh,
  ListSmithController<int>? controller,
}) async {
  final countingPolicy = _CountingEndPolicy();
  await pumpListSmith(
    tester,
    ListSmith<int>.async(
      fetchPage: pagedFetcher(pages),
      itemIdGetter: (item) => item,
      endPolicy: countingPolicy,
      refresh: refresh,
      controller: controller,
      itemBuilder: (_, item, _) => SizedBox(height: 50, child: Text('item $item')),
    ),
  );
  await drain(tester, frames: 30);

  return countingPolicy;
}

/// 10 drag updates of [stepOffset], and the policy calls each one made.
Future<List<int>> _dragCounting(
  WidgetTester tester,
  _CountingEndPolicy countingPolicy,
  Offset stepOffset, {
  VoidCallback? onLastUpdate,
}) async {
  final dragGesture = await tester.startGesture(tester.getCenter(listScrollableFinder));
  final callCountsPerUpdate = <int>[];
  for (var update = 0; update < 10; update++) {
    final callCountBefore = countingPolicy.callCount;
    await dragGesture.moveBy(stepOffset);
    await tester.pump();
    callCountsPerUpdate.add(countingPolicy.callCount - callCountBefore);
  }
  onLastUpdate?.call();
  await dragGesture.up();
  await drain(tester, frames: 30);

  return callCountsPerUpdate;
}

/// Counts its calls, ending like the default.
final class _CountingEndPolicy() extends PaginationEndPolicy {
  var callCount = 0;

  @override
  bool hasReachedEnd(EndContext context) {
    callCount++;

    return context.countTrailingEmptyPages() > 0;
  }
}
