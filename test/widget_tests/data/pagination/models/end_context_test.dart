// Test-local fixtures share the file with the scenarios that use them.
// ignore_for_file: prefer-match-file-name

import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:list_smith/list_smith.dart';

import '../../../../support/support.dart';

void main() {
  feature('ListSmith.async EndContext', () {
    scenarioWidgets("a policy sees every page's item count in fetch order, and can't change them", (
      tester,
    ) async {
      final recordingPolicy = _RecordingEndPolicy();

      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: pagedFetcher(const [
            [1, 2, 3],
            [4],
          ]),
          itemIdGetter: (item) => item,
          endPolicy: recordingPolicy,
          refresh: const NoRefresh(),
          itemBuilder: (_, item, _) => Text('item $item'),
        ),
      );
      await drain(tester, frames: 12);

      final pageItemCounts = recordingPolicy.seenEndContexts.last.pageItemCounts;
      check(pageItemCounts).deepEquals(const [3, 1, 0]);
      check(() => pageItemCounts[0] = 0).throws<UnsupportedError>();
    });
  });
}

/// Keeps every context it's handed.
final class _RecordingEndPolicy() extends PaginationEndPolicy {
  final List<EndContext> seenEndContexts = [];

  @override
  bool hasReachedEnd(EndContext context) {
    seenEndContexts.add(context);

    return context.trailingEmptyRun > 0;
  }
}
