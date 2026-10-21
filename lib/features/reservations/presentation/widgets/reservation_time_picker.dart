// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/l10n/lexicon.dart';
import '../../../../core/time/workspace_time.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../plan/domain/half_day_windows.dart';
import '../../../workspace/domain/booking_granularity.dart';
import '../../domain/picked_time.dart';
import '../../domain/reservation.dart';

/// From/to clock pickers on the booking's device-local day, snapped to
/// the granularity's step — the same slot language as the hub's chips.
Future<HalfDayWindow?> pickReservationTimes(
  BuildContext context,
  AppLocalizations l10n,
  Reservation r,
  BookingGranularity granularity,
) async {
  final snap = granularity.stepMinutes ?? 15;
  final local = WorkspaceTime.wall(r.startsAt);
  final endLocal = WorkspaceTime.wall(r.endsAt);
  final from = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(local),
    helpText: lexiconText(context, key: 'planFromLabel', fallback: l10n.planFromLabel),
  );
  if (from == null || !context.mounted) return null;
  final to = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(endLocal),
    helpText: l10n.planToLabel,
  );
  if (to == null) return null;
  DateTime snapDown(int hour, int minute) {
    // #638 — the shared grid rule, not a private copy of it.
    // #1082 — and the result is a WORKSPACE instant. `local` is the
    // workspace wall clock of the reservation; rebuilding a bare
    // DateTime from it silently MOVED an existing booking by the
    // device's offset every time somebody edited its times.
    final m = granularity.snapMinutesOfDay(hour * 60 + minute);
    return pickedInstantAt(local, m ~/ 60, m % 60);
  }

  final start = snapDown(from.hour, from.minute);
  var end = snapDown(to.hour, to.minute);
  if (!end.isAfter(start)) end = start.add(Duration(minutes: snap));
  return (start: start, end: end);
}
