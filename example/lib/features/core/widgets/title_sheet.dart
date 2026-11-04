import 'package:flutter/widgets.dart';
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';

/// Hands [onSaved] the title typed, trimmed, and nothing when it's closed or left blank.
Future<void> showTitleSheet(
  BuildContext context, {
  required String heading,
  required String hint,
  required ValueChanged<String> onSaved,
}) async {
  var typedTitle = '';
  final savedTitle = await showPlatformSheet<String>(
    context: context,
    appBarBuilder: (context) => PlatformAppBar(
      title: Text(heading),
      primaryAction: PlatformBarAction(
        label: 'Save',
        onPressed: () => Navigator.maybeOf(context)?.pop(typedTitle.trim()),
      ),
    ),
    // The body doesn't scroll, so iOS would otherwise draw it under the bar.
    useSafeArea: true,
    builder: (_) => Padding(
      padding: const .all(16),
      child: PlatformTextField(
        hintText: hint,
        autofocus: true,
        onChanged: (value) => typedTitle = value,
      ),
    ),
  );
  if (savedTitle != null && savedTitle.isNotEmpty) onSaved(savedTitle);
}
