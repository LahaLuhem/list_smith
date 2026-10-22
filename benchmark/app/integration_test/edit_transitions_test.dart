/// Scenario: frame cost while edits come and go, under each kind of edit transition.
///
/// Each variant cycles an upsert of a new item and its removal. `none` makes the same edits with no
/// transition, so the others read as what animating them adds. `size_scrolled` makes `size`'s edits
/// just above the screen, where the list holds the rows on it still on every frame.
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

// Off the start, but near enough that an edit there is built, inside the cache extent.
const _scrolledOffset = 112.0;

final _slideInTween = Tween(begin: const Offset(1, 0), end: Offset.zero);

final _sizeTransition = EditTransition(
  duration: _transitionDuration,
  transitionBuilder: (child, animation) => SizeTransition(sizeFactor: animation, child: child),
);

final _variants = <String, ({EditTransition editTransition, double scrollOffset})>{
  'none': (editTransition: const NoEditTransition(), scrollOffset: 0),
  'size': (editTransition: _sizeTransition, scrollOffset: 0),
  'fade': (
    editTransition: EditTransition(
      duration: _transitionDuration,
      transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
    ),
    scrollOffset: 0,
  ),
  'slide': (
    editTransition: EditTransition(
      duration: _transitionDuration,
      transitionBuilder: (child, animation) =>
          SlideTransition(position: _slideInTween.animate(animation), child: child),
    ),
    scrollOffset: 0,
  ),
  'size_scrolled': (editTransition: _sizeTransition, scrollOffset: _scrolledOffset),
};

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('edits coming and going under each edit transition', (tester) async {
    final records = <Map<String, dynamic>>[];

    for (final MapEntry(key: name, value: (:editTransition, :scrollOffset)) in _variants.entries) {
      final controller = ListSmithController<int>();
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
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
            scroll: ListScrollConfig(controller: scrollController),
            itemBuilder: (_, item, _) => ScrollBenchItem(index: item),
          ),
        ),
      );
      for (var i = 0; i < _warmupPumps; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      scrollController.jumpTo(scrollOffset);
      await tester.pump(const Duration(milliseconds: 16));

      final summary = await captureFrames(binding, () async {
        for (var cycle = 0; cycle < _iterations; cycle++) {
          final item = -1 - cycle;
          controller.upsert(item);
          await _pumpFrames(tester);
          controller.remove(item);
          await _pumpFrames(tester);
        }
      });
      records.add(
        buildFrameRecord(
          scenario: 'edit_transitions_$name',
          iterations: _iterations,
          summary: summary,
        ),
      );
    }

    binding.reportData = <String, dynamic>{'output_path': _outputPath, 'records': records};
  });
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var frame = 0; frame < _framesPerEdit; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}
