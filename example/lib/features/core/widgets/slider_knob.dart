import 'package:flutter/widgets.dart';
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';

import 'knob_label.dart';

class const SliderKnob({
  required final String label,
  required final String valueText,
  required final double value,
  required final double min,
  required final double max,
  required final int divisions,
  required final ValueChanged<double> onChanged,
  final String? subtitle,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: .start,
    children: [
      Row(
        children: [
          Expanded(
            child: KnobLabel(label: label, subtitle: subtitle),
          ),
          Text(valueText),
        ],
      ),
      PlatformSlider(value: value, min: min, max: max, divisions: divisions, onChanged: onChanged),
    ],
  );
}
