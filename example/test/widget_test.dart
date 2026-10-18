import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_slidable/flutter_slidable.dart' show Slidable;
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith_example/features/core/widgets/bool_knob.dart';
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart' show PlatformSwitch;

import 'support/support.dart';

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
      await openDemo(tester, 'Custom surfaces');
      // Fixed pumps, so the loader is still up when it's checked.
      await tester.pump(const Duration(milliseconds: 300));

      check(find.text('Loading…').evaluate()).length.equals(1);

      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      check(find.text('Item 1').evaluate()).length.equals(1);
    });

    scenarioWidgets('playground pages past its empty first page to the data', (tester) async {
      await openDemo(tester, 'Playground', surfaceSize: tallSurfaceSize);
      // Page 0 is empty, so advance-past-empty fetches page 0 then page 1. Give both time.
      await drain(tester, frames: 12, step: const Duration(milliseconds: 300));

      check(find.text('Item 21').evaluate()).length.equals(1);
    });

    scenarioWidgets('sync search filters the in-memory list as you type', (tester) async {
      await openDemo(tester, 'Sync search');
      await tester.pump(const Duration(milliseconds: 400));

      check(find.text('Item 1').evaluate()).length.equals(1);

      await tester.enterText(find.byType(EditableText), '42');
      await tester.pump(); // rebuild with the new query, scheduling the debounce timer
      await tester.pump(const Duration(milliseconds: 50)); // fire the (zero) debounce, then filter

      check(find.text('Item 42').evaluate()).length.equals(1);
      check(find.text('Item 1').evaluate()).length.equals(0);
    });

    scenarioWidgets('async search switches to paginated search results', (tester) async {
      await openDemo(tester, 'Async search');
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

    scenarioWidgets('async search logs a page-loaded event as the feed loads', (tester) async {
      await openDemo(tester, 'Async search');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      check(find.text('Item 1').evaluate()).length.equals(1);
      check(find.textContaining('onPageLoaded').evaluate().length).isGreaterThan(0);
    });

    scenarioWidgets('sync search groups its list into labelled sections on a switch', (
      tester,
    ) async {
      await openDemo(tester, 'Sync search');
      await tester.pump(const Duration(milliseconds: 400));

      check(find.text('Alpha').evaluate()).isEmpty();

      await tester.tap(find.byType(PlatformSwitch));
      await tester.pump();

      check(find.text('Item 1').evaluate()).length.equals(1);
      // The 1st item (id 0) sits in the 'Alpha' section, whose header renders above it.
      check(find.text('Alpha').evaluate()).length.equals(1);
    });

    scenarioWidgets(
      'cache routing serves the cold load from the network, then bypasses on a pull',
      (tester) async {
        await openDemo(tester, 'Cache routing', surfaceSize: tallSurfaceSize);
        await drain(tester, frames: 8, step: const Duration(milliseconds: 300));

        // The cold load reported initialLoad and went to the network, stamping its rows.
        check(find.textContaining('initialLoad · network').evaluate().length).isGreaterThan(0);
        check(find.textContaining('from fetch #1').evaluate().length).isGreaterThan(0);

        await tester.fling(find.text('Item 1'), const Offset(0, 300), 1000);
        await drain(tester, frames: 10, step: const Duration(milliseconds: 300));

        // The pull reported refresh, so the fetch skipped the cache and re-stamped the 1st page.
        check(find.textContaining('refresh · network (bypassed)').evaluate().length)
            .isGreaterThan(0);
        check(find.textContaining('from fetch #1').evaluate()).length.equals(0);
        // The pages it then paged on to reported nextPage, so those came back from the cache: both halves
        // of the routing, not just the bypass.
        check(find.textContaining('· cache').evaluate().length).isGreaterThan(0);
      },
    );

    scenarioWidgets('reload demo loads its stamped feed', (tester) async {
      await openDemo(tester, 'Reload');
      // The feed fetches with a 500ms latency, so pump enough for the 1st pages to settle.
      await drain(tester, frames: 8, step: const Duration(milliseconds: 300));

      check(find.text('Item 1').evaluate()).length.equals(1);
      // Each item carries its per-page fetch stamp, "load #1" on the 1st load.
      check(find.textContaining('load #1').evaluate().length).isGreaterThan(0);
    });

    scenarioWidgets('the reload demo refreshes from code, with no pull', (tester) async {
      await openDemo(tester, 'Reload', surfaceSize: tallSurfaceSize);
      await drain(tester, frames: 8, step: const Duration(milliseconds: 300));
      check(find.textContaining('load #1').evaluate().length).isGreaterThan(0);

      await tester.tap(find.text('Refresh from code'));
      await drain(tester, frames: 8, step: const Duration(milliseconds: 300));

      // The button ran the pull's own reload (depth kept by default), so every page is re-stamped.
      check(find.textContaining('load #2').evaluate().length).isGreaterThan(0);
      check(find.textContaining('load #1').evaluate()).length.equals(0);
    });

    scenarioWidgets('the reload demo shows an injected failure after a pull', (tester) async {
      // Phone-sized, so only the 1st page loads before the pull.
      await openDemo(tester, 'Reload', surfaceSize: const Size(390, 844));
      await drain(tester, frames: 8, step: const Duration(milliseconds: 300));

      final injectKnobFinder = find.ancestor(
        of: find.text('Inject a failure on reload'),
        matching: find.byType(BoolKnob),
      );
      await tester.tap(
        find.descendant(of: injectKnobFinder, matching: find.byType(PlatformSwitch)),
      );
      await tester.pump();
      await tester.fling(find.text('Item 1'), const Offset(0, 300), 1000);
      await drain(tester, frames: 10, step: const Duration(milliseconds: 300));

      check(find.textContaining('Simulated reload failure').evaluate()).isNotEmpty();
    });

    scenarioWidgets('the edits demo adds on top, renames in place and swipes a row away', (
      tester,
    ) async {
      await openDemo(tester, 'Edits', surfaceSize: tallSurfaceSize);
      await drain(tester, frames: 8, step: const Duration(milliseconds: 300));

      await tester.tap(find.text('Add an item'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300)); // the new row grows in

      check(tester.getTopLeft(find.text('New item 1')).dy)
          .isLessThan(tester.getTopLeft(find.text('Item 1')).dy);

      final renamedRowTop = tester.getTopLeft(find.text('Item 2')).dy;
      // Short of a full swipe, so the row opens on its actions.
      await tester.timedDrag(
        find.text('Item 2'),
        const Offset(-300, 0),
        const Duration(milliseconds: 300),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Rename'));
      await drain(tester, frames: 3, step: const Duration(milliseconds: 200));
      await tester.enterText(find.byType(EditableText), 'Renamed row');
      await tester.tap(find.text('Save'));
      await drain(tester, frames: 3, step: const Duration(milliseconds: 200));

      check(find.text('Item 2').evaluate()).isEmpty();
      check(tester.getTopLeft(find.text('Renamed row')).dy).equals(renamedRowTop);

      // Timed, since a plain drag ends before the full-swipe pane has built, so the row only opens.
      await tester.timedDrag(
        find.text('Item 1'),
        const Offset(-700, 0),
        const Duration(milliseconds: 300),
      );
      // The dismissal then the resize take 300ms each.
      await drain(tester, frames: 6, step: const Duration(milliseconds: 200));

      check(find.text('Item 1').evaluate()).isEmpty();
      check(find.text('New item 1').evaluate()).length.equals(1);

      await tester.pump(const Duration(seconds: 1)); // the delete answering
      await tester.fling(find.text('New item 1'), const Offset(0, 300), 1000);
      await drain(tester, frames: 10, step: const Duration(milliseconds: 300));

      // Read again, so these are the server's copies.
      check(find.text('Item 1').evaluate()).isEmpty();
      check(tester.getTopLeft(find.text('New item 1')).dy)
          .isLessThan(tester.getTopLeft(find.text('Renamed row')).dy);
    });

    scenarioWidgets("the edits demo's Delete shrinks the row away", (tester) async {
      await openDemo(tester, 'Edits', surfaceSize: tallSurfaceSize);
      await drain(tester, frames: 8, step: const Duration(milliseconds: 300));

      final fullHeight = tester
          .getSize(find.ancestor(of: find.text('Item 3'), matching: find.byType(Slidable)))
          .height;
      // Short of a full swipe, so the row opens on its actions.
      await tester.timedDrag(
        find.text('Item 2'),
        const Offset(-300, 0),
        const Duration(milliseconds: 300),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Delete'));
      // The frame that checks the row didn't shrink itself, then the exit's 1st frame.
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final leavingFinder = find.ancestor(
        of: find.text('Item 2', skipOffstage: false),
        matching: find.byType(SizeTransition, skipOffstage: false),
      );

      check(tester.getSize(leavingFinder.first).height)
        ..isGreaterThan(0)
        ..isLessThan(fullHeight);
      await drain(tester, frames: 4, step: const Duration(milliseconds: 100));
      check(tester.takeException()).isNull();
      check(find.text('Item 2', skipOffstage: false).evaluate()).isEmpty();
      await tester.pump(const Duration(seconds: 1)); // the page load the removal set off
    });

    scenarioWidgets('a save failing after the edits demo is gone changes nothing', (tester) async {
      await openDemo(tester, 'Edits', surfaceSize: tallSurfaceSize);
      await drain(tester, frames: 8, step: const Duration(milliseconds: 300));

      await tester.tap(find.byType(PlatformSwitch));
      await tester.pump();
      await tester.tap(find.text('Add an item'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox()); // gone at once, before the save answers
      await drain(tester, frames: 10, step: const Duration(milliseconds: 100));

      check(tester.takeException()).isNull();
    });

    scenarioWidgets('with saves failing, each edit rolls back and says so', (tester) async {
      // In the list, not the rename dialog's field.
      Finder rowText(String text) =>
          find.descendant(of: find.byType(Slidable), matching: find.text(text));
      // A toast lasts 4s, and the next one waits for it.
      Future<void> waitOutTheToast() =>
          drain(tester, frames: 10, step: const Duration(milliseconds: 500));

      await openDemo(tester, 'Edits', surfaceSize: tallSurfaceSize);
      await drain(tester, frames: 8, step: const Duration(milliseconds: 300));

      await tester.tap(find.byType(PlatformSwitch));
      await tester.pump();

      await tester.tap(find.text('Add an item'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300)); // the new row grows in
      check(rowText('New item 1').evaluate()).length.equals(1);
      await drain(tester, frames: 10, step: const Duration(milliseconds: 100));
      check(rowText('New item 1').evaluate()).isEmpty();
      check(find.text("Couldn't save New item 1").evaluate()).length.equals(1);
      await waitOutTheToast();

      // Short of a full swipe, so the row opens on its actions.
      await tester.timedDrag(
        find.text('Item 2'),
        const Offset(-300, 0),
        const Duration(milliseconds: 300),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Rename'));
      await drain(tester, frames: 3, step: const Duration(milliseconds: 200));
      await tester.enterText(find.byType(EditableText), 'Renamed row');
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      check(rowText('Renamed row').evaluate()).length.equals(1);
      await drain(tester, frames: 10, step: const Duration(milliseconds: 100));
      check(rowText('Renamed row').evaluate()).isEmpty();
      check(rowText('Item 2').evaluate()).length.equals(1);
      check(find.text("Couldn't save Renamed row").evaluate()).length.equals(1);
      await waitOutTheToast();

      await tester.timedDrag(
        find.text('Item 1'),
        const Offset(-700, 0),
        const Duration(milliseconds: 300),
      );
      // The dismissal then the resize take 300ms each, and the delete fails 500ms after.
      for (var frame = 0; frame < 8 && find.text('Item 1').evaluate().isNotEmpty; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      check(find.text('Item 1').evaluate()).isEmpty();
      await drain(tester, frames: 10, step: const Duration(milliseconds: 100));

      check(find.text('Item 1').evaluate()).length.equals(1);
      check(find.text("Couldn't delete Item 1").evaluate()).length.equals(1);
    });

    scenarioWidgets('the sorted edits demo moves a renamed row to where its server sorts it', (
      tester,
    ) async {
      double rowTopOf(String text) => tester.getTopLeft(find.text(text)).dy;

      await openDemo(tester, 'Sorted edits', surfaceSize: tallSurfaceSize);
      await drain(tester, frames: 8, step: const Duration(milliseconds: 300));

      await tester.tap(find.text('Item 2'));
      await drain(tester, frames: 3, step: const Duration(milliseconds: 200));
      await tester.enterText(find.byType(EditableText), 'Item 5a');
      await tester.tap(find.text('Save'));
      await drain(tester, frames: 3, step: const Duration(milliseconds: 200));

      check(rowTopOf('Item 5a'))
        ..isGreaterThan(rowTopOf('Item 5'))
        ..isLessThan(rowTopOf('Item 6'));

      await tester.pump(const Duration(seconds: 1)); // the save answering
      await tester.fling(find.text('Item 1'), const Offset(0, 300), 1000);
      await drain(tester, frames: 10, step: const Duration(milliseconds: 300));

      // Read again, so now it's the server's copy.
      check(rowTopOf('Item 5a'))
        ..isGreaterThan(rowTopOf('Item 5'))
        ..isLessThan(rowTopOf('Item 6'));
    });

    scenarioWidgets('the sorted edits demo adds an item where its server sorts it, not on top', (
      tester,
    ) async {
      double rowTopOf(String text) => tester.getTopLeft(find.text(text)).dy;

      await openDemo(tester, 'Sorted edits', surfaceSize: tallSurfaceSize);
      await drain(tester, frames: 8, step: const Duration(milliseconds: 300));

      await tester.tap(find.text('Add an item'));
      await drain(tester, frames: 3, step: const Duration(milliseconds: 200));
      await tester.enterText(find.byType(EditableText), 'Item 3a');
      await tester.tap(find.text('Save'));
      // The new row grows in.
      await drain(tester, frames: 3, step: const Duration(milliseconds: 200));

      check(rowTopOf('Item 3a'))
        ..isGreaterThan(rowTopOf('Item 3'))
        ..isLessThan(rowTopOf('Item 4'));

      await tester.pump(const Duration(seconds: 1)); // the save answering
      await tester.fling(find.text('Item 1'), const Offset(0, 300), 1000);
      await drain(tester, frames: 10, step: const Duration(milliseconds: 300));

      check(rowTopOf('Item 3a'))
        ..isGreaterThan(rowTopOf('Item 3'))
        ..isLessThan(rowTopOf('Item 4'));
    });
  });
}
