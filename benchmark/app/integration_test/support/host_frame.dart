import 'package:flutter/widgets.dart';

/// A minimal frame giving a pumped list a [Directionality], a [MediaQuery], and bounded constraints,
/// so a scenario can host a `ListSmith` without a full app shell.
class HostFrame extends StatelessWidget {
  const HostFrame({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(size: Size(400, 800)),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 400, height: 800, child: child),
      ),
    ),
  );
}
