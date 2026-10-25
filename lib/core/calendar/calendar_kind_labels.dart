// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2495 — how a calendar kind reads and looks. The kind is core's
// (calendar_item.dart); its name and icon are said here, beside it, so
// the task recorder names a calendar filter without importing the
// calendar feature.
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'calendar_item.dart';

IconData calendarKindIcon(CalendarKind kind) => switch (kind) {
  CalendarKind.reservation => Icons.event_seat_outlined,
  CalendarKind.checkIn => Icons.login_outlined,
  CalendarKind.checkOut => Icons.logout_outlined,
  CalendarKind.event => Icons.notifications_outlined,
  CalendarKind.message => Icons.forum_outlined,
  CalendarKind.invoice => Icons.receipt_long_outlined,
  CalendarKind.payment => Icons.payments_outlined,
  CalendarKind.consumption => Icons.local_cafe_outlined,
  CalendarKind.reminder => Icons.alarm_outlined,
  CalendarKind.due => Icons.event_available_outlined,
  CalendarKind.validation => Icons.how_to_reg_outlined,
  CalendarKind.scheduled => Icons.event_repeat_outlined,
  CalendarKind.lease => Icons.vpn_key_outlined,
};

String calendarKindLabel(AppLocalizations l10n, CalendarKind kind) =>
    switch (kind) {
      CalendarKind.reservation => l10n.calendarKindReservation,
      CalendarKind.checkIn => l10n.calendarKindCheckIn,
      CalendarKind.checkOut => l10n.calendarKindCheckOut,
      CalendarKind.event => l10n.calendarKindEvent,
      CalendarKind.message => l10n.calendarKindMessage,
      CalendarKind.invoice => l10n.calendarKindInvoice,
      CalendarKind.payment => l10n.calendarKindPayment,
      CalendarKind.consumption => l10n.calendarKindConsumption,
      CalendarKind.reminder => l10n.calendarKindReminder,
      CalendarKind.due => l10n.calendarKindDue,
      CalendarKind.scheduled => l10n.calendarKindScheduled,
      CalendarKind.lease => l10n.calendarKindLease,
      CalendarKind.validation => l10n.calendarKindValidation,
    };
