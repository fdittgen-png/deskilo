// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2870 — the places step's preview: what a member finds to book, level by
// level — a floor, a room or a table booked as a whole, then every seat,
// meeting room and parking slot, said with the booking list's own words.
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/floor_plan.dart';
import '../../domain/level.dart';
import '../../domain/seat.dart';

class SetupBookablePlaces extends StatelessWidget {
  const SetupBookablePlaces({super.key, required this.plans});

  /// Level → its plan; null while the plan loads.
  final Map<Level, FloorPlan?> plans;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final loaded = [
      for (final MapEntry(key: level, value: plan) in plans.entries)
        if (plan != null && _holdsAny(level, plan)) (level, plan),
    ];
    return Column(
      key: const ValueKey('setup-places-preview'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.setupPlacesPreviewTitle, style: theme.textTheme.labelLarge),
        if (loaded.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              l10n.setupPlacesPreviewNone,
              key: const ValueKey('setup-places-preview-none'),
            ),
          ),
        for (final (level, plan) in loaded) ...[
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Text(level.name, style: theme.textTheme.titleSmall),
          ),
          if (level.bookableAsWhole)
            _Whole(id: 'level-${level.id}', name: level.name),
          for (final office in plan.offices.where((o) => o.bookableAsWhole))
            _Whole(id: 'office-${office.id}', name: office.name),
          for (final desk in plan.desks.where((d) => d.bookableAsWhole))
            _Whole(id: 'desk-${desk.id}', name: desk.name),
          for (final seat in plan.seats)
            ListTile(
              key: ValueKey('setup-places-bookable-seat-${seat.id}'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(_icon(seat)),
              title: Text(seat.name),
              subtitle: switch (_kind(l10n, seat)) {
                final kind? => Text(kind),
                null => null,
              },
            ),
        ],
      ],
    );
  }

  static IconData _icon(Seat seat) => switch (seat.resourceKind) {
    ResourceKind.room => Icons.meeting_room_outlined,
    ResourceKind.parking =>
      seat.parkingKind == ParkingKind.ev
          ? Icons.ev_station_outlined
          : Icons.local_parking,
    ResourceKind.seat => Icons.event_seat_outlined,
  };

  /// What a room or a parking slot is, as the booking list says it; null
  /// for a plain seat.
  static String? _kind(AppLocalizations l10n, Seat seat) =>
      switch (seat.resourceKind) {
        ResourceKind.room => switch (seat.capacity) {
          final people? => l10n.reserveRoomFor(people),
          null => l10n.reserveMeetingRoom,
        },
        ResourceKind.parking => switch (seat.parkingKind) {
          ParkingKind.ev => l10n.reserveParkingEv,
          ParkingKind.accessible => l10n.reserveParkingAccessible,
          _ => l10n.reserveParkingStandard,
        },
        ResourceKind.seat => null,
      };

  static bool _holdsAny(Level level, FloorPlan plan) =>
      level.bookableAsWhole ||
      plan.seats.isNotEmpty ||
      plan.offices.any((o) => o.bookableAsWhole) ||
      plan.desks.any((d) => d.bookableAsWhole);
}

/// A floor, a room or a table a member books as one.
class _Whole extends StatelessWidget {
  const _Whole({required this.id, required this.name});

  final String id;
  final String name;

  @override
  Widget build(BuildContext context) => ListTile(
    key: ValueKey('setup-places-bookable-$id'),
    dense: true,
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.crop_square),
    title: Text(name),
    subtitle: Text(context.l10n.setupPlacesWholeSpace),
  );
}
