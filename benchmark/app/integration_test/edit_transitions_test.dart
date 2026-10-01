/// Scenario: frame cost while edits come and go, under each kind of edit transition.
///
/// Each variant cycles an upsert of a new item and its removal. `none` makes the same edits with no
/// transition, so the other 3 read as what animating them adds.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:list_smith/list_smith.dart';

import 'support/frame_scenario.dart';
import 'support/host_frame.dart';
import 'support/scroll_bench_item.dart';

const _iterations = int.fromEnvironment('ITERATIONS', defaultValue: 10);
const _outputPath = String.fromEnvironment('OUTPUT');

const _itemCount = 30;
const _transitionDuration = Duration(milliseconds: 300);

// Frames pumped after each edit, enough for its transition to finish.
const _framesPerEdit = 25;

// Fixed pumps settle the page, so every variant warms up over the same frames.
const _warmupPumps = 10;

final _slideIn = Tween(begin: const Offset(1, 0), end: Offset.zero);

final _variants = <String, EditTransition>{
  'none': const NoEditTransition(),
  'size': EditTransition(
    duration: _transitionDuration,
    transitionBuilder: (child, animation) => SizeTransition(sizeFactor: animation, child: child),
  ),
  'fade': EditTransition(
    duration: _transitionDuration,
    transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
  ),
  'slide': EditTransition(
    duration: _transitionDuration,
    transitionBuilder: (child, animation) =>
        SlideTransition(position: _slideIn.animate(animation), child: child),
  ),
};

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('edits coming and going under each edit transition', (tester) async {
    final records = <Map<String, dynamic>>[];

    for (final MapEntry(key: name, value: editTransition) in _variants.entries) {
      final controller = ListSmithController<int>();
      await tester.pumpWidget(
        HostFrame(
          key: ValueKey(name),
          child: ListSmith<int>.async(
            fetchPage: PageFetcher(
              (request) async => request.pageIndex == 0
                  ? List<int>.generate(_itemCount, (index) => index)
                  : const <int>[],
            ),
            itemIdGetter: (item) => item,
            refresh: const NoRefresh(),
            editTransition: editTransition,
            controller: controller,
            itemBuilder: (_, item, _) => ScrollBenchItem(index: item),
          ),
        ),
      );
      for (var i = 0; i < _warmupPumps; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      final summary = await captureFrames(binding, () async {
        for (var cycle = 0; cycle < _iterations; cycle++) {
          final item = -1 - cycle;
          controller.upsert(item);
          await _pumpFrames(tester);
          controller.remove(item);
          await _pumpFrames(tester);
        }
      });
      records.add(buildFrameRecord(scenario: 'edit_transitions_$name', summary: summary));
    }

    binding.reportData = <String, dynamic>{'output_path': _outputPath, 'records': records};
  });
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var frame = 0; frame < _framesPerEdit; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}
