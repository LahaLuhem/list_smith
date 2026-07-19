import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith_example/main.dart';

import 'support/bdd.dart';

/// Pumps the example app and settles the first frame.
Future<void> pumpExampleApp(WidgetTester tester) async {
  await tester.pumpWidget(const ListSmithExampleApp());
  await tester.pump();
}

void main() {
  feature('list_smith example app', () {
    scenarioWidgets('home lists the demos, and the basic feed loads its items', (tester) async {
      await pumpExampleApp(tester);

      check(find.text('Basic feed').evaluate()).length.equals(1);

      await tester.tap(find.text('Basic feed'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      check(find.text('Item 1').evaluate()).length.equals(1);
    });

    scenarioWidgets('custom surfaces: the custom loader shows, then items load', (tester) async {
      await pumpExampleApp(tester);

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

    scenarioWidgets('playground pages past its empty first page to the data', (tester) async {
      // The playground stacks its knob panel above the list; give it enough height for the list to
      // render items under the knobs, but not so tall it over-fetches pages to fill the viewport.
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpExampleApp(tester);

      await tester.tap(find.text('Playground'));
      await tester.pump();
      // Page 0 is empty; with the default advance-past-empty, the list fetches page 0 then page 1,
      // so give both fetches time to settle.
      for (var frame = 0; frame < 12; frame++) {
        await tester.pump(const Duration(milliseconds: 300));
      }

      check(find.text('Item 21').evaluate()).length.equals(1);
    });

    scenarioWidgets('sync search filters the in-memory list as you type', (tester) async {
      await pumpExampleApp(tester);

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
      await pumpExampleApp(tester);

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
      await pumpExampleApp(tester);

      // Observer sits near the bottom of the hub; scroll it into view before tapping.
      await tester.scrollUntilVisible(find.text('Observer'), 100);
      await tester.tap(find.text('Observer'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      check(find.text('Item 1').evaluate()).length.equals(1);
      check(find.textContaining('onPageLoaded').evaluate().length).isGreaterThan(0);
    });

    scenarioWidgets('grouping shows the in-memory list in labelled sections', (tester) async {
      await pumpExampleApp(tester);

      await tester.tap(find.text('Grouping'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      check(find.text('Item 1').evaluate()).length.equals(1);
      // The first item (id 0) sits in the 'Alpha' section, whose header renders above it.
      check(find.text('Alpha').evaluate()).length.equals(1);
    });

    scenarioWidgets('reload demo loads its stamped feed', (tester) async {
      await pumpExampleApp(tester);

      // Reload sits at the bottom of the hub; scroll it into view before tapping.
      await tester.scrollUntilVisible(find.text('Reload'), 100);
      await tester.tap(find.text('Reload'));
      await tester.pump();
      // The feed fetches with a 500ms latency; pump enough for the first pages to settle.
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 300));
      }

      check(find.text('Item 1').evaluate()).length.equals(1);
      // Each item carries its per-page fetch stamp, "load #1" on the first load.
      check(find.textContaining('load #1').evaluate().length).isGreaterThan(0);
    });
  });
}
