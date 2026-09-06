import 'package:flutter/widgets.dart';

/// A trivial host so the app is runnable. The benchmark scenarios pump their own widget trees.
void main() => runApp(
  const Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: Text('list_smith benchmark host')),
  ),
);
