// SPDX-License-Identifier: 0BSD
// #1088 — the events.type constraint has been widened six times. A client
// that has not been updated yet must still read the rest of the feed: one
// wire word it does not know may cost that row its label, never the feed.
import 'package:deskilo/features/events/domain/notification_feed.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an unrecognised type reads as unknown instead of throwing', () {
    expect(EventType.fromDb('a_type_from_a_later_migration'),
        EventType.unknown);
    expect(EventType.fromDb('invoice_issue'), EventType.invoiceIssue);
  });

  test('an unrecognised action and status degrade the same way', () {
    expect(EventAction.fromDb('escalated'), EventAction.unknown);
    expect(EventAction.fromDb('approved'), EventAction.approved);
    expect(EventStatus.fromDb('superseded'), EventStatus.unknown);
    expect(EventStatus.fromDb('confirmed'), EventStatus.confirmed);
  });

  test('a feed carrying one unknown row keeps every known row', () {
    final rows = <String>[
      'reservation',
      'a_type_from_a_later_migration',
      'invoice_issue',
    ];
    final parsed = rows.map(EventType.fromDb).toList();
    expect(parsed, [
      EventType.reservation,
      EventType.unknown,
      EventType.invoiceIssue,
    ]);
  });

  test('an unknown event still lands in a category', () {
    final event = WorkspaceEvent(
      id: 'e1',
      workspaceId: 'w1',
      type: EventType.unknown,
      action: EventAction.unknown,
      actorMemberId: 'm1',
      subjectMemberId: 'm1',
      payload: const {},
      status: EventStatus.unknown,
      createdAt: DateTime.utc(2026, 9, 10),
    );
    expect(categoryOfEvent(event), isNotNull);
  });
}
