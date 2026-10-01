import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show ThemeMode;

/// Lets any screen flip the app's brightness.
class const ThemeScope({required super.notifier, required super.child, super.key})
    extends InheritedNotifier<ValueNotifier<ThemeMode>> {
  static ValueNotifier<ThemeMode> of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    assert(scope?.notifier != null, 'No ThemeScope found in the widget tree.');

    return scope!.notifier!;
  }
}
