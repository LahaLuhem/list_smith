import 'package:flutter/widgets.dart';

/// A platform-neutral end-of-list footer, shown once every page has loaded.
class CustomEnd extends StatelessWidget {
  const CustomEnd({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: .all(16),
    child: Center(child: Text("That's everything")),
  );
}
