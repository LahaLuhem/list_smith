import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// A 50 px row showing `off N` until a tap flips it to `on N`, so a kept state reads as `on N`.
class ToggleRow extends StatefulWidget {
  final int item;

  const new(this.item, {super.key});

  @override
  State<ToggleRow> createState() => _ToggleRowState();
}

class _ToggleRowState extends State<ToggleRow> {
  var _isOn = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => setState(() => _isOn = !_isOn),
    child: SizedBox(height: 50, child: Text('${_isOn ? 'on' : 'off'} ${widget.item}')),
  );
}

/// The [ToggleRow]s on screen, top to bottom.
List<String> shownToggleRows() => find
    .textContaining(RegExp('^(on|off) '))
    .evaluate()
    .map((element) => (element.widget as Text).data)
    .nonNulls
    .toList(growable: false);
