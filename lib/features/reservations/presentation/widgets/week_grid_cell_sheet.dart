// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2494 — the occupants sheet of one Week grid cell, moved beside the grid
// by #3817 so the grid's files keep their size.
import 'package:flutter/material.dart';

import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../domain/reservation.dart';
import 'booking_range_text.dart';
import 'week_grid.dart';

/// The occupants of [seatName]'s cell on [day], sorted by start; the
/// reader's own row picked, or null.
Future<Reservation?> showWeekGridCellSheet(
  BuildContext context, {
  required String seatName,
  required DateTime day,
  required List<Reservation> items,
  required String? myMemberId,
  required Map<String, String>? names,
}) {
  final l10n = context.l10n;
  final format = appFormatOf(context);
  // "09:00 – 11:00 · Flo": the names only in Everyone mode ([names]).
  String lineOf(Reservation r) {
    final range = bookingRangeText(context, format, l10n, r.startsAt, r.endsAt);
    final name = names?[r.memberId] ?? '';
    return name.isEmpty ? range : '$range · $name';
  }

  final sorted = [...items]..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  final date = format.dates(DateShape.weekdayMonthDay);
  return showAppSheet<Reservation>(
    context: context,
    builder: (context) => _WeekGridCellSheet(
      title: '$seatName · ${date.format(day)}',
      items: sorted,
      myMemberId: myMemberId,
      lineOf: lineOf,
    ),
  );
}

/// Small occupants sheet of one seat/day cell: one line per reservation,
/// my own rows popping the tapped reservation for the hub's detail sheet.
class _WeekGridCellSheet extends StatelessWidget {
  const _WeekGridCellSheet({
    required this.title,
    required this.items,
    required this.myMemberId,
    required this.lineOf,
  });

  final String title;

  /// Sorted by start.
  final List<Reservation> items;
  final String? myMemberId;

  /// "09:00 – 11:00 · Flo" (names only in Everyone mode).
  final String Function(Reservation reservation) lineOf;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.xs,
              ),
              child: Text(title, style: Theme.of(context).textTheme.titleSmall),
            ),
            for (final r in items)
              ListTile(
                key: WeekGrid.sheetItemKey(r.id),
                leading: Icon(
                  r.memberId == myMemberId
                      ? Icons.event_seat
                      : Icons.person_outline,
                ),
                title: Text(lineOf(r)),
                trailing: r.memberId == myMemberId
                    ? const Icon(Icons.chevron_right)
                    : null,
                onTap: r.memberId == myMemberId
                    ? () => Navigator.of(context).pop(r)
                    : null,
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}
