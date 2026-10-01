import 'package:flutter/widgets.dart';

/// [Directionality], [MediaQuery] and bounded constraints, so a scenario can host a `ListSmith` without
/// a full app shell.
class const HostFrame({required final Widget child, super.key}) extends StatelessWidget {
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
