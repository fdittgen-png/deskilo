// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The place on screen as the sidebar shows it: "Purchases › Suppliers". The
// last part is the page's place, or the page's own name (#3789).
//
// #3619 — where the parts do not fit on one line, the page's name keeps its
// room and the parts before it give way: the middle ones first, down to the
// smallest a target may be, then the first. A shortened part keeps its whole
// name for a screen reader and as a tooltip, so it still says where it leads.
// The name of the page takes the room that is left, on two lines at most
// (#3893): it is never the part that is cut while one before it still shows
// whole. Every width is measured with the text painter, as the bar's own
// fit is (`crumbsWidth`).
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui/kit/kit_metrics.dart';
import 'shell_menu.dart';

/// The horizontal padding of a crumb's text button, both sides.
const double _crumbButtonPadding = 24;

/// The chevron between two crumbs: an icon's width.
const double _chevronWidth = 24;

/// How wide [crumb] is on one line, in its style, a button with its padding.
double _crumbWidth(
  BuildContext context,
  DeskCrumb crumb, {
  required bool last,
}) {
  final theme = Theme.of(context);
  final painter = TextPainter(
    text: TextSpan(
      text: crumb.label,
      style: last ? theme.textTheme.titleLarge : theme.textTheme.titleMedium,
    ),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final width = painter.width.ceilToDouble();
  painter.dispose();
  return width + (crumb.entry != null ? _crumbButtonPadding : 0);
}

/// How wide the crumbs are on one line: each part in its style, a crumb that
/// is a button with the padding of its button, a chevron between.
double crumbsWidth(BuildContext context, List<DeskCrumb> crumbs) {
  var width = 0.0;
  for (final (i, crumb) in crumbs.indexed) {
    width += _crumbWidth(context, crumb, last: i == crumbs.length - 1);
    if (i > 0) width += _chevronWidth;
  }
  return width;
}

/// The width each crumb gets in [room] when the crumbs of [natural] widths
/// do not fit: the last keeps its width while it can; the ones before it
/// shrink, the middle ones first, then the first, to [least] at most; what
/// is still missing comes off the last, which then wraps.
@visibleForTesting
List<double> crumbWidths(
  List<double> natural, {
  required double room,
  required double least,
}) {
  final widths = [...natural];
  if (widths.isEmpty) return widths;
  final chevrons = (widths.length - 1) * _chevronWidth;
  double over() => widths.fold(0.0, (a, b) => a + b) + chevrons - room;
  // The middle ones first, from the one nearest the page's name; then the
  // first.
  final order = [
    for (var i = widths.length - 2; i >= 1; i--) i,
    if (widths.length > 1) 0,
  ];
  for (final i in order) {
    final excess = over();
    if (excess <= 0) return widths;
    final floor = natural[i] < least ? natural[i] : least;
    final give = (widths[i] - floor).clamp(0.0, excess);
    widths[i] -= give;
  }
  final excess = over();
  if (excess > 0) {
    widths[widths.length - 1] = (widths.last - excess).clamp(
      least,
      widths.last,
    );
  }
  return widths;
}

/// The breadcrumb of the desk's top bar.
class DeskBreadcrumb extends StatelessWidget {
  const DeskBreadcrumb({
    super.key,
    required this.crumbs,
    required this.router,
    required this.wraps,
  });

  final List<DeskCrumb> crumbs;
  final GoRouter router;

  /// The page's name takes a second line (#3893).
  final bool wraps;

  /// One part: its name, a button to the entry's page, a tooltip when it is
  /// shortened so it still says where it leads.
  Widget _part(
    BuildContext context,
    DeskCrumb crumb, {
    required bool last,
    required bool shortened,
  }) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final text = Text(
      crumb.label,
      maxLines: last && wraps ? 2 : 1,
      overflow: TextOverflow.ellipsis,
      style: last ? null : theme.textTheme.titleMedium?.copyWith(color: muted),
    );
    final entry = crumb.entry;
    final shown = entry == null
        ? text
        : TextButton(
            key: ValueKey('desk-crumb-${entry.key}'),
            onPressed: entry.route == null
                ? entry.onTap
                : () => router.go(entry.route!),
            style: TextButton.styleFrom(
              foregroundColor: last ? theme.colorScheme.onSurface : muted,
              textStyle: last ? theme.textTheme.titleLarge : null,
            ),
            child: text,
          );
    return shortened ? Tooltip(message: crumb.label, child: shown) : shown;
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return LayoutBuilder(
      builder: (context, box) {
        final natural = [
          for (final (i, c) in crumbs.indexed)
            _crumbWidth(context, c, last: i == crumbs.length - 1),
        ];
        final widths = box.maxWidth.isFinite
            ? crumbWidths(
                natural,
                room: box.maxWidth,
                least: KitMetrics.minTarget,
              )
            : natural;
        return Row(
          key: const ValueKey('desk-breadcrumb'),
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, crumb) in crumbs.indexed) ...[
              if (i > 0) Icon(Icons.chevron_right, color: muted),
              if (i == crumbs.length - 1)
                // The page's name takes the room that is left.
                Flexible(
                  child: _part(
                    context,
                    crumb,
                    last: true,
                    shortened: widths[i] < natural[i],
                  ),
                )
              else if (widths[i] < natural[i])
                SizedBox(
                  width: widths[i],
                  child: _part(context, crumb, last: false, shortened: true),
                )
              else
                _part(context, crumb, last: false, shortened: false),
            ],
          ],
        );
      },
    );
  }
}
