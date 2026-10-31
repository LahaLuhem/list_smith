import 'package:flutter/foundation.dart';

/// Tells the app about data list_smith works around, without stopping the list.
@internal
void reportBadData(String message) => FlutterError.reportError(
  FlutterErrorDetails(exception: FlutterError(message), library: 'list_smith'),
);
