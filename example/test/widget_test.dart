import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith_example/main.dart';

import 'support/bdd.dart';

void main() {
  feature('list_smith example app', () {
    scenarioWidgets('home lists the demos, and the basic feed loads its items', (tester) async {
      await tester.pumpWidget(const ListSmithExampleApp());
      await tester.pump();

      check(find.text('Basic feed').evaluate()).length.equals(1);

      await tester.tap(find.text('Basic feed'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      check(find.text('Item 1').evaluate()).length.equals(1);
    });

    scenarioWidgets('custom surfaces: the custom loader shows, then items load', (tester) async {
      await tester.pumpWidget(const ListSmithExampleApp());
      await tester.pump();

      await tester.tap(find.text('Custom surfaces'));
      // Drive the route transition, then assert the custom first-page loader is
      // up before the fake fetch resolves; the spinner animates forever so we
      // never pumpAndSettle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      check(find.text('Loading…').evaluate()).length.equals(1);

      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      check(find.text('Item 1').evaluate()).length.equals(1);
    });

    scenarioWidgets('playground loads its gappy source', (tester) async {
      await tester.pumpWidget(const ListSmithExampleApp());
      await tester.pump();

      await tester.tap(find.text('Playground'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      check(find.text('Item 1').evaluate()).length.equals(1);
    });

    scenarioWidgets('sync search filters the in-memory list as you type', (tester) async {
      await tester.pumpWidget(const ListSmithExampleApp());
      await tester.pump();

      await tester.tap(find.text('Sync search'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      check(find.text('Item 1').evaluate()).length.equals(1);

      await tester.enterText(find.byType(EditableText), '42');
      await tester.pump(); // rebuild with the new query, scheduling the debounce timer
      await tester.pump(const Duration(milliseconds: 50)); // fire the (zero) debounce, then filter

      check(find.text('Item 42').evaluate()).length.equals(1);
      check(find.text('Item 1').evaluate()).length.equals(0);
    });

    scenarioWidgets('async search switches to paginated search results', (tester) async {
      await tester.pumpWidget(const ListSmithExampleApp());
      await tester.pump();

      await tester.tap(find.text('Async search'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      check(find.text('Item 1').evaluate()).length.equals(1);

      await tester.enterText(find.byType(EditableText), '42');
      await tester.pump(); // rebuild with the new query, scheduling the debounce timer
      await tester.pump(
        const Duration(milliseconds: 400),
      ); // fire the 300ms debounce → search page 0
      await tester.pump(
        const Duration(seconds: 1),
      ); // page 0 (one match) arrives, pulling a partial page 1
      await tester.pump(const Duration(seconds: 1)); // page 1 (empty) arrives → end of results
      await tester.pump();

      check(find.text('Item 42').evaluate()).length.equals(1);
      check(find.text('Item 1').evaluate()).length.equals(0);
    });

    scenarioWidgets('observer logs a page-loaded event as the feed loads', (tester) async {
      await tester.pumpWidget(const ListSmithExampleApp());
      await tester.pump();

      await tester.tap(find.text('Observer'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      check(find.text('Item 1').evaluate()).length.equals(1);
      check(find.textContaining('onPageLoaded').evaluate().length).isGreaterThan(0);
    });
  });
}
