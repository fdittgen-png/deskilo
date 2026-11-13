// SPDX-License-Identifier: AGPL-3.0-or-later
//
// One of the person's own bookings as `my_reservations_page_v1` answers it
// (split from my_reservations.dart): what it booked and the item itself,
// read strictly -- a missing or mistyped field is a shape error, and a
// status this build does not know leaves the booking out (#3884).
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:meta/meta.dart';

import 'reservation.dart';

/// What a reservation booked: one of the four plan objects.
enum MyReservationPlaceKind {
  seat('seat'),
  desk('desk'),
  office('office'),
  level('level'),

  /// #3548 -- a place kind this version does not know: the booking still
  /// shows, by its label.
  other('other');

  const MyReservationPlaceKind(this.wire);
  final String wire;

  static MyReservationPlaceKind fromWire(String wire, {required String context}) {
    for (final k in values) {
      if (k.wire == wire) return k;
    }
    return other;
  }
}

/// One of the person's own bookings, as the host that holds it answers.
@immutable
class MyReservationItem {
  const MyReservationItem({
    required this.id,
    required this.workspaceId,
    required this.workspaceName,
    required this.placeKind,
    required this.placeId,
    required this.placeLabel,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required this.checkedInAt,
    required this.checkedOutAt,
  });

  /// The item, or null when its status is one this build does not know
  /// (#3884): the id and the unknown value go into [left] and the page
  /// keeps its other bookings, rather than drawing it as a status it is not.
  static MyReservationItem? tryFromJson(
    Object? raw, {
    required String context,
    required Map<String, String> left,
  }) {
    final r = JsonReader.of(raw, context: context);
    final statusWire = r.string('status');
    final status = reservationStatusFromDb(statusWire);
    if (status == null) {
      left[r.string('id')] = 'reservation status $statusWire';
      return null;
    }
    return MyReservationItem(
      id: r.string('id'),
      workspaceId: r.string('workspace_id'),
      workspaceName: r.string('workspace_name'),
      placeKind: MyReservationPlaceKind.fromWire(r.string('place_kind'), context: context),
      // Null only for a booking whose place was deleted: the label then
      // carries the substitution snapshot.
      placeId: r.stringOrNull('place_id'),
      placeLabel: r.string('place_label'),
      startsAt: r.dateTime('starts_at').toUtc(),
      endsAt: r.dateTime('ends_at').toUtc(),
      status: status,
      checkedInAt: r.dateTimeOrNull('checked_in_at')?.toUtc(),
      checkedOutAt: r.dateTimeOrNull('checked_out_at')?.toUtc(),
    );
  }

  final String id;
  final String workspaceId;
  final String workspaceName;
  final MyReservationPlaceKind placeKind;
  final String? placeId;

  /// The place's name, or the substitution label of a deleted place; may
  /// be empty for an unnamed seat.
  final String placeLabel;
  final DateTime startsAt;
  final DateTime endsAt;
  final ReservationStatus status;
  final DateTime? checkedInAt;
  final DateTime? checkedOutAt;
}
