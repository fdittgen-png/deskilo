// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1881 B — the calendar's choices, as the recorder words them. The
// screens call these with what they already hold; nothing here reads a
// member, an entry's id, a name or a date beyond its distance from today.
import '../../../core/calendar/calendar_item.dart';
import '../domain/action_registry.dart';

/// A kind-filter change: which chip moved and which way. "All" is its
/// own target; a change that moved nothing records nothing (null).
({String target, String switchTo})? calendarKindChange(
  Set<CalendarKind>? before,
  Set<CalendarKind>? after,
) {
  if (after == null) {
    return before == null ? null : (target: calendarAllKinds, switchTo: 'on');
  }
  final was = before ?? const <CalendarKind>{};
  for (final k in after.difference(was)) {
    return (target: k.wire, switchTo: 'on');
  }
  for (final k in was.difference(after)) {
    return (target: k.wire, switchTo: 'off');
  }
  return null;
}

/// The kind of entry a calendar row opens, or null when the destination
/// records its own step (a reservation's sheet does, wherever it opens).
String? calendarOpenedKind(CalendarItem item) => switch (item.link) {
  ReservationLink() || null => null,
  ConversationLink() => 'conversation',
  EventLink() => item.kind == CalendarKind.validation ? 'decision' : 'alert',
  LedgerLink() => 'payment',
  InvoiceLink() => 'invoice',
};

/// Which way a step through the dates went.
String calendarDirection(int delta) => delta < 0 ? 'previous' : 'next';
