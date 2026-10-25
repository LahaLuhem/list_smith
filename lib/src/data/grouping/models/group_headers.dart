import 'package:meta/meta.dart';

import '/src/data/presentation/presentation.dart';
import '../typedefs/group_header_builder.dart';

/// One build's group headers, and how to draw them.
@internal
final class GroupHeaders({
  /// In list order.
  required final List<GroupHeader> headers,

  /// Whether each sits after its group's last item, as on a reversed list, rather than before its 1st.
  required final bool isAfterItem,

  /// Builds a group's header from its key.
  required final GroupHeaderBuilder<Object> headerFor,
}) {
  late final Map<Object, int> _indexByKey = headers.asMap().map(
    (index, header) => MapEntry(header.key, index),
  );

  /// Creates it.
  this;

  /// Where the header for [key] sits now, or null once its group has gone. [lastIndex] is where it
  /// was.
  int? indexOf(Object key, int lastIndex) =>
      lastIndex < headers.length && headers[lastIndex].key == key ? lastIndex : _indexByKey[key];
}
