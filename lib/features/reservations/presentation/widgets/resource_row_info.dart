// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../plan/domain/seat.dart';
import '../../domain/seat_state_logic.dart';

export '../../../plan/domain/seat.dart' show Seat;

/// #2631 — what a Reserve row says about a bookable resource beyond its
/// state: a meeting room, a parking slot (with the electric marker) or a
/// plain seat. Pure presentation helpers over the seat's kind.

/// The icon of a row: the block sign, a room, a parking slot (electric
/// ones with the charging station) or the seat the list always showed.
IconData seatRowIcon(Seat seat, SeatState state) {
  final free = state == SeatState.free;
  if (state == SeatState.blocked) return Icons.block;
  return switch (seat.resourceKind) {
    ResourceKind.room =>
      free ? Icons.meeting_room_outlined : Icons.meeting_room,
    ResourceKind.parking =>
      seat.parkingKind == ParkingKind.ev
          ? (free ? Icons.ev_station_outlined : Icons.ev_station)
          : Icons.local_parking,
    ResourceKind.seat => free ? Icons.event_seat_outlined : Icons.event_seat,
  };
}

/// The words a screen reader gets for the electric marker; null elsewhere.
String? seatRowSemantics(AppLocalizations l10n, Seat seat) =>
    seat.parkingKind == ParkingKind.ev ? l10n.reserveEvMarker : null;

/// The two lines under a row's title: where it is (when the seat's name is
/// the title) with what it is, then its state.
String seatRowSubtitle(
  AppLocalizations l10n,
  Seat seat, {
  required String place,
  required String stateText,
}) => [
  [
    if (seat.name.isNotEmpty) place,
    ?resourceLine(l10n, seat),
  ].where((s) => s.isNotEmpty).join(' · '),
  stateText,
].where((s) => s.isNotEmpty).join('\n');

/// The slot a resource is booked in, in words; null when it follows the
/// workspace (every plain seat).
String? _slotLine(AppLocalizations l10n, int? slotMinutes) =>
    switch (slotMinutes) {
      null => null,
      60 => l10n.reserveSlotHour,
      1440 => l10n.reserveSlotDay,
      final m => l10n.reserveSlotMinutes(m),
    };

/// The descriptive line of a room or a parking slot (kind, capacity, slot);
/// null for a plain seat that follows the workspace's slot.
String? resourceLine(AppLocalizations l10n, Seat seat) {
  final kind = switch (seat.resourceKind) {
    ResourceKind.room =>
      seat.capacity == null
          ? l10n.reserveMeetingRoom
          : l10n.reserveRoomFor(seat.capacity!),
    ResourceKind.parking => switch (seat.parkingKind) {
      ParkingKind.ev => l10n.reserveParkingEv,
      ParkingKind.accessible => l10n.reserveParkingAccessible,
      _ => l10n.reserveParkingStandard,
    },
    ResourceKind.seat => null,
  };
  final parts = [kind, _slotLine(l10n, seat.slotMinutes)].nonNulls;
  return parts.isEmpty ? null : parts.join(' · ');
}
