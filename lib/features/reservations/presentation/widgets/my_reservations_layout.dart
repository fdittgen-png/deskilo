// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2553 C4 -- how My reservations lays its rows out: the #2551 card
// (radius 20 with the decorative border, padding 24 expanded and 16
// compact) and, on a wide window, a table: date and time, workspace, kind,
// status, actions. Each row keeps its times on its workspace's wall clock.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/personal_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/my_reservations.dart';
import '../../domain/my_reservations_composition.dart';
import '../../domain/reservation.dart';

/// A content width from which a card takes the expanded padding.
const double _expandedMinWidth = 600;

/// #2553 C4 -- how My reservations lays its rows out at a content width: a
/// card with the #2551 compact or expanded padding, or, from a medium
/// window's width on, one table row per booking.
enum MyReservationsLayout {
  compact,
  expanded,
  table;

  static MyReservationsLayout of(double width) {
    if (width >= PersonalShellMetrics.railMinWidth) return table;
    return width >= _expandedMinWidth ? expanded : compact;
  }

  /// The card's padding: 16 compact, 24 expanded.
  EdgeInsets get cardPadding =>
      this == compact ? AppSpacing.lgAll : AppSpacing.xlAll;
}

/// #2553 C4 -- the #2551 card of My reservations: radius 20 and the
/// decorative border, the padding of [layout]. Guest visits wear it too.
ShapeBorder myReservationsCardShape(BuildContext context) =>
    RoundedRectangleBorder(
      borderRadius: PersonalShellMetrics.cardRadiusAll,
      side: BorderSide(color: PersonalTheme.of(context).decorativeBorder),
    );

/// #2553 C4 -- the five columns of the wide table, as wide as
/// [MyReservationsTableHeader]'s: date and time, workspace, kind, status,
/// actions.
const List<int> _columnFlex = [3, 3, 2, 2, 4];

/// The titles of the wide table's columns.
class MyReservationsTableHeader extends StatelessWidget {
  const MyReservationsTableHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = Theme.of(context).textTheme.labelLarge;
    final titles = [
      l10n.myReservationsColumnWhen,
      l10n.myReservationsColumnWorkspace,
      l10n.myReservationsColumnKind,
      l10n.myReservationsColumnStatus,
      l10n.myReservationsColumnActions,
    ];
    return Semantics(
      header: true,
      child: Padding(
        key: const ValueKey('my-reservations-table-header'),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            for (final (i, title) in titles.indexed)
              Expanded(
                flex: _columnFlex[i],
                child: Text(title, style: style),
              ),
          ],
        ),
      ),
    );
  }
}

/// One booking as a row of the wide table; its times on its workspace's
/// wall clock, the zone named when it is not the device's.
class MyReservationTableRow extends ConsumerWidget {
  const MyReservationTableRow({
    super.key,
    required this.entry,
    required this.actions,
    required this.banner,
  });

  final MyReservationEntry entry;
  final Widget actions;
  final Widget? banner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final format = ref.watch(appFormatProvider);
    final theme = Theme.of(context);
    final item = entry.item;
    final zone = entry.foreignZone;
    final label = item.placeLabel.isEmpty
        ? l10n.myReservationsUnnamedPlace
        : item.placeLabel;
    String at(DateTime instant) => format.wallTime(entry.wall(instant));
    Widget cell(int i, Widget child) =>
        Expanded(flex: _columnFlex[i], child: child);
    final banner = this.banner;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: PersonalTheme.of(context).decorativeBorder),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                cell(
                  0,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${myReservationDay(format, entry.day)} · ${at(item.startsAt)}–${at(item.endsAt)}',
                        key: ValueKey('my-reservation-times-${item.id}'),
                        style: theme.textTheme.bodyLarge,
                      ),
                      if (zone != null)
                        Text(
                          l10n.myReservationsTimesIn(zone),
                          key: ValueKey('my-reservation-zone-${item.id}'),
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                cell(
                  1,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.workspaceName,
                        style: theme.textTheme.bodyLarge,
                      ),
                      Text(label, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                cell(
                  2,
                  Row(
                    children: [
                      Icon(myReservationKindIcon(item.placeKind)),
                      const SizedBox(width: AppSpacing.xs),
                      Flexible(
                        child: Text(
                          myReservationKindWords(l10n, item.placeKind),
                        ),
                      ),
                    ],
                  ),
                ),
                cell(
                  3,
                  Text(
                    myReservationStatusWords(l10n, item.status),
                    key: ValueKey('my-reservation-status-${item.id}'),
                    style: theme.textTheme.labelLarge,
                  ),
                ),
                cell(4, actions),
              ],
            ),
            ?banner,
          ],
        ),
      ),
    );
  }
}

/// A day of the workspace's calendar, already a wall date: formatted as
/// it is, never shifted by another zone.
String myReservationDay(AppFormat format, DateTime day) =>
    DateFormat.MMMEd(format.locale).format(day);

/// The icon of what a booking holds (#2554 C2 reuses it on the Overview).
IconData myReservationKindIcon(MyReservationPlaceKind kind) => switch (kind) {
  MyReservationPlaceKind.seat => Icons.chair_outlined,
  MyReservationPlaceKind.desk => Icons.desk_outlined,
  MyReservationPlaceKind.office => Icons.meeting_room_outlined,
  MyReservationPlaceKind.level => Icons.layers_outlined,
};

/// What a booking holds, in words.
String myReservationKindWords(
  AppLocalizations l10n,
  MyReservationPlaceKind kind,
) => switch (kind) {
  MyReservationPlaceKind.seat => l10n.myReservationsKindSeat,
  MyReservationPlaceKind.desk => l10n.myReservationsKindDesk,
  MyReservationPlaceKind.office => l10n.myReservationsKindOffice,
  MyReservationPlaceKind.level => l10n.myReservationsKindLevel,
};

/// Where a booking stands, in words.
String myReservationStatusWords(
  AppLocalizations l10n,
  ReservationStatus status,
) => switch (status) {
  ReservationStatus.reserved => l10n.myReservationsStatusReserved,
  ReservationStatus.checkedIn => l10n.myReservationsStatusCheckedIn,
  ReservationStatus.completed => l10n.myReservationsStatusCompleted,
  ReservationStatus.cancelled => l10n.myReservationsStatusCancelled,
  ReservationStatus.released => l10n.myReservationsStatusReleased,
};
