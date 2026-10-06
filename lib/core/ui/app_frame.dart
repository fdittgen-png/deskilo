// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

/// The widest the app draws itself. On a desktop or tablet window every
/// screen sits in one centred column with calm margins instead of
/// stretching rows, tabs and cards across 1500 px; phones are untouched.
const double kAppFrameMaxWidth = 1200;

/// Reading screens (lists, forms, cards) are narrower still: a row that
/// spans 1200 px cannot be scanned. Canvas screens keep the wide frame.
const double kReadingColumnMaxWidth = 960;

/// Routes drawn on a canvas (map, editors): they want the width. The Reserve
/// hub is NOT one of them: it sits in the same column as the Calendar and
/// the Alerts, so moving between the destinations never changes the width.
const List<String> kWideRoutePrefixes = [
  '/discover', '/kiosk', '/report-editor', '/editor',
  '/settings/sites', '/me', '/invoicing/wizard',
];

/// A prefix names a path or its children — never a longer word that merely
/// starts with it (`/me` is Me, not `/messages` or `/members`).
bool _under(String path, String prefix) =>
    path == prefix || path.startsWith('$prefix/');

double frameWidthFor(String path) =>
    kWideRoutePrefixes.any((prefix) => _under(path, prefix))
        ? kAppFrameMaxWidth
        : kReadingColumnMaxWidth;

/// Whether a screen puts its controls in a side panel: only a PHONE held
/// sideways, where the height is what is scarce. A wide, tall window (a
/// desktop) stacks controls above the content like the portrait layout, in
/// the centred column — one arrangement a person learns once.
bool phoneLandscape(BoxConstraints c) =>
    c.maxWidth > c.maxHeight && c.maxHeight < 520;

class AppFrame extends StatelessWidget {
  const AppFrame({super.key, required this.child, this.maxWidth = kAppFrameMaxWidth});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (media.size.width <= maxWidth) return child;
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: Center(
        child: SizedBox(
          width: maxWidth,
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              border: Border.symmetric(
                vertical: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
            // Screens measure THIS column, not the window behind it.
            child: MediaQuery(
              data: media.copyWith(size: Size(maxWidth, media.size.height)),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
