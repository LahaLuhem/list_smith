import 'package:flutter/widgets.dart';
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';

/// A labelled slider for the playground, showing the current [valueText] beside
/// the [label] and a [PlatformSlider] below.
class SliderKnob extends StatelessWidget {
  final String label;
  final String valueText;
  final double value;
  final double min;
  final double max;
  final int divisions;

  final ValueChanged<double> onChanged;

  const SliderKnob({
    required this.label,
    required this.valueText,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: .start,
    children: [
      Row(
        children: [
          Expanded(child: Text(label)),
          Text(valueText),
        ],
      ),
      PlatformSlider(value: value, min: min, max: max, divisions: divisions, onChanged: onChanged),
    ],
  );
}
