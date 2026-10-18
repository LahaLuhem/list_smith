import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith_example/main.dart';

/// Room for a demo's controls above its list.
const tallSurfaceSize = Size(800, 1200);

Future<void> pumpExampleApp(WidgetTester tester) async {
  await tester.pumpWidget(const ListSmithExampleApp());
  await tester.pump();
}

/// Taps the hub's [title] demo open, leaving its first load for the caller to wait out.
Future<void> openDemo(WidgetTester tester, String title, {Size? surfaceSize}) async {
  if (surfaceSize != null) {
    await tester.binding.setSurfaceSize(surfaceSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }
  await pumpExampleApp(tester);

  await tester.scrollUntilVisible(find.text(title), 100);
  await tester.tap(find.text(title));
  await tester.pump();
}

/// Pumps [frames] frames, [step] apart when given.
Future<void> drain(WidgetTester tester, {int frames = 5, Duration? step}) async {
  for (var frame = 0; frame < frames; frame++) {
    await tester.pump(step);
  }
}
