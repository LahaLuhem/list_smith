import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_slidable/flutter_slidable.dart' show Slidable;
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith_example/features/core/widgets/bool_knob.dart';
import 'package:list_smith_example/main.dart';
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart' show PlatformSwitch;

import 'support/bdd.dart';

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
      // Fixed pumps, so the loader is still up when it's checked.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      check(find.text('Loading…').evaluate()).length.equals(1);

      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      check(find.text('Item 1').evaluate()).length.equals(1);
    });

    scenarioWidgets('playground pages past its empty first page to the data', (tester) async {
      // The playground stacks its knob panel above the list, so give the list room to render items under
      // the knobs, but not so tall it over-fetches pages to fill the viewport.
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpExampleApp(tester);

      await tester.tap(find.text('Playground'));
      await tester.pump();
      // Page 0 is empty, so advance-past-empty fetches page 0 then page 1. Give both time.
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

      // Observer sits near the bottom of the hub, so scroll it into view before tapping.
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
      // The 1st item (id 0) sits in the 'Alpha' section, whose header renders above it.
      check(find.text('Alpha').evaluate()).length.equals(1);
    });

    scenarioWidgets(
      'cache routing serves the cold load from the network, then bypasses on a pull',
      (tester) async {
        // Intro, knob, list, clear-cache row and log panel stack up, so give the list room.
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await pumpExampleApp(tester);

        await tester.scrollUntilVisible(find.text('Cache routing'), 100);
        await tester.tap(find.text('Cache routing'));
        await tester.pump();
        for (var frame = 0; frame < 8; frame++) {
          await tester.pump(const Duration(milliseconds: 300));
        }

        // The cold load reported initialLoad and went to the network, stamping its rows.
        check(find.textContaining('initialLoad · network').evaluate().length).isGreaterThan(0);
        check(find.textContaining('from fetch #1').evaluate().length).isGreaterThan(0);

        await tester.fling(find.text('Item 1'), const Offset(0, 300), 1000);
        for (var frame = 0; frame < 10; frame++) {
          await tester.pump(const Duration(milliseconds: 300));
        }

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
      await pumpExampleApp(tester);

      // Reload sits at the bottom of the hub, so scroll it into view before tapping.
      await tester.scrollUntilVisible(find.text('Reload'), 100);
      await tester.tap(find.text('Reload'));
      await tester.pump();
      // The feed fetches with a 500ms latency, so pump enough for the 1st pages to settle.
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 300));
      }

      check(find.text('Item 1').evaluate()).length.equals(1);
      // Each item carries its per-page fetch stamp, "load #1" on the 1st load.
      check(find.textContaining('load #1').evaluate().length).isGreaterThan(0);
    });

    scenarioWidgets('the reload demo refreshes from code, with no pull', (tester) async {
      // The knob panel plus its button needs the taller surface to sit above the list unclipped.
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpExampleApp(tester);

      await tester.scrollUntilVisible(find.text('Reload'), 100);
      await tester.tap(find.text('Reload'));
      await tester.pump();
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      check(find.textContaining('load #1').evaluate().length).isGreaterThan(0);

      await tester.tap(find.text('Refresh from code'));
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 300));
      }

      // The button ran the pull's own reload (depth kept by default), so every page is re-stamped.
      check(find.textContaining('load #2').evaluate().length).isGreaterThan(0);
      check(find.textContaining('load #1').evaluate()).length.equals(0);
    });

    scenarioWidgets('the reload demo shows an injected failure after a pull', (tester) async {
      // Phone-sized, so only the 1st page loads before the pull.
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpExampleApp(tester);

      await tester.scrollUntilVisible(find.text('Reload'), 100);
      await tester.tap(find.text('Reload'));
      await tester.pump();
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 300));
      }

      final injectKnobFinder = find.ancestor(
        of: find.text('Inject a failure on reload'),
        matching: find.byType(BoolKnob),
      );
      await tester.tap(
        find.descendant(of: injectKnobFinder, matching: find.byType(PlatformSwitch)),
      );
      await tester.pump();
      await tester.fling(find.text('Item 1'), const Offset(0, 300), 1000);
      for (var frame = 0; frame < 10; frame++) {
        await tester.pump(const Duration(milliseconds: 300));
      }

      check(find.textContaining('Simulated reload failure').evaluate()).isNotEmpty();
    });

    scenarioWidgets('the edits demo adds on top, renames in place and swipes a row away', (
      tester,
    ) async {
      // The intro, knob and button stack above the list, so give it room.
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpExampleApp(tester);

      await tester.scrollUntilVisible(find.text('Edits'), 100);
      await tester.tap(find.text('Edits'));
      await tester.pump();
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 300));
      }

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
      for (var frame = 0; frame < 3; frame++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      await tester.enterText(find.byType(EditableText), 'Renamed row');
      await tester.tap(find.text('Save'));
      for (var frame = 0; frame < 3; frame++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      check(find.text('Item 2').evaluate()).isEmpty();
      check(tester.getTopLeft(find.text('Renamed row')).dy).equals(renamedRowTop);

      // Timed, since a plain drag ends before the full-swipe pane has built, so the row only opens.
      await tester.timedDrag(
        find.text('Item 1'),
        const Offset(-700, 0),
        const Duration(milliseconds: 300),
      );
      // The dismissal then the resize take 300ms each.
      for (var frame = 0; frame < 6; frame++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      check(find.text('Item 1').evaluate()).isEmpty();
      check(find.text('New item 1').evaluate()).length.equals(1);
      await tester.pump(const Duration(seconds: 1)); // the delete answering
    });

    scenarioWidgets("the edits demo's Delete shrinks the row away", (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpExampleApp(tester);

      await tester.scrollUntilVisible(find.text('Edits'), 100);
      await tester.tap(find.text('Edits'));
      await tester.pump();
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 300));
      }

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
      for (var frame = 0; frame < 4; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      check(tester.takeException()).isNull();
      check(find.text('Item 2', skipOffstage: false).evaluate()).isEmpty();
      await tester.pump(const Duration(seconds: 1)); // the page load the removal set off
    });

    scenarioWidgets('with deletes failing, a row swiped away comes back by itself', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpExampleApp(tester);

      await tester.scrollUntilVisible(find.text('Edits'), 100);
      await tester.tap(find.text('Edits'));
      await tester.pump();
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 300));
      }

      await tester.tap(find.byType(PlatformSwitch));
      await tester.pump();
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
      for (var frame = 0; frame < 10; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      check(find.text('Item 1').evaluate()).length.equals(1);
    });
  });
}
