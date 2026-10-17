import 'dart:math' as math;

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

/// The list's scroll view, not the neutral error's.
final listScrollableFinder = find.byType(Scrollable).first;

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

/// Pulls from [anchor] by [offset], down unless told otherwise, far enough to arm a refresh, then pumps
/// long enough for it to run.
Future<void> pullToRefresh(
  WidgetTester tester,
  Finder anchor, {
  Offset offset = const Offset(0, 300),
}) async {
  await tester.fling(anchor, offset, 1000);
  // Timed frames, since the indicator only moves as time passes.
  for (var frame = 0; frame < 10; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await drain(tester, frames: 16);
}

/// Jumps to the end until it stops growing, since the list only knows its end once rows are laid out.
Future<void> scrollToEnd(WidgetTester tester, ScrollController scrollController) async {
  double? lastMaxScrollExtent;
  for (var pass = 0; pass < 20; pass++) {
    final maxScrollExtent = scrollController.position.maxScrollExtent;
    if (maxScrollExtent == lastMaxScrollExtent) return;
    lastMaxScrollExtent = maxScrollExtent;
    scrollController.jumpTo(maxScrollExtent);
    await tester.idle();
    await drain(tester);
  }
}

/// What follows [prefix] in each row, top to bottom, once the list has reached its end.
Future<List<String>> allShownTexts(
  WidgetTester tester,
  ScrollController scrollController,
  String prefix,
) async {
  await scrollToEnd(tester, scrollController);
  scrollController.jumpTo(0);
  await tester.pump();
  final shownTexts = <String>{};
  while (true) {
    shownTexts.addAll(
      find
          .textContaining(RegExp('^$prefix'))
          .evaluate()
          .map((element) => (element.widget as Text).data!.replaceFirst(prefix, '')),
    );
    final position = scrollController.position;
    if (position.pixels >= position.maxScrollExtent) return shownTexts.toList(growable: false);
    scrollController.jumpTo(
      math.min(position.pixels + position.viewportDimension, position.maxScrollExtent),
    );
    await tester.pump();
  }
}
