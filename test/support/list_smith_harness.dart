import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps [child] wrapped in the minimal ancestors a widget test needs, a [Directionality] and a [MediaQuery].
/// Call it again with the same widget type to drive a rebuild that exercises `didUpdateWidget`.
Future<void> pumpListSmith(WidgetTester tester, Widget child) => tester.pumpWidget(
  Directionality(
    textDirection: .ltr,
    child: MediaQuery(data: const MediaQueryData(), child: child),
  ),
);

/// Pumps [frames] fixed frames so the 1st fetch, its result, and any page it triggers all settle. Never
/// `pumpAndSettle`: list_smith's neutral spinner animates forever, so the tree never quiesces.
Future<void> drain(WidgetTester tester, {int frames = 5}) async {
  for (var frame = 0; frame < frames; frame++) {
    await tester.pump();
  }
}

/// Advances past a search [debounce] so a committed query takes effect, then [drain]s the fetch it triggers.
Future<void> settle(
  WidgetTester tester, {
  Duration debounce = const Duration(milliseconds: 20),
}) async {
  await tester.pump(debounce);

  await drain(tester);
}
