import 'package:flutter/widgets.dart';

/// Fallback foreground colour for list_smith's default surfaces. A mid-grey, legible on light and
/// dark alike, so a default surface never vanishes into the background.
const neutralForegroundColour = Color(0xFF9E9E9E);

/// The colour to paint list_smith's defaults with, for [context].
///
/// Prefers the ambient [DefaultTextStyle] colour, so defaults inherit the host app's text colour
/// without importing a design system. Falls back to [neutralForegroundColour].
Color neutralForegroundOf(BuildContext context) =>
    DefaultTextStyle.of(context).style.color ?? neutralForegroundColour;
