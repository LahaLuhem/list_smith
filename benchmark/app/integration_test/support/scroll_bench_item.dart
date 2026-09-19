import 'package:flutter/widgets.dart';

/// The list item shared by both scroll scenarios, so their per-frame build cost is measured over identical
/// widgets.
class ScrollBenchItem extends StatelessWidget {
  const new({required this.index, super.key});

  final int index;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 56,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        spacing: 12,
        children: [
          const ColoredBox(color: Color(0xFFBBBBBB), child: SizedBox(width: 40, height: 40)),
          Text('Item $index'),
        ],
      ),
    ),
  );
}
