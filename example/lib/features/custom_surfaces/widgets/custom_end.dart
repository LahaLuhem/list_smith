import 'package:flutter/widgets.dart';

class const CustomEnd({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Padding(
    padding: .all(16),
    child: Center(child: Text("That's everything")),
  );
}
