import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../utils/neutral_theme.dart';

/// A neutral, widgets-layer progress spinner for list_smith's loading surfaces.
///
/// The widgets layer ships no progress indicator (that lives in Material), so
/// this hand-rolls one: an arc drawn with a [CustomPainter] and rotated with a
/// [RotationTransition]. It imposes no design system and inherits the ambient
/// foreground colour via [neutralForegroundOf], so it drops into any app
/// unchanged.
class NeutralProgressIndicator extends StatefulWidget {
  /// The diameter of the spinner, in logical pixels.
  final double size;

  /// Creates a neutral spinner [size] logical pixels across.
  const NeutralProgressIndicator({this.size = 24, super.key});

  @override
  State<NeutralProgressIndicator> createState() => _NeutralProgressIndicatorState();
}

class _NeutralProgressIndicatorState extends State<NeutralProgressIndicator>
    with SingleTickerProviderStateMixin {
  static const _rotationPeriod = Duration(milliseconds: 900);

  late final _controller = AnimationController(vsync: this, duration: _rotationPeriod)..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(
    turns: _controller,
    child: SizedBox.square(
      dimension: widget.size,
      child: CustomPaint(painter: _ArcPainter(colour: neutralForegroundOf(context))),
    ),
  );
}

class _ArcPainter extends CustomPainter {
  static const double _strokeFraction = 1 / 10;
  static const double _sweepFraction = 3 / 4;

  static const _startAngle = -math.pi / 2;
  static const _sweepAngle = _sweepFraction * 2 * math.pi;

  final Color colour;

  const _ArcPainter({required this.colour});

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.shortestSide * _strokeFraction;
    final arcRect = (Offset.zero & size).deflate(strokeWidth / 2);

    final arcPaint = Paint()
      ..color = colour
      ..style = .stroke
      ..strokeCap = .round
      ..strokeWidth = strokeWidth;

    canvas.drawArc(arcRect, _startAngle, _sweepAngle, false, arcPaint);
  }

  @override
  bool shouldRepaint(_ArcPainter oldDelegate) => oldDelegate.colour != colour;
}
