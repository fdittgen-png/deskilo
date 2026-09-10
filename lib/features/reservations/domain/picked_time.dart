// SPDX-License-Identifier: 0BSD
import '../../../core/time/workspace_time.dart';

/// #1082 — the instant a member MEANT when they picked [time] on [day].
///
/// Every booking surface used to build `DateTime(day.year, day.month,
/// day.day, t.hour, t.minute)`: a bare, device-local instant, assigned
/// to fields that hold workspace `TZDateTime`s and compared against
/// `HalfDayWindows` values that are workspace-anchored. Workspace in
/// Paris, phone in New York: pick 10:00, and the tile re-renders as
/// 16:00 and the booking is made at 16:00 Paris.
///
/// A picked time is a WALL-CLOCK time, and the only wall clock a booking
/// may use is the space's — the server's `enforce_booking_rules` checks
/// canonical windows in it.
/// `domain/` is pure Dart (no Flutter), so this takes the components a
/// `TimeOfDay` carries rather than the widget type itself.
DateTime pickedInstantAt(DateTime day, int hour, int minute) =>
    WorkspaceTime.at(day.year, day.month, day.day, hour, minute);

/// Minutes after midnight of [instant] ON THE WORKSPACE CLOCK.
///
/// The counterpart trap: reading `.hour`/`.minute` off a device-local
/// "now" and treating those numbers as the space's wall clock. At 09:00
/// in New York it is 15:00 in Paris, and a probe that mixes them judges
/// the wrong half of the day.
int workspaceWallMinutes(DateTime instant) =>
    WorkspaceTime.minutesOfDay(instant);
