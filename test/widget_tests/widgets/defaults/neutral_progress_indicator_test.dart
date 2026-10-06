import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith/list_smith.dart';

import '../../../support/support.dart';

void main() {
  feature('The neutral progress indicator', () {
    scenarioWidgets('the neutral spinner repaints when the ambient colour changes', (tester) async {
      final holdCompleter = Completer<List<int>>();
      Widget build(Color colour) => DefaultTextStyle(
        style: TextStyle(color: colour),
        child: ListSmith.async(
          fetchPage: PageFetcher(
            (request) =>
                request.pageIndex == 0 ? holdCompleter.future : Future.value(const <int>[]),
          ),
          itemIdGetter: (item) => item,
          refresh: const NoRefresh(),
          itemBuilder: (_, item, _) => Text('item $item'),
        ),
      );

      // Held on the 1st page, so the neutral spinner is what is on screen.
      await pumpListSmith(tester, build(const Color(0xFFFF0000)));
      await drain(tester);
      check(find.byType(CustomPaint).evaluate()).isNotEmpty();

      // Re-pump under a different ambient colour: the arc painter has to notice and repaint.
      await pumpListSmith(tester, build(const Color(0xFF0000FF)));
      await drain(tester);
      check(find.byType(CustomPaint).evaluate()).isNotEmpty();

      holdCompleter.complete(const [1]);
      await tester.idle();
      await drain(tester);
      check(find.text('item 1').evaluate()).length.equals(1);
    });
  });
}
