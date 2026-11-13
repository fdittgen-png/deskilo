// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3626 (desk M7) — what New booking at the desk reads of the workspace to
// build the booking sheet for a place: the booking rules, the gate, who may be
// booked for, and the window the clicked cell asks for.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/context_l10n.dart';
import '../../core/time/clock.dart';
import '../../core/time/work_hours.dart';
import '../../features/plan/domain/half_day_windows.dart';
import '../../features/reservations/domain/booking_error_text.dart';
import '../../features/reservations/domain/booking_gate.dart';
import '../../features/reservations/domain/default_booking_period.dart';
import '../../features/reservations/presentation/booking_gate_scope.dart';
import '../../features/reservations/presentation/screens/reserve_window_rules.dart';
import '../../features/reservations/presentation/widgets/booking_sheet.dart';
import '../../features/reservations/providers/default_period_controller.dart';
import '../../features/workspace/domain/booking_granularity.dart';
import '../../features/workspace/domain/member.dart';
import '../../features/workspace/domain/workspace_feature.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import 'desk_calendar.dart';

/// The workspace's rules for a booking made from the grid.
class DeskBookingForm {
  DeskBookingForm._({
    required this.workspaceId,
    required this.timezone,
    required this.myMemberId,
    required this.granularity,
    required this.gate,
    required this.now,
    required this.period,
    required this.members,
    required this.allowSeries,
    required this.day,
    required this.at,
  });

  final String workspaceId;
  final String timezone;
  final String? myMemberId;
  final BookingGranularity granularity;
  final BookingGate? gate;
  final DateTime now;
  final DefaultBookingPeriod? period;
  final List<({String id, String name})> members;
  final bool allowSeries;

  /// The cell's day, and the instant it named (a day grid) when it did.
  final DateTime day;
  final DateTime? at;

  /// The form for a cell on [day] (at [at]); null before the workspace and its
  /// booking rules are read: there is nothing to judge a window against.
  static DeskBookingForm? read(WidgetRef ref, DateTime day, DateTime? at) {
    final workspace = ref.read(currentWorkspaceProvider).value;
    final granularity = ref.read(bookingGranularityProvider).value;
    if (workspace == null || granularity == null) return null;
    final features = ref.read(enabledFeaturesSyncProvider);
    final names = ref.read(memberNamesProvider).value ?? const {}; // empty-ok: a missing name is blank, not invented
    final roster = ref.read(workspaceMembersProvider).value ?? const <Member>[]; // empty-ok: no roster, no "book for" choice
    final members =
        features.contains(WorkspaceFeature.bookForOthers) &&
            ref.read(actsForReservationsProvider)
        ? [
            for (final m in roster)
              if (m.status == MemberStatus.active)
                (id: m.id, name: names[m.id] ?? ''),
          ]
        : const <({String id, String name})>[];
    return DeskBookingForm._(
      workspaceId: workspace.id,
      timezone: workspace.timezone,
      myMemberId: ref.read(myMemberProvider).value?.id,
      granularity: granularity,
      gate: bookingGateOf(ref),
      now: ref.read(clockProvider).now(),
      period: ref.read(defaultPeriodProvider).value,
      members: members,
      allowSeries: features.contains(WorkspaceFeature.seriesBooking),
      day: day,
      at: at,
    );
  }

  /// The window [place] is booked in: the clicked instant on a minute grid,
  /// the canonical day period under a day-based granularity.
  HalfDayWindow windowOf(DeskPlace place) {
    final rules = ReserveWindowRules(granularity);
    final instant = at != null && !granularity.isDayBased ? at : null;
    final asked = rules.effectiveWindow(
      selectedDay: day,
      now: now,
      preferredPeriod: period,
      start: instant,
      end: instant == null ? null : rules.defaultEndFor(instant),
    );
    return rules.resourceWindow(
      place.seat?.slotMinutes,
      asked: asked,
      now: now,
      day: workDayWindow(day, hours: gate?.hours),
    );
  }

  /// The booking sheet for [place]; [cap] is when its next booking begins.
  Widget sheetOf(BuildContext context, DeskPlace place, DateTime? cap) {
    final booked = windowOf(place);
    final capped = cap != null && cap.isBefore(booked.end);
    final effective = BookingGranularity.forSlot(
      place.seat?.slotMinutes,
      granularity,
    );
    final gate = this.gate;
    return BookingSheet(
      key: ValueKey('${place.id}-${booked.start.microsecondsSinceEpoch}'),
      seatId: place.id,
      seatName: place.name,
      timezone: timezone,
      start: booked.start,
      initialEnd: capped ? cap : booked.end,
      cap: cap,
      capped: capped,
      granularity: effective,
      walkUp: false,
      fixedEnd: effective.isDayBased,
      members: members,
      myMemberId: myMemberId,
      allowSeries: allowSeries,
      now: now,
      refusalOf: gate == null
          ? null
          : (start, end, {required walkUp}) => gate.refusalFor(
              start: start,
              end: end,
              walkUp: walkUp,
              seat: place.seat,
            ),
      refusalTextOf: gate == null
          ? null
          : (refusal) => bookingRefusalText(
              context.l10n,
              refusal,
              policies: gate.policies,
              stepMinutes: effective.stepMinutes,
            ),
    );
  }
}
