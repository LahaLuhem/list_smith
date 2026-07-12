import 'dart:io';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _flingDistancePixels = -500.0;
const _flingVelocity = 3000.0;
const _framesPerFling = 40;
const _refreshPullPixels = 360.0;
const _refreshPullSteps = 12;
const _refreshStepPixels = _refreshPullPixels / _refreshPullSteps; // 30 px/step, past touch slop.
const _refreshSettleFrames = 60;
const _frameBudgetMicros = 16667; // 60 Hz frame budget.
const _flushDelay = Duration(seconds: 2);

/// Flings [scrollable] down [passes] times, pumping fixed frames after each (never `pumpAndSettle`:
/// list_smith's loading indicator animates forever). Shared by the scroll scenarios so list_smith and
/// the bare-`ListView` control are scrolled identically.
Future<void> flingThrough(
  WidgetTester tester, {
  required Finder scrollable,
  required int passes,
}) async {
  for (var pass = 0; pass < passes; pass++) {
    await tester.fling(scrollable, const Offset(0, _flingDistancePixels), _flingVelocity);
    for (var frame = 0; frame < _framesPerFling; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }
}

/// Drives [passes] full pull-to-refresh cycles on [scrollable]: a stepped overscroll drag past CRI's
/// arm threshold, release, then a fixed settle window while onRefresh runs and the indicator settles
/// back (never `pumpAndSettle`: list_smith's loading indicator animates forever). The drag is stepped
/// over several pumps so the drag/arm/settle animation renders real intermediate frames, not one jump.
/// Each pass starts at the leading edge (the list sits at the top; a downward pull only overscrolls),
/// which is what CRI's default `onEdge` trigger needs to arm.
Future<void> refreshThrough(
  WidgetTester tester, {
  required Finder scrollable,
  required int passes,
}) async {
  for (var pass = 0; pass < passes; pass++) {
    final gesture = await tester.startGesture(tester.getCenter(scrollable));
    for (var step = 0; step < _refreshPullSteps; step++) {
      await gesture.moveBy(const Offset(0, _refreshStepPixels));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    for (var frame = 0; frame < _refreshSettleFrames; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }
}

/// Collects [FrameTiming]s across [action] and summarises them, WITHOUT touching the VM service.
///
/// `binding.watchPerformance` is the SDK's built-in, but its GC-info step opens a localhost socket
/// the sandboxed macOS app is denied ("Operation not permitted"), so this hand-rolls the collection:
/// register a timings callback, bracket [action] with fixed flush delays (the engine batches frame
/// timings roughly once a second), then summarise. Produces the same keys as
/// `FrameTimingSummarizer.summary` (minus GC counts), so [buildFrameRecord] reads it unchanged.
Future<Map<String, dynamic>> captureFrames(
  WidgetsBinding binding,
  Future<void> Function() action,
) async {
  final timings = <FrameTiming>[];
  void collector(List<FrameTiming> batch) => timings.addAll(batch);

  await Future<void>.delayed(_flushDelay);
  binding.addTimingsCallback(collector);
  await action();
  await Future<void>.delayed(_flushDelay);
  binding.removeTimingsCallback(collector);

  return _summariseFrames(timings);
}

Map<String, dynamic> _summariseFrames(List<FrameTiming> timings) {
  final buildMicros = timings.map((t) => t.buildDuration.inMicroseconds).toList(growable: false);
  final rasterMicros = timings.map((t) => t.rasterDuration.inMicroseconds).toList(growable: false);

  return <String, dynamic>{
    'frame_count': timings.length,
    'frame_build_times': buildMicros,
    'frame_rasterizer_times': rasterMicros,
    'average_frame_build_time_millis': _avgMillis(buildMicros),
    'worst_frame_build_time_millis': _maxMillis(buildMicros),
    '99th_percentile_frame_build_time_millis': _percentileMillis(buildMicros, 99),
    'missed_frame_build_budget_count': _missedCount(buildMicros),
    'average_frame_rasterizer_time_millis': _avgMillis(rasterMicros),
    'worst_frame_rasterizer_time_millis': _maxMillis(rasterMicros),
    '99th_percentile_frame_rasterizer_time_millis': _percentileMillis(rasterMicros, 99),
    'missed_frame_rasterizer_budget_count': _missedCount(rasterMicros),
  };
}

double _avgMillis(List<int> micros) {
  if (micros.isEmpty) return 0;

  return micros.reduce((a, b) => a + b) / micros.length / 1000.0;
}

double _maxMillis(List<int> micros) {
  if (micros.isEmpty) return 0;

  return micros.reduce((a, b) => a > b ? a : b) / 1000.0;
}

double _percentileMillis(List<int> micros, int percentile) {
  if (micros.isEmpty) return 0;

  final sorted = [...micros]..sort();
  final index = ((percentile / 100) * (sorted.length - 1)).round().clamp(0, sorted.length - 1);

  return sorted[index] / 1000.0;
}

int _missedCount(List<int> micros) => micros.where((m) => m > _frameBudgetMicros).length;

/// Maps a frame summary (the [captureFrames] output, matching `FrameTimingSummarizer.summary`) into a
/// unified benchmark record: the raw per-frame build/raster times (microseconds) become samples, the
/// aggregate build/raster stats (milliseconds) become summary scalars.
Map<String, dynamic> buildFrameRecord({
  required String scenario,
  required Map<String, dynamic> summary,
}) {
  final buildMicros = (summary['frame_build_times'] as List).cast<int>();
  final rasterMicros = (summary['frame_rasterizer_times'] as List).cast<int>();

  return <String, dynamic>{
    'scenario': scenario,
    'iteration': 0,
    'sdk_version': Platform.version.split(' ').first,
    'package_version': const String.fromEnvironment('PKG_VERSION', defaultValue: 'unknown'),
    'git_sha': const String.fromEnvironment('GIT_SHA', defaultValue: 'unknown'),
    'started_at': DateTime.now().toUtc().toIso8601String(),
    'samples': <String, List<num>>{
      'frame_build_micros': buildMicros,
      'frame_raster_micros': rasterMicros,
    },
    'summary': <String, num>{
      'avg_frame_build_millis': summary['average_frame_build_time_millis'] as num,
      'worst_frame_build_millis': summary['worst_frame_build_time_millis'] as num,
      'p99_frame_build_millis': summary['99th_percentile_frame_build_time_millis'] as num,
      'missed_frame_build_count': summary['missed_frame_build_budget_count'] as num,
      'avg_frame_raster_millis': summary['average_frame_rasterizer_time_millis'] as num,
      'worst_frame_raster_millis': summary['worst_frame_rasterizer_time_millis'] as num,
      'missed_frame_raster_count': summary['missed_frame_rasterizer_budget_count'] as num,
      'frame_count': summary['frame_count'] as num,
    },
  };
}
