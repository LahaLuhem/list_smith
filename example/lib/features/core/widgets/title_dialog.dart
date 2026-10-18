import 'package:flutter/widgets.dart';
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';

/// Hands [onSaved] the title typed, trimmed, and nothing when it's cancelled or left blank.
Future<void> showTitleDialog(
  BuildContext context, {
  required String heading,
  required String hint,
  required ValueChanged<String> onSaved,
}) async {
  var typedTitle = '';
  final savedTitle = await showPlatformAlertDialog<String>(
    context: context,
    title: Text(heading),
    content: PlatformTextField(
      hintText: hint,
      autofocus: true,
      onChanged: (value) => typedTitle = value,
    ),
    actions: [
      PlatformDialogAction(
        onPressed: (context) => Navigator.maybeOf(context)?.pop(),
        child: const Text('Cancel'),
      ),
      PlatformDialogAction(
        isDefaultAction: true,
        onPressed: (context) => Navigator.maybeOf(context)?.pop(typedTitle.trim()),
        child: const Text('Save'),
      ),
    ],
  );
  if (savedTitle != null && savedTitle.isNotEmpty) onSaved(savedTitle);
}
