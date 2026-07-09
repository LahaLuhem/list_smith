import 'package:flutter/widgets.dart';

/// Fallback neutral foreground colour for list_smith's default surfaces, used when the ambient
/// text style carries no colour of its own.
///
/// A mid-grey chosen to stay legible on both light and dark backgrounds, so a default surface never
/// disappears into the app's background.
const neutralForegroundColour = Color(0xFF9E9E9E);

/// Resolves the neutral foreground colour to paint list_smith's defaults with, for the given [context].
///
/// Prefers the ambient [DefaultTextStyle] colour so our defaults inherit the host app's own text colour
/// (Material, Cupertino, or bespoke) without importing a design system;
/// falls back to [neutralForegroundColour] when the ambient style declares no colour.
Color neutralForegroundOf(BuildContext context) =>
    DefaultTextStyle.of(context).style.color ?? neutralForegroundColour;
