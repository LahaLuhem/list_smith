import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith_example/features/core/widgets/title_sheet.dart';
import 'package:material_ui/material_ui.dart' show CloseButton;
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart' show PlatformApp;

import 'support/support.dart';

void main() {
  feature('Title sheet', () {
    scenarioOutlineWidgets<({String typedText, Finder pressedFinder, List<String> savedTitles})>(
      'it hands back the title typed, trimmed, and nothing when blank or closed',
      examples: {
        'a title with spaces around it, saved': (
          typedText: '  Item 5a  ',
          pressedFinder: find.text('Save'),
          savedTitles: ['Item 5a'],
        ),
        'a blank title, saved': (
          typedText: '   ',
          pressedFinder: find.text('Save'),
          savedTitles: [],
        ),
        // The sheet's own way out: a close X on Material.
        'a title, closed': (
          typedText: 'Item 5a',
          pressedFinder: find.byType(CloseButton),
          savedTitles: [],
        ),
      },
      outline: (tester, example) async {
        final savedTitles = <String>[];
        await tester.pumpWidget(const PlatformApp(home: Text('home')));

        unawaited(
          showTitleSheet(
            tester.element(find.text('home')),
            heading: 'Rename',
            hint: 'Item 2',
            onSaved: savedTitles.add,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300)); // the sheet opening
        await tester.enterText(find.byType(EditableText), example.typedText);
        await tester.tap(example.pressedFinder);
        await tester.pump();

        check(savedTitles).deepEquals(example.savedTitles);
      },
    );
  });
}
