import 'package:flutter/widgets.dart';

/// A short heading + blurb at the top of a demo, explaining what the screen
/// exercises. Colours inherit the ambient `DefaultTextStyle`, so it reads
/// correctly under both the Material and Cupertino shells in light and dark.
class DemoIntro extends StatelessWidget {
  final String title;
  final String description;

  const DemoIntro({required this.title, required this.description, super.key});

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
