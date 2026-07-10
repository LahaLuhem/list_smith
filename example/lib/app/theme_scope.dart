import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show ThemeMode;

/// Exposes the app-wide [ThemeMode] notifier to descendants.
///
/// The root app owns the `ValueNotifier<ThemeMode>`, rebuilds `PlatformApp` when
/// it ticks, and publishes it here via the app's `builder`. Any screen reads it
/// with [ThemeScope.of] and writes a new mode to flip the whole app's brightness.
class ThemeScope extends InheritedNotifier<ValueNotifier<ThemeMode>> {
  const ThemeScope({required super.notifier, required super.child, super.key});

  /// The nearest theme-mode notifier. Asserts a [ThemeScope] is in scope.
  static ValueNotifier<ThemeMode> of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    assert(scope?.notifier != null, 'No ThemeScope found in the widget tree.');

    return scope!.notifier!;
  }
}
