import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart' show DesignLanguage;

import '../../test/support/support.dart';

late final String _framesPath;
late final Duration _frameStepDuration;

/// Each look's width in a clip, in pixels.
const _lookWidth = 440;

/// Fails outside render_clips.sh, then loads real fonts, since a test otherwise draws boxes.
Future<void> setUpClips() async {
  final framesPath = Platform.environment['CLIP_FRAMES'];
  final frameMillis = int.tryParse(Platform.environment['CLIP_FRAME_MILLIS'] ?? '');
  if (framesPath == null || frameMillis == null) {
    throw StateError('Run the clips through example/tool/render_clips.sh.');
  }
  _framesPath = framesPath;
  _frameStepDuration = Duration(milliseconds: frameMillis);

  // The platforms' own text fonts: Roboto from the SDK, and SF Pro, which only macOS has.
  final materialFontsPath =
      '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts';
  final sfProByteData = _readFont('/System/Library/Fonts/SFNS.ttf');
  // The app's bundled fonts, its icons among them.
  final fontFamilies = (jsonDecode(
    await rootBundle.loadString('FontManifest.json'),
  ) as List<Object?>).cast<Map<String, Object?>>();

  await [
    _loadFont(
      'Roboto',
      [
        'Regular',
        'Medium',
        'Bold',
      ].map((weight) => _readFont('$materialFontsPath/Roboto-$weight.ttf')),
    ),
    _loadFont('CupertinoSystemText', [sfProByteData]),
    _loadFont('CupertinoSystemDisplay', [sfProByteData]),
    ...fontFamilies.map(
      (family) => _loadFont(
        family['family']! as String,
        (family['fonts']! as List<Object?>).cast<Map<String, Object?>>().map(
          (font) => rootBundle.load(font['asset']! as String),
        ),
      ),
    ),
  ].wait;
}

Future<ByteData> _readFont(String path) => File(path).readAsBytes().then(ByteData.sublistView);

Future<void> _loadFont(String family, Iterable<Future<ByteData>> fonts) {
  final fontLoader = FontLoader(family);
  fonts.forEach(fontLoader.addFont);

  return fontLoader.load();
}

/// Films [storyboard] once per look, as numbered frames in `CLIP_FRAMES/<docFolder>/<name>/<look>/`.
void clip(
  String name, {
  required String docFolder,
  required AsyncValueSetter<ClipDriver> storyboard,
}) {
  for (final designLanguage in DesignLanguage.values) {
    testWidgets('$name, ${designLanguage.name}', (tester) async {
      debugDefaultTargetPlatformOverride = switch (designLanguage) {
        .material => .android,
        .cupertino => .iOS,
      };
      // Real shadows, which a test otherwise draws as solid outlines.
      debugDisableShadows = false;
      tester.view
        ..physicalSize = const Size(1170, 2532)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final framesDirectory = Directory('$_framesPath/$docFolder/$name/${designLanguage.name}')
        ..createSync(recursive: true);

      try {
        await storyboard(ClipDriver._(tester, framesDirectory));
      } finally {
        debugDefaultTargetPlatformOverride = null;
        debugDisableShadows = true;
      }
    });
  }
}

/// Plays a demo like a person would, saving a frame every frame step.
final class ClipDriver._(final WidgetTester _tester, final Directory _framesDirectory) {
  var _frameIndex = 0;

  /// Opens [demo] from the hub off camera, then waits [settle] there, like for its 1st page.
  Future<void> open(String demo, {Duration settle = Duration.zero}) async {
    await openDemo(_tester, demo, overlay: const _TouchDots());
    await _tester.pump(const Duration(milliseconds: 500) + settle); // the route coming in
  }

  Future<void> hold(Duration duration) async {
    for (var elapsed = Duration.zero; elapsed < duration; elapsed += _frameStepDuration) {
      await _frame();
    }
  }

  Future<void> tap(Finder finder) async {
    final gesture = await _tester.startGesture(_tester.getCenter(finder));
    await hold(const Duration(milliseconds: 130)); // long enough to see the touch
    await gesture.up();
    await _frame();
  }

  Future<void> drag(Finder finder, Offset offset, Duration duration) async {
    final stepCount = duration.inMicroseconds ~/ _frameStepDuration.inMicroseconds;
    final gesture = await _tester.startGesture(_tester.getCenter(finder));

    for (var step = 0; step < stepCount; step++) {
      await gesture.moveBy(offset / stepCount.toDouble());
      await _frame();
    }
    await gesture.up();
    await _frame();
  }

  /// Types [text] a letter at a time.
  Future<void> type(Finder finder, String text) async {
    final typedTextBuffer = StringBuffer();
    for (final letter in text.characters) {
      typedTextBuffer.write(letter);
      await _tester.enterText(finder, typedTextBuffer.toString());
      await hold(_frameStepDuration * 2);
    }
  }

  Future<void> clear(Finder finder) async {
    await _tester.enterText(finder, '');
    await _frame();
  }

  Future<void> _frame() async {
    await _tester.pump(_frameStepDuration);

    final physicalSize = _tester.view.physicalSize;
    final layer = _tester.binding.renderViews.single.debugLayer! as OffsetLayer;
    final pngByteData = await _tester.runAsync(() async {
      final image = await layer.toImage(
        Offset.zero & physicalSize,
        pixelRatio: _lookWidth / physicalSize.width,
      );
      try {
        return (await image.toByteData(format: .png))!;
      } finally {
        image.dispose();
      }
    });
    final frameName = (_frameIndex++).toString().padLeft(4, '0');
    File('${_framesDirectory.path}/$frameName.png')
        .writeAsBytesSync(pngByteData!.buffer.asUint8List());
  }
}

/// A dot under each finger, like Android's "Show taps", which never sees a test's touches.
class const _TouchDots() extends StatefulWidget {
  @override
  State<_TouchDots> createState() => _TouchDotsState();
}

class _TouchDotsState() extends State<_TouchDots> {
  final _touchPositionsNotifier = ValueNotifier<Map<int, Offset>>(const {});

  @override
  void initState() {
    super.initState();

    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointerEvent);
  }

  @override
  void dispose() {
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointerEvent);
    _touchPositionsNotifier.dispose();

    super.dispose();
  }

  void _onPointerEvent(PointerEvent event) {
    final touchPositions = {..._touchPositionsNotifier.value};
    if (event is PointerDownEvent || event is PointerMoveEvent) {
      touchPositions[event.pointer] = event.position;
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      touchPositions.remove(event.pointer);
    } else {
      return;
    }
    _touchPositionsNotifier.value = touchPositions;
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ValueListenableBuilder(
      valueListenable: _touchPositionsNotifier,
      builder: (_, touchPositions, _) =>
          CustomPaint(painter: _TouchDotsPainter(touchPositions.values), size: Size.infinite),
    ),
  );
}

class const _TouchDotsPainter(final Iterable<Offset> _touchPositions) extends CustomPainter {
  static const _radius = 18.0;
  static final _fillPaint = Paint()..color = const Color(0x66000000);
  static final _ringPaint = Paint()
    ..color = const Color(0xCCFFFFFF)
    ..style = .stroke
    ..strokeWidth = 2;

  @override
  void paint(Canvas canvas, Size size) {
    for (final position in _touchPositions) {
      canvas
        ..drawCircle(position, _radius, _fillPaint)
        ..drawCircle(position, _radius, _ringPaint);
    }
  }

  @override
  bool shouldRepaint(_TouchDotsPainter oldDelegate) => true;
}
