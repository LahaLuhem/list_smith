import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith/list_smith.dart';

import '../support/support.dart';

void main() {
  feature('ListSmith.async 1st-page loads', () {
    Future<void> pumpList(
      WidgetTester tester,
      FakeServer<int> server, {
      ListSmithController<int>? controller,
    }) => pumpListSmith(
      tester,
      ListSmith.async(
        fetchPage: server.offsetLateFetcher,
        itemIdGetter: (item) => item,
        pageSize: 3,
        endPolicy: const FixedPageCountPolicy(pageCount: 1),
        controller: controller,
        itemBuilder: (_, item, _) => SizedBox(height: 50, child: Text('item $item')),
      ),
    );

    scenarioOutlineWidgets<List<Future<void> Function(ListSmithController<int> controller)>>(
      'restarts from code a frame apart during the 1st load still land a page',
      examples: {
        'refresh() twice': [
          (controller) => controller.refresh(),
          (controller) => controller.refresh(),
        ],
        'refresh() then reset()': [
          (controller) => controller.refresh(),
          (controller) => controller.reset(),
        ],
        'invalidate() right after mount': [(controller) => controller.invalidate()],
      },
      outline: (tester, restarts) async {
        final server = FakeServer<int>([1, 2, 3]);
        final firstLoad = server.hold(0, attempt: 1);
        final controller = ListSmithController<int>();
        await pumpList(tester, server, controller: controller);

        for (final restart in restarts) {
          unawaited(restart(controller));
          await tester.pump();
        }
        await release(tester, [firstLoad]);

        check(find.text('item 1').evaluate()).length.equals(1);
      },
    );
  });
}
