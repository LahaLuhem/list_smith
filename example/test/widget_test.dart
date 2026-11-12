import 'package:checks/checks.dart';
import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoTheme;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_slidable/flutter_slidable.dart' show Slidable;
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith_example/features/core/widgets/event_log_panel.dart';
import 'package:material_ui/material_ui.dart' show Theme;
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

    scenarioOutlineWidgets<
      ({TargetPlatform platform, Brightness Function(BuildContext context) brightnessOf})
    >(
      'the brightness toggle cycles light, then dark, then back to following the device',
      examples: {
        'Material': (platform: .android, brightnessOf: (context) => Theme.of(context).brightness),
        'Cupertino': (platform: .iOS, brightnessOf: CupertinoTheme.brightnessOf),
      },
      outline: (tester, example) async {
        // On the hub, the app bar's only icon.
        final toggleFinder = find.descendant(
          of: find.byType(NavigationToolbar),
          matching: find.byType(Icon),
        );
        Brightness shownBrightness() =>
            example.brightnessOf(tester.element(find.text('Basic feed')));

        debugDefaultTargetPlatformOverride = example.platform;
        tester.platformDispatcher.platformBrightnessTestValue = .dark;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        await pumpExampleApp(tester);

        final shownBrightnesses = [shownBrightness()];
        for (var tap = 0; tap < 3; tap++) {
          await tester.tap(toggleFinder);
          await drain(tester, frames: 3, step: const Duration(milliseconds: 100));
          shownBrightnesses.add(shownBrightness());
        }
        tester.platformDispatcher.platformBrightnessTestValue = .light;
        await drain(tester, frames: 3, step: const Duration(milliseconds: 100));
        shownBrightnesses.add(shownBrightness());
        debugDefaultTargetPlatformOverride = null;

        // The last turns light with the device.
        check(shownBrightnesses).deepEquals([
          Brightness.dark,
          Brightness.light,
          Brightness.dark,
          Brightness.dark,
          Brightness.light,
        ]);
      },
    );

    scenarioWidgets('the cursor feed pages on from where the last page ended', (tester) async {
      await openDemo(tester, 'Cursor feed', surfaceSize: tallSurfaceSize);
      await drain(tester, frames: 8, step: const Duration(milliseconds: 300));

      await tester.drag(find.text('Item 1'), const Offset(0, -800));
      await drain(tester, frames: 8, step: const Duration(milliseconds: 300));

      check(find.text('Item 21').evaluate()).length.equals(1);
    });

    scenarioOutlineWidgets<({AsyncValueSetter<WidgetTester> failPage, String loadedTitle})>(
      "the custom error's Retry loads the page once failures are off",
      examples: {
        'the 1st page': (
          failPage: (tester) async {
            // Past the route's entrance, before the page lands.
            await tester.pump(const Duration(milliseconds: 400));
            await tester.tap(knobSwitchFinder('Inject fetch failures'));
            await drain(tester, frames: 8, step: const Duration(milliseconds: 300));
          },
          loadedTitle: 'Item 1',
        ),
        // Page 1 lands with page 0, so page 2 is the 1st to fail.
        'a next page': (
          failPage: (tester) async {
            await drain(tester, frames: 8, step: const Duration(milliseconds: 300));
            await tester.tap(knobSwitchFinder('Inject fetch failures'));
            await tester.pump();
            await tester.scrollUntilVisible(find.text('Could not load more.'), 300);
          },
          loadedTitle: 'Item 41',
        ),
      },
      outline: (tester, example) async {
        await openDemo(tester, 'Custom surfaces', surfaceSize: tallSurfaceSize);
        await example.failPage(tester);
        check(find.text(example.loadedTitle, skipOffstage: false).evaluate()).isEmpty();

        await tester.tap(knobSwitchFinder('Inject fetch failures'));
        await tester.pump();
        await tester.tap(find.text('Retry'));
        await drain(tester, frames: 8, step: const Duration(milliseconds: 300));

        check(find.text(example.loadedTitle, skipOffstage: false).evaluate()).length.equals(1);
      },
    );

    scenarioWidgets('the custom arrow turns over once the pull is armed', (tester) async {
      int arrowQuarterTurns() => tester.widget<RotatedBox>(find.byType(RotatedBox)).quarterTurns;

      await openDemo(tester, 'Custom surfaces', surfaceSize: tallSurfaceSize);
      await drain(tester, frames: 8, step: const Duration(milliseconds: 300));

      final gesture = await tester.startGesture(tester.getCenter(find.text('Item 1')));
      await gesture.moveBy(const Offset(0, 50));
      await tester.pump();
      final draggingQuarterTurns = arrowQuarterTurns();
      await gesture.moveBy(const Offset(0, 250));
      await tester.pump();
      final armedQuarterTurns = arrowQuarterTurns();
      await gesture.up();
      await drain(tester, frames: 8, step: const Duration(milliseconds: 300)); // the refresh

      check(armedQuarterTurns).equals((draggingQuarterTurns + 2) % 4);
    });

    scenarioOutlineWidgets<({AsyncValueSetter<WidgetTester> turnKnob, Finder shownFinder})>(
      'a playground knob read only as the list is built gives a fresh list that uses it',
      examples: {
        'page size, up to 40': (
          turnKnob: (tester) => tester.drag(knobSliderFinder('Page size'), const Offset(1000, 0)),
          shownFinder: find.text('Item 41'),
        ),
        // The empty 1st page then ends the list.
        'empty pages before end, down to 1': (
          turnKnob: (tester) =>
              tester.drag(knobSliderFinder('Empty pages before end'), const Offset(-1000, 0)),
          shownFinder: find.text('No items'),
        ),
        'page past empty pages, off': (
          turnKnob: (tester) => tester.tap(knobSwitchFinder('Page past empty pages')),
          shownFinder: find.text('No items'),
        ),
      },
      outline: (tester, example) async {
        await openDemo(tester, 'Playground', surfaceSize: tallSurfaceSize);
        // Page 0 is empty, so the list pages past it to page 1.
        await drain(tester, frames: 12, step: const Duration(milliseconds: 300));
        check(find.text('Item 21').evaluate()).length.equals(1);

        await example.turnKnob(tester);
        await drain(tester, frames: 12, step: const Duration(milliseconds: 300));

        check(find.text('Item 21').evaluate()).isEmpty();
        check(example.shownFinder.evaluate()).length.equals(1);
      },
    );

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

    scenarioWidgets('async search logs a failed fetch with its error', (tester) async {
      await openDemo(tester, 'Async search', surfaceSize: tallSurfaceSize);
      await drain(tester, frames: 8, step: const Duration(milliseconds: 300));

      await tester.tap(knobSwitchFinder('Inject failures'));
      await tester.pump();
      await tester.fling(find.text('Item 1'), const Offset(0, 300), 1000);
      await drain(tester, frames: 10, step: const Duration(milliseconds: 300));

      final loggedErrorFinder = find.descendant(
        of: find.byType(EventLogPanel),
        matching: find.textContaining('Simulated network failure'),
      );
      check(loggedErrorFinder.evaluate()).length.equals(1);
    });

    scenarioWidgets('async search looks a code up from code, and End search brings the feed back', (
      tester,
    ) async {
      await openDemo(tester, 'Async search', surfaceSize: tallSurfaceSize);
      await drain(tester, frames: 8, step: const Duration(milliseconds: 300));
      check(find.text('Item 1').evaluate()).length.equals(1);

      await tester.tap(find.text('Look up 13 from code'));
      await drain(tester, frames: 8, step: const Duration(milliseconds: 300));

      // Typed, 13 also finds 113, so its absence shows the lookup's own endpoint answered.
      check(find.text('Item 13').evaluate()).length.equals(1);
      check(find.text('Item 113').evaluate()).length.equals(0);
      check(find.text('Item 1').evaluate()).length.equals(0);

      await tester.tap(find.text('End search'));
      await drain(tester, frames: 8, step: const Duration(milliseconds: 300));

      check(find.text('Item 1').evaluate()).length.equals(1);
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

    scenarioWidgets('with Route on trigger off, a pull hands back the cached rows', (tester) async {
      await openDemo(tester, 'Cache routing', surfaceSize: tallSurfaceSize);
      await drain(tester, frames: 8, step: const Duration(milliseconds: 300));

      await tester.tap(knobSwitchFinder('Route on trigger'));
      await tester.pump();
      await tester.fling(find.text('Item 1'), const Offset(0, 300), 1000);
      await drain(tester, frames: 10, step: const Duration(milliseconds: 300));

      // The pull did run, and read the cache.
      check(find.textContaining('refresh · cache').evaluate()).length.equals(1);
      check(find.text('from fetch #1').evaluate().length).isGreaterThan(0);
    });

    scenarioWidgets('after Clear cache, a pull fetches every page from the network', (
      tester,
    ) async {
      Set<String?> shownStamps() => tester
          .widgetList<Text>(find.textContaining('from fetch #', skipOffstage: false))
          .map((text) => text.data)
          .toSet();

      await openDemo(tester, 'Cache routing', surfaceSize: tallSurfaceSize);
      await drain(tester, frames: 8, step: const Duration(milliseconds: 300));
      final coldStamps = shownStamps();

      await tester.tap(find.text('Clear cache'));
      await tester.pump();
      await tester.fling(find.text('Item 1'), const Offset(0, 300), 1000);
      await drain(tester, frames: 10, step: const Duration(milliseconds: 300));
      final pulledStamps = shownStamps();

      check(pulledStamps).isNotEmpty();
      check(pulledStamps.intersection(coldStamps)).isEmpty();
    });

    scenarioOutlineWidgets<String>(
      'Clear empties the event log',
      examples: const {'async search': 'Async search', 'cache routing': 'Cache routing'},
      outline: (tester, demoTitle) async {
        final loggedEventsFinder = find.descendant(
          of: find.byType(EventLogPanel),
          matching: find.byType(ListView),
        );

        await openDemo(tester, demoTitle, surfaceSize: tallSurfaceSize);
        await drain(tester, frames: 8, step: const Duration(milliseconds: 300));
        check(loggedEventsFinder.evaluate()).isNotEmpty();

        await tester.tap(find.text('Clear'));
        await tester.pump();

        check(loggedEventsFinder.evaluate()).isEmpty();
      },
    );

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

      await tester.tap(knobSwitchFinder('Inject a failure on reload'));
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

    scenarioWidgets("an edits row's menu renames that row", (tester) async {
      await openDemo(tester, 'Edits', surfaceSize: tallSurfaceSize);
      await drain(tester, frames: 8, step: const Duration(milliseconds: 300));

      await tester.tap(_rowMenuFinder('Item 2'));
      await drain(tester, frames: 3, step: const Duration(milliseconds: 200));
      await tester.tap(find.text('Rename'));
      await drain(tester, frames: 3, step: const Duration(milliseconds: 200));
      await tester.enterText(find.byType(EditableText), 'Renamed row');
      await tester.tap(find.text('Save'));
      await drain(tester, frames: 3, step: const Duration(milliseconds: 200));

      check(find.text('Item 2').evaluate()).isEmpty();
      check(find.text('Renamed row').evaluate()).length.equals(1);
      await tester.pump(const Duration(seconds: 1)); // the save answering
    });

    scenarioWidgets("an edits row's menu deletes that row", (tester) async {
      await openDemo(tester, 'Edits', surfaceSize: tallSurfaceSize);
      await drain(tester, frames: 8, step: const Duration(milliseconds: 300));

      await tester.tap(_rowMenuFinder('Item 2'));
      await drain(tester, frames: 3, step: const Duration(milliseconds: 200));
      await tester.tap(find.text('Delete'));
      await drain(tester, frames: 3, step: const Duration(milliseconds: 200));
      await tester.tap(find.text('Delete').last); // the confirm's
      await drain(tester, frames: 6, step: const Duration(milliseconds: 200));

      check(find.text('Item 2', skipOffstage: false).evaluate()).isEmpty();
      check(find.text('Item 3').evaluate()).length.equals(1);
      await tester.pump(const Duration(seconds: 1)); // the delete answering
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

Finder _rowMenuFinder(String title) => find.descendant(
  of: find.ancestor(of: find.text(title), matching: find.byType(Slidable)),
  matching: find.byTooltip('More'),
);
