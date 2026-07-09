// SPDX-License-Identifier: MIT
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/money/domain/bill_sections.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:flutter_test/flutter_test.dart';

LedgerEntry entry({
  required String id,
  required LedgerKind kind,
  required LedgerCategory category,
  required int amountCents,
  String description = '',
  String period = '2026-07',
}) =>
    LedgerEntry(
      id: id,
      memberId: 'member-1',
      kind: kind,
      category: category,
      amountCents: amountCents,
      description: description,
      period: period,
      createdAt: DateTime(2026, 7, 5),
    );

WorkspaceEvent event({
  required String id,
  required EventType type,
  EventStatus status = EventStatus.pending,
  String subjectMemberId = 'member-1',
  Map<String, dynamic> payload = const {},
}) =>
    WorkspaceEvent(
      id: id,
      workspaceId: 'ws-1',
      type: type,
      action: EventAction.submitted,
      actorMemberId: subjectMemberId,
      subjectMemberId: subjectMemberId,
      payload: payload,
      status: status,
      createdAt: DateTime(2026, 7, 6),
    );

void main() {
  group('buildBillSections', () {
    test('groups service charges of the period and totals them', () {
      final sections = buildBillSections(
        period: '2026-07',
        memberId: 'member-1',
        nowPeriod: '2026-07',
        pendingEvents: const [],
        ledger: [
          entry(
            id: 'coffee',
            kind: LedgerKind.charge,
            category: LedgerCategory.service,
            amountCents: 300,
            description: 'Coffee x2',
          ),
          entry(
            id: 'printing',
            kind: LedgerKind.charge,
            category: LedgerCategory.service,
            amountCents: 80,
            description: 'Printing x4',
          ),
          // Other period — not on this bill.
          entry(
            id: 'june-coffee',
            kind: LedgerKind.charge,
            category: LedgerCategory.service,
            amountCents: 150,
            period: '2026-06',
          ),
          // Other category — belongs to the subscription block.
          entry(
            id: 'fee',
            kind: LedgerKind.charge,
            category: LedgerCategory.subscription,
            amountCents: 15000,
          ),
        ],
      );

      expect(
        [for (final e in sections.serviceEntries) e.id],
        ['coffee', 'printing'],
      );
      expect(sections.servicesTotalCents, 380);
    });

    test('open positions: service charges follow their payload period', () {
      final matching = event(
        id: 'sc-july',
        type: EventType.serviceCharge,
        payload: const {
          'name': 'Coffee',
          'quantity': 2,
          'amount_cents': 300,
          'period': '2026-07',
        },
      );
      final sections = buildBillSections(
        period: '2026-07',
        memberId: 'member-1',
        nowPeriod: '2026-08',
        ledger: const [],
        pendingEvents: [
          matching,
          event(
            id: 'sc-june',
            type: EventType.serviceCharge,
            payload: const {'amount_cents': 150, 'period': '2026-06'},
          ),
          // Already decided — no longer an open position.
          event(
            id: 'sc-confirmed',
            type: EventType.serviceCharge,
            status: EventStatus.confirmed,
            payload: const {'amount_cents': 150, 'period': '2026-07'},
          ),
          // Someone else's bill.
          event(
            id: 'sc-other',
            type: EventType.serviceCharge,
            subjectMemberId: 'member-2',
            payload: const {'amount_cents': 150, 'period': '2026-07'},
          ),
        ],
      );

      expect(sections.openPositions, hasLength(1));
      final position = sections.openPositions.single;
      expect(position.event.id, 'sc-july');
      expect(position.amountCents, 300);
      expect(position.isCredit, isFalse);
    });

    test(
        'open positions: pending payments and expenses only appear on the '
        'current period — they post to now() on confirmation', () {
      final pending = [
        event(
          id: 'pay',
          type: EventType.payment,
          payload: const {'amount_cents': 5000, 'note': 'transfer'},
        ),
        event(
          id: 'exp',
          type: EventType.expense,
          payload: const {'amount_cents': 1200, 'category': 'coffee'},
        ),
        // Reservations carry no money — never an open position.
        event(id: 'res', type: EventType.reservation),
      ];

      final current = buildBillSections(
        period: '2026-07',
        memberId: 'member-1',
        nowPeriod: '2026-07',
        ledger: const [],
        pendingEvents: pending,
      );
      expect(
        [for (final p in current.openPositions) p.event.id],
        ['pay', 'exp'],
      );
      expect(current.openPositions.first.isCredit, isTrue);
      expect(current.openPositions.first.amountCents, 5000);

      final past = buildBillSections(
        period: '2026-06',
        memberId: 'member-1',
        nowPeriod: '2026-07',
        ledger: const [],
        pendingEvents: pending,
      );
      expect(past.openPositions, isEmpty);
    });

    test('credits: confirmed payment/expense/adjustment credits of the '
        'period', () {
      final sections = buildBillSections(
        period: '2026-07',
        memberId: 'member-1',
        nowPeriod: '2026-07',
        pendingEvents: const [],
        ledger: [
          entry(
            id: 'payment',
            kind: LedgerKind.credit,
            category: LedgerCategory.payment,
            amountCents: 15000,
          ),
          entry(
            id: 'expense',
            kind: LedgerKind.credit,
            category: LedgerCategory.expense,
            amountCents: 1200,
          ),
          entry(
            id: 'adjustment',
            kind: LedgerKind.credit,
            category: LedgerCategory.adjustment,
            amountCents: 500,
          ),
          // Charges never land in the credits section, whatever category.
          entry(
            id: 'adjustment-charge',
            kind: LedgerKind.charge,
            category: LedgerCategory.adjustment,
            amountCents: 700,
          ),
          entry(
            id: 'service',
            kind: LedgerKind.charge,
            category: LedgerCategory.service,
            amountCents: 300,
          ),
          // Other period.
          entry(
            id: 'june-payment',
            kind: LedgerKind.credit,
            category: LedgerCategory.payment,
            amountCents: 9000,
            period: '2026-06',
          ),
        ],
      );

      expect(
        [for (final e in sections.creditEntries) e.id],
        ['payment', 'expense', 'adjustment'],
      );
      expect(
        [for (final e in sections.serviceEntries) e.id],
        ['service'],
      );
    });
  });
}
