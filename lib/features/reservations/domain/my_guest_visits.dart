// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2553 C4 -- a person's guest visits in My reservations: their own kind
// beside the bookings, read through the visits' current producer
// (`my_guest_participations` on the personal home), never placed in a
// workspace host's slot. A visit needs no membership. Which tab a visit
// belongs to and which ones a period shows. Pure Dart.
import 'package:meta/meta.dart';

import '../../visits/domain/guest_participation.dart';
import 'my_reservations.dart';
import 'my_reservations_composition.dart';

/// The tab [visit] belongs to at [now]: asked for or accepted and not yet
/// ended is upcoming, a cancelled one is cancelled; a declined, expired,
/// ended or unknown one is past. A request is shown as a request, never as
/// a confirmation.
@visibleForTesting
MyReservationsTab myVisitTab(GuestParticipation visit, DateTime now) =>
    switch (visit.status) {
      GuestVisitStatus.cancelled => MyReservationsTab.cancelled,
      GuestVisitStatus.requested || GuestVisitStatus.confirmed
          when visit.endsAt.isAfter(now) =>
        MyReservationsTab.upcoming,
      _ => MyReservationsTab.past,
    };

/// The visits of [visits] that [tab] shows in the period `[from, to)`, in
/// the tab's order (the past newest first), ties by id.
List<GuestParticipation> myVisitsShown(
  List<GuestParticipation> visits, {
  required MyReservationsTab tab,
  required DateTime from,
  required DateTime to,
  required DateTime now,
}) {
  final shown = [
    for (final v in visits)
      if (myVisitTab(v, now) == tab &&
          v.startsAt.isBefore(to) &&
          v.endsAt.isAfter(from))
        v,
  ];
  final ascending = tab.direction == MyReservationsDirection.ascending;
  shown.sort((a, b) {
    final byStart = a.startsAt.compareTo(b.startsAt);
    final order = byStart != 0 ? byStart : a.id.compareTo(b.id);
    return ascending ? order : -order;
  });
  return List.unmodifiable(shown);
}
