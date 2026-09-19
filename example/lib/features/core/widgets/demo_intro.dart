import 'package:flutter/widgets.dart';

/// The heading and blurb at the top of a demo, where its user-facing explanation lives.
class DemoIntro extends StatelessWidget {
  final String title;
  final String description;

  const new({required this.title, required this.description, super.key});

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
