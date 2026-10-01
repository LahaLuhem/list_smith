import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show ThemeMode;

/// Lets any screen flip the app's brightness.
class ThemeScope extends InheritedNotifier<ValueNotifier<ThemeMode>> {
  const new({required super.notifier, required super.child, super.key});

  static ValueNotifier<ThemeMode> of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    assert(scope?.notifier != null, 'No ThemeScope found in the widget tree.');

    return scope!.notifier!;
  }
}
