import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps [child] under the minimal ancestors a widget test needs. Pumping the same widget type again
/// exercises `didUpdateWidget`.
Future<void> pumpListSmith(WidgetTester tester, Widget child) => tester.pumpWidget(
  Directionality(
    textDirection: .ltr,
    child: MediaQuery(data: const MediaQueryData(), child: child),
  ),
);

/// Pumps [frames] fixed frames so the 1st fetch, its result, and any page it triggers all settle. Never
/// `pumpAndSettle`, for the reason in CODESTYLE's test style.
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

/// Pulls down from [anchor] far enough to arm a refresh, then pumps long enough for it to run.
Future<void> pullToRefresh(WidgetTester tester, Finder anchor) async {
  await tester.fling(anchor, const Offset(0, 300), 1000);
  // Timed frames, since the indicator only moves as time passes.
  for (var frame = 0; frame < 10; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await drain(tester, frames: 16);
}
