import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith_example/features/core/widgets/title_dialog.dart';
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart' show PlatformApp;

import 'support/bdd.dart';

void main() {
  feature('Title dialog', () {
    scenarioOutlineWidgets<({String typedText, String pressedLabel, List<String> savedTitles})>(
      'it hands back the title typed, trimmed, and nothing when blank or cancelled',
      examples: {
        'a title with spaces around it, saved': (
          typedText: '  Item 5a  ',
          pressedLabel: 'Save',
          savedTitles: ['Item 5a'],
        ),
        'a blank title, saved': (typedText: '   ', pressedLabel: 'Save', savedTitles: []),
        'a title, cancelled': (typedText: 'Item 5a', pressedLabel: 'Cancel', savedTitles: []),
      },
      outline: (tester, example) async {
        final savedTitles = <String>[];
        await tester.pumpWidget(const PlatformApp(home: Text('home')));

        unawaited(
          showTitleDialog(
            tester.element(find.text('home')),
            heading: 'Rename',
            hint: 'Item 2',
            onSaved: savedTitles.add,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300)); // the dialog opening
        await tester.enterText(find.byType(EditableText), example.typedText);
        await tester.tap(find.text(example.pressedLabel));
        await tester.pump();

        check(savedTitles).deepEquals(example.savedTitles);
      },
    );
  });
}
