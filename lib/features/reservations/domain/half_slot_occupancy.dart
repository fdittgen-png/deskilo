// SPDX-License-Identifier: AGPL-3.0-or-later
import 'reservation.dart';

/// Who holds one half-slot of a seat's day in the Week grid (#236).
enum HalfSlotHolder {
  /// No reservation holds any part of the half.
  none,

  /// A reservation of the reader's own holds it.
  mine,

  /// Only other members' reservations hold it.
  others,
}

/// What one half-slot ([start]..[end]) of a seat's day shows, given the
/// seat's [reservations] that day: any held reservation overlapping the half
/// occupies it, one of [myMemberId]'s wins over everyone else's, and the
/// first overlapping reservation in [reservations] order is the [covering]
/// one whose occupant the cell names.
({HalfSlotHolder holder, Reservation? covering}) halfSlotOccupancy(
  Iterable<Reservation> reservations, {
  required DateTime start,
  required DateTime end,
  required String? myMemberId,
}) {
  Reservation? covering;
  var mine = false;
  for (final r in reservations) {
    if (!r.holdsRange(start, end)) continue;
    covering ??= r;
    if (r.memberId == myMemberId) {
      mine = true;
      break;
    }
  }
  final holder = covering == null
      ? HalfSlotHolder.none
      : mine
      ? HalfSlotHolder.mine
      : HalfSlotHolder.others;
  return (holder: holder, covering: covering);
}
