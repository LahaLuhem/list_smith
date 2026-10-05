import 'package:flutter/widgets.dart';
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';

import 'knob_label.dart';

class const BoolKnob({
  required final String label,
  required final bool value,
  required final ValueChanged<bool> onChanged,
  final String? subtitle,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: KnobLabel(label: label, subtitle: subtitle),
      ),
      PlatformSwitch(value: value, onChanged: onChanged),
    ],
  );
}
