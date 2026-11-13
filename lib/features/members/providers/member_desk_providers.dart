// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3618 — the bookings the members' desk reads a last visit from: this
// month's and the last month's, so "none" is said with the day it counts
// from, never as "never".
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../reservations/domain/reservation.dart';
import '../../reservations/providers/reservation_providers.dart';

/// The bookings read for the last visits, and the first day they cover;
/// [reservations] is null while a month is not read (or failed).
typedef MembersVisits = ({DateTime since, List<Reservation>? reservations});

final membersVisitsProvider = Provider.autoDispose<MembersVisits>((ref) {
  final today = ref.watch(businessDateOfProvider)(
    ref.watch(clockProvider).now(),
  );
  final since = DateTime(today.year, today.month - 1);
  final months = [
    ref.watch(reservationsForMonthProvider(monthKeyOf(since))),
    ref.watch(reservationsForMonthProvider(monthKeyOf(today))),
  ];
  if (months.any((m) => !m.hasValue)) return (since: since, reservations: null);
  final seen = <String>{};
  return (
    since: since,
    reservations: [
      for (final m in months)
        for (final r in m.requireValue)
          if (seen.add(r.id)) r,
    ],
  );
});
