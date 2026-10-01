import 'package:flutter/widgets.dart';
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';

class const BoolKnob({
  required final String label,
  required final bool value,
  required final ValueChanged<bool> onChanged,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label)),
      PlatformSwitch(value: value, onChanged: onChanged),
    ],
  );
}
