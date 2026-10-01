import 'package:flutter/widgets.dart';

/// The heading and blurb at the top of a demo, where its user-facing explanation lives.
class const DemoIntro({required final String title, required final String description, super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: .start,
    spacing: 4,
    children: [
      Text(title, style: const TextStyle(fontSize: 20, fontWeight: .w600)),
      Text(description),
    ],
  );
}
