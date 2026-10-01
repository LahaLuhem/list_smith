import 'package:flutter/widgets.dart';

class CustomEnd extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: .all(16),
    child: Center(child: Text("That's everything")),
  );
}
