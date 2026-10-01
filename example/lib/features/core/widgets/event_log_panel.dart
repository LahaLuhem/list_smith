import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show Divider;
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';

/// Plain widgets layer, like list_smith's own defaults, so it reads under either shell.
class const EventLogPanel({
  /// Newest first.
  required final ValueListenable<List<String>> events,
  required final VoidCallback onClear,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 184,
    child: Column(
      crossAxisAlignment: .stretch,
      children: [
        const Divider(height: 1),
        Padding(
          padding: const .fromLTRB(16, 4, 8, 0),
          child: Row(
            children: [
              const Expanded(
                child: Text('Event log', style: TextStyle(fontWeight: .w600)),
              ),
              PlatformButton(
                onPressed: onClear,
                materialButtonVariant: .text,
                child: const Text('Clear'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ValueListenableBuilder(
            valueListenable: events,
            builder: (context, events, _) => events.isEmpty
                ? const Center(child: Text('No events yet'))
                : ListView.builder(
                    padding: const .fromLTRB(16, 0, 16, 8),
                    itemCount: events.length,
                    itemBuilder: (_, index) => Padding(
                      padding: const .symmetric(vertical: 2),
                      child: Text(
                        events[index],
                        style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    ),
  );
}
