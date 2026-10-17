import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

/// Fallback foreground colour for the default surfaces. A mid-grey that reads on light and dark alike.
const _neutralForegroundColour = Color(0xFF9E9E9E);

/// The colour to paint the default surfaces with, for [context].
///
/// Takes the ambient [DefaultTextStyle] colour, so defaults pick up the host app's text colour without
/// pulling in a design system. Falls back to [_neutralForegroundColour].
@internal
Color neutralForegroundOf(BuildContext context) =>
    DefaultTextStyle.of(context).style.color ?? _neutralForegroundColour;
