// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The dashboard page kind: tiles on a grid whose column count comes from the
// width the grid really has (never from the window class, since a sidebar, a
// side pane or large text take part of the window), a figure tile, and a
// filter bar that stays in view while the grid scrolls, with a slot for the
// page's Export and Print actions.
import 'package:flutter/material.dart';

import '../../l10n/context_l10n.dart';
import '../../theme/app_spacing.dart';

/// The most columns a dashboard lays out, however wide it is.
const int _maxColumns = 4;

/// The space between two tiles, across and down.
const double dashboardGap = AppSpacing.sm;

/// The narrowest a figure tile is drawn.
// content-fit: a figure tile holds its two-line label and an amount with its currency
const double kpiTileMinWidth = 160;

/// The most of the window's height the filter bar takes before it scrolls
/// inside itself, so the grid below it always keeps room.
const double _filterBarMaxHeightShare = 0.4;

/// How many columns of at least [minTileWidth] fit across [width], with
/// [dashboardGap] between them: at least one, at most [maxColumns].
int dashboardColumns(
  double width, {
  required double minTileWidth,
  int maxColumns = _maxColumns,
}) {
  if (!width.isFinite) return 1;
  final fit = ((width + dashboardGap) / (minTileWidth + dashboardGap)).floor();
  return fit.clamp(1, maxColumns);
}

/// The width of a tile [cells] columns wide on a grid of [columns] across
/// [width]. Rounded down, so a row of tiles never adds up to more than the
/// row and wraps early.
double dashboardTileWidth(double width, int columns, int cells) =>
    ((width + dashboardGap) * cells.clamp(1, columns) / columns - dashboardGap)
        .floorToDouble();

/// A tile of a [DashboardGrid] that spans [span] columns where the grid has
/// that many; on fewer columns it takes the whole row.
class DashboardTile extends StatelessWidget {
  const DashboardTile({super.key, this.span = 1, required this.child});

  final int span;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// [children] in reading order on as many columns of at least
/// [minTileWidth] as the grid's own width holds (one to four). A
/// [DashboardTile] child may span more than one column.
class DashboardGrid extends StatelessWidget {
  const DashboardGrid({
    super.key,
    required this.minTileWidth,
    required this.children,
  });

  final double minTileWidth;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final columns = dashboardColumns(width, minTileWidth: minTileWidth);
      return Wrap(
        spacing: dashboardGap,
        runSpacing: dashboardGap,
        children: [
          for (final child in children)
            SizedBox(
              width: dashboardTileWidth(
                width,
                columns,
                child is DashboardTile ? child.span : 1,
              ),
              child: child,
            ),
        ],
      );
    },
  );
}

/// Which way a figure moved since the period it is compared with.
enum KpiTrendDirection {
  up,
  down,
  flat;

  /// The direction of a signed [change]; null when the change is unknown.
  static KpiTrendDirection? of(num? change) => switch (change) {
    null => null,
    > 0 => up,
    < 0 => down,
    _ => flat,
  };
}

/// The direction of a trend as an arrow, said in words to a screen reader:
/// the sign never rests on a colour alone.
class KpiTrendMark extends StatelessWidget {
  const KpiTrendMark(this.direction, {super.key});

  final KpiTrendDirection direction;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (icon, word) = switch (direction) {
      KpiTrendDirection.up => (Icons.arrow_upward, l10n.dashboardTrendUp),
      KpiTrendDirection.down => (Icons.arrow_downward, l10n.dashboardTrendDown),
      KpiTrendDirection.flat => (Icons.arrow_forward, l10n.dashboardTrendFlat),
    };
    final theme = Theme.of(context);
    return Semantics(
      label: word,
      excludeSemantics: true,
      child: Icon(
        icon,
        size: theme.textTheme.bodyMedium?.fontSize,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// One figure: its [label], the [figure] itself, one line of [note] (the
/// period it covers), and the [trend] with its worded [trendChange]. A tap
/// runs [onTap].
class KpiTile extends StatelessWidget {
  const KpiTile({
    super.key,
    required this.label,
    required this.figure,
    this.note,
    this.trend,
    this.trendChange,
    this.onTap,
    this.figureKey,
    this.tapKey,
  });

  final String label;
  final String figure;
  final String? note;
  final KpiTrendDirection? trend;
  final String? trendChange;
  final VoidCallback? onTap;
  final Key? figureKey;
  final Key? tapKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final direction = trend;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        key: tapKey,
        onTap: onTap,
        child: Padding(
          padding: AppSpacing.smAll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(figure, key: figureKey, style: text.titleLarge),
              if (note case final note?)
                Text(
                  note,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelSmall,
                ),
              if (direction != null)
                Row(
                  children: [
                    KpiTrendMark(direction),
                    const SizedBox(width: AppSpacing.xs),
                    if (trendChange case final change?)
                      Flexible(child: Text(change, style: text.labelSmall)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The page's filters in one band that stays in view while the grid
/// scrolls ([DashboardScrollView] pins it). [filters] wrap onto more lines
/// when their content needs it; past a share of the window's height the
/// band scrolls inside itself. [actions] is the slot for Export and Print.
class FilterBar extends StatelessWidget {
  const FilterBar({super.key, required this.filters, this.actions = const []});

  final Widget filters;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final height = MediaQuery.sizeOf(context).height;
    return Material(
      color: scheme.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: height * _filterBarMaxHeightShare,
          ),
          child: SingleChildScrollView(
            primary: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: filters),
                if (actions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: actions,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A dashboard page's scrolling body: [header] scrolls away, [filterBar]
/// stays pinned at the top once it reaches it, and [children] (headings and
/// grids) scroll below it within [padding].
class DashboardScrollView extends StatelessWidget {
  const DashboardScrollView({
    super.key,
    this.header = const [],
    this.filterBar,
    required this.children,
    this.padding = EdgeInsets.zero,
  });

  final List<Widget> header;
  final Widget? filterBar;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      SliverList.list(children: header),
      if (filterBar case final bar?) PinnedHeaderSliver(child: bar),
      SliverPadding(
        padding: padding,
        sliver: SliverList.list(children: children),
      ),
    ],
  );
}
