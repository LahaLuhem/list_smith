import 'package:flutter/widgets.dart';
import 'package:flutter_slidable/flutter_slidable.dart' show Slidable;
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith/list_smith.dart';
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart' show PlatformButton;

import '../../test/support/support.dart';
import 'clip_driver.dart';

// pubspec.yaml lists the clips in doc/screenshots, and the README shows the rest from doc/clips.
void main() {
  setUpAll(setUpClips);

  // pub.dev makes the package's thumbnail from this clip's 1st frame, so it opens on a settled list.
  clip(
    'feed',
    docFolder: 'screenshots',
    storyboard: (clip) async {
      await clip.open('Basic feed', settle: _firstPageLoadDuration);
      await clip.hold(const Duration(milliseconds: 900));
      // A pull while at the top, since scrolling back up would overshoot into one on iOS. Far, so it
      // arms through iOS's bounce too.
      await clip.drag(_listFinder, const Offset(0, 400), const Duration(milliseconds: 700));
      await clip.hold(const Duration(milliseconds: 1500)); // the refresh
      await clip.drag(_listFinder, _toTheEndOffset, const Duration(milliseconds: 800));
      await clip.hold(const Duration(milliseconds: 1500)); // the next page loads in
    },
  );

  clip(
    'edits',
    docFolder: 'screenshots',
    storyboard: (clip) async {
      await clip.open('Edits', settle: _firstPageLoadDuration);
      await clip.hold(const Duration(milliseconds: 700));
      await clip.tap(find.text('Add an item'));
      await clip.hold(const Duration(milliseconds: 1000));
      // All the way, so the row goes at once.
      await clip.drag(
        find.text('Item 2'),
        const Offset(-500, 0),
        const Duration(milliseconds: 300),
      );
      await clip.hold(const Duration(milliseconds: 1200));
      await clip.tap(
        find.descendant(
          of: find.ancestor(of: find.text('Item 3'), matching: find.byType(Slidable)),
          matching: find.byType(PlatformButton),
        ),
      );
      await clip.hold(const Duration(milliseconds: 500));
      await clip.tap(find.text('Rename'));
      await clip.hold(const Duration(milliseconds: 600));
      await clip.type(find.byType(EditableText), 'Renamed');
      await clip.hold(const Duration(milliseconds: 300));
      await clip.tap(find.text('Save'));
      await clip.hold(const Duration(milliseconds: 1500));
    },
  );

  clip(
    'search',
    docFolder: 'screenshots',
    storyboard: (clip) async {
      await clip.open('Sync search');
      await clip.hold(const Duration(milliseconds: 800));
      await clip.tap(find.byType(EditableText));
      await clip.type(find.byType(EditableText), 'Item 2');
      await clip.hold(const Duration(milliseconds: 900));
      await clip.tap(knobSwitchFinder('Group into sections'));
      await clip.hold(const Duration(milliseconds: 1500));
      await clip.clear(find.byType(EditableText));
      await clip.hold(const Duration(milliseconds: 1000));
      await clip.tap(knobSwitchFinder('Group into sections'));
      await clip.hold(const Duration(milliseconds: 800));
    },
  );

  clip(
    'rollback',
    docFolder: 'clips',
    storyboard: (clip) async {
      await clip.open('Edits', settle: _firstPageLoadDuration);
      await clip.hold(const Duration(milliseconds: 600));
      await clip.tap(knobSwitchFinder('Saves fail'));
      await clip.hold(const Duration(milliseconds: 400));
      await clip.tap(find.text('Add an item'));
      // It shows, its save fails, and it leaves with a toast.
      await clip.hold(const Duration(milliseconds: 3000));
    },
  );

  clip(
    'sorted',
    docFolder: 'clips',
    storyboard: (clip) async {
      await clip.open('Sorted edits', settle: _firstPageLoadDuration);
      await clip.hold(const Duration(milliseconds: 600));
      await clip.tap(find.text('Item 2'));
      await clip.hold(const Duration(milliseconds: 600));
      await clip.type(find.byType(EditableText), 'Item 5a');
      await clip.hold(const Duration(milliseconds: 300));
      await clip.tap(find.text('Save'));
      await clip.hold(const Duration(milliseconds: 1800));
    },
  );

  clip(
    'states',
    docFolder: 'clips',
    storyboard: (clip) async {
      await clip.open('Custom surfaces');
      await clip.hold(const Duration(milliseconds: 900)); // the custom loader, then the 1st page
      await clip.tap(knobSwitchFinder('Inject fetch failures'));
      await clip.drag(_listFinder, _toTheEndOffset, const Duration(milliseconds: 800));
      // The next page fails into the custom error.
      await clip.hold(const Duration(milliseconds: 1400));
      await clip.tap(knobSwitchFinder('Inject fetch failures'));
      await clip.tap(find.text('Retry'));
      await clip.hold(const Duration(milliseconds: 1500));
    },
  );
}

/// Long enough for a demo's fake server to answer.
const _firstPageLoadDuration = Duration(seconds: 1);

/// Past whatever has loaded, on either look, so the next page's fetch starts on both at once.
const _toTheEndOffset = Offset(0, -3000);

final _listFinder = find.byWidgetPredicate((widget) => widget is ListSmith);
