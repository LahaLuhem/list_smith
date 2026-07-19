import 'package:flutter/widgets.dart';
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';

/// A labelled boolean control for a demo's knobs, backed by a [PlatformSwitch].
class BoolKnob extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const BoolKnob({required this.label, required this.value, required this.onChanged, super.key});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label)),
      PlatformSwitch(value: value, onChanged: onChanged),
    ],
  );
}
