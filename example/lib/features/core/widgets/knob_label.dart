import 'package:flutter/widgets.dart';

/// A knob's name, with what it does underneath, so the explanation sits where it's used.
class const KnobLabel({required final String label, final String? subtitle, super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    final bodyStyle = DefaultTextStyle.of(context).style;

    return Column(
      crossAxisAlignment: .start,
      children: [
        Text(label),
        if (subtitle != null)
          Text(
            subtitle,
            style: TextStyle(fontSize: 13, color: bodyStyle.color?.withValues(alpha: 0.7)),
          ),
      ],
    );
  }
}
