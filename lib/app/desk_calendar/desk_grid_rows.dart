// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3626 (desk M7) — the rows both places-down grids share: which rows the
// places make (with a header where the level changes), the place's name cell
// and the row itself.
import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import 'desk_calendar.dart';
import 'desk_metrics.dart';

/// One line of a places-down grid: a level's header or a place.
class DeskGridEntry {
  const DeskGridEntry.header(String this.header) : place = null;
  const DeskGridEntry.place(DeskPlace this.place) : header = null;

  final String? header;
  final DeskPlace? place;

  double get height => place == null
      ? DeskCalendarMetrics.levelHeader
      : DeskCalendarMetrics.rowHeight;
}

/// The entries of [rows]: with more than one level among them each group
/// starts with its level's name from [levelNames].
List<DeskGridEntry> deskGridEntries(
  List<DeskPlace> rows,
  Map<String, String> levelNames,
) {
  final levels = {for (final r in rows) r.levelId};
  final headers = levels.length > 1;
  final out = <DeskGridEntry>[];
  String? current;
  for (final place in rows) {
    if (headers && place.levelId != current) {
      current = place.levelId;
      out.add(DeskGridEntry.header(levelNames[current] ?? ''));
    }
    out.add(DeskGridEntry.place(place));
  }
  return out;
}

/// The key of the row of place [id].
@visibleForTesting
Key deskRowKey(String id) => ValueKey('desk-row-$id');

/// A row of a places-down grid: the guards measure it as a table row (the
/// mouse hits its regions at 36, a keyboard reaches every one).
class DeskGridRow extends StatelessWidget {
  const DeskGridRow({
    required this.placeId,
    required this.width,
    required this.child,
    super.key,
  });

  final String placeId;
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: deskRowKey(placeId),
    width: width,
    height: DeskCalendarMetrics.rowHeight,
    child: child,
  );
}

/// The name of a place, in the column at a grid's start.
class DeskPlaceName extends StatelessWidget {
  const DeskPlaceName(this.entry, {super.key});

  final DeskGridEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final header = entry.header;
    return SizedBox(
      width: DeskCalendarMetrics.placeColumn,
      height: entry.height,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text(
            header ?? entry.place!.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: header == null
                ? theme.textTheme.bodyMedium
                : theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
          ),
        ),
      ),
    );
  }
}
