// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2494 — the Open tab's decisions, as a table: where an open invoice
// stands, which actions it offers, the figure beside them, the due
// dunning level and the journey card's secondary actions.
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/money/application/open_invoice_rows.dart';
import 'package:deskilo/features/money/domain/dunning.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_clock.dart';

Invoice _invoice({String id = 'inv-1', int totalCents = 25000}) => Invoice(
  id: id,
  workspaceId: 'ws-1',
  memberId: 'member-1',
  number: 'INV-$id',
  issuedAt: kTestNow.subtract(const Duration(days: 60)),
  period: kTestPeriod,
  title: kTestPeriod,
  lines: const [],
  totalCents: totalCents,
  currency: 'EUR',
  memberName: 'Flo',
  memberAddress: '',
  workspaceName: 'Space',
  workspaceAddress: '',
  issuerName: 'Owner',
  signature: 'sig',
);

InvoiceMatch _match({int paidCents = 10000, String status = 'confirmed'}) =>
    InvoiceMatch(
      invoiceId: 'inv-1',
      paidCents: paidCents,
      resolution: 'partial',
      status: status,
      matchedAt: kTestNow,
    );

OpenInvoiceFacts _entry({int totalCents = 25000, InvoiceMatch? match}) =>
    (invoice: _invoice(totalCents: totalCents), pendingMatch: match);

List<OpenInvoiceAct> _acts(List<OpenInvoiceActChoice> choices) => [
  for (final c in choices) c.act,
];

List<OpenInvoiceAct> _tonal(List<OpenInvoiceActChoice> choices) => [
  for (final c in choices)
    if (c.tonal) c.act,
];

void main() {
  group('the classic row', () {
    final cases =
        <
          ({
            String name,
            OpenInvoiceFacts entry,
            bool writeoffPending,
            OpenInvoiceStanding standing,
            List<OpenInvoiceAct> acts,
            List<OpenInvoiceAct> tonal,
            int? figure,
          })
        >[
          (
            name: 'open, nothing matched',
            entry: _entry(),
            writeoffPending: false,
            standing: OpenInvoiceStanding.open,
            acts: const [
              OpenInvoiceAct.voidInvoice,
              OpenInvoiceAct.proforma,
              OpenInvoiceAct.remind,
              OpenInvoiceAct.match,
            ],
            tonal: const [OpenInvoiceAct.match],
            figure: null,
          ),
          (
            name: 'credit note: void or refund what the workspace owes',
            entry: _entry(totalCents: -4000),
            writeoffPending: false,
            standing: OpenInvoiceStanding.creditNote,
            acts: const [OpenInvoiceAct.voidInvoice, OpenInvoiceAct.refund],
            tonal: const [OpenInvoiceAct.refund],
            figure: 4000,
          ),
          (
            name: 'standing partial: remind, match, write off the remainder',
            entry: _entry(match: _match()),
            writeoffPending: false,
            standing: OpenInvoiceStanding.partiallyPaid,
            acts: const [
              OpenInvoiceAct.remind,
              OpenInvoiceAct.match,
              OpenInvoiceAct.writeoff,
            ],
            tonal: const [OpenInvoiceAct.match, OpenInvoiceAct.writeoff],
            figure: 15000,
          ),
          (
            name: 'standing partial with a filed write-off: the chip',
            entry: _entry(match: _match()),
            writeoffPending: true,
            standing: OpenInvoiceStanding.partiallyPaid,
            acts: const [
              OpenInvoiceAct.remind,
              OpenInvoiceAct.match,
              OpenInvoiceAct.writeoffPending,
            ],
            tonal: const [OpenInvoiceAct.match],
            figure: 15000,
          ),
          (
            name: 'a match waiting for its validation: the chip only',
            entry: _entry(match: _match(status: 'pending')),
            writeoffPending: false,
            standing: OpenInvoiceStanding.matchPending,
            acts: const [OpenInvoiceAct.matchPending],
            tonal: const [],
            figure: null,
          ),
          (
            name: 'a matched credit note is a partial, not a refund',
            entry: _entry(totalCents: -4000, match: _match(paidCents: -1000)),
            writeoffPending: false,
            standing: OpenInvoiceStanding.partiallyPaid,
            acts: const [
              OpenInvoiceAct.remind,
              OpenInvoiceAct.match,
              OpenInvoiceAct.writeoff,
            ],
            tonal: const [OpenInvoiceAct.match, OpenInvoiceAct.writeoff],
            figure: -3000,
          ),
        ];
    for (final c in cases) {
      test(c.name, () {
        final row = OpenInvoiceRows.of(
          [c.entry],
          dueLevels: const {'inv-1': 2},
          pendingWriteoffs: c.writeoffPending ? const {'inv-1'} : const {},
        ).single;
        expect(row.standing, c.standing);
        expect(_acts(row.acts), c.acts);
        expect(_tonal(row.acts), c.tonal);
        expect(row.figureCents, c.figure);
        expect(row.dueLevel, 2);
        expect(row.reminderDue, isTrue);
      });
    }
  });

  group('the due dunning level', () {
    const rules = DunningRules();
    final reminders = <String, ({int count, DateTime last})>{};

    test('dunning off: nothing is due', () {
      expect(
        OpenInvoiceRows.dueLevels(
          [_entry()],
          dunningOn: false,
          reminders: reminders,
          rules: rules,
          now: kTestNow,
        ),
        isEmpty,
      );
    });

    test('dunning on: every positive invoice is measured, a credit note '
        'never', () {
      final levels = OpenInvoiceRows.dueLevels(
        [
          _entry(),
          (invoice: _invoice(id: 'cn', totalCents: -1), pendingMatch: null),
        ],
        dunningOn: true,
        reminders: reminders,
        rules: rules,
        now: kTestNow,
      );
      expect(levels.keys, ['inv-1']);
      expect(
        levels['inv-1'],
        dueReminderLevel(
          issuedAt: _invoice().issuedAt,
          reminderCount: 0,
          lastReminderAt: null,
          rules: rules,
          now: kTestNow,
        ),
      );
    });
  });

  test('pending write-offs: only pending invoice write-off events count', () {
    WorkspaceEvent event(String id, EventType type, EventStatus status) =>
        WorkspaceEvent(
          id: id,
          workspaceId: 'ws-1',
          type: type,
          action: EventAction.created,
          actorMemberId: 'member-1',
          subjectMemberId: 'member-1',
          payload: {'invoice_id': 'inv-$id'},
          status: status,
          createdAt: kTestNow,
        );
    expect(
      OpenInvoiceRows.pendingWriteoffs([
        event('a', EventType.invoiceWriteoff, EventStatus.pending),
        event('b', EventType.invoiceWriteoff, EventStatus.confirmed),
        event('c', EventType.payment, EventStatus.pending),
      ]),
      {'inv-a'},
    );
  });

  group('the journey card', () {
    final cases =
        <
          ({
            String name,
            OpenInvoiceFacts entry,
            OpenInvoiceAct? primary,
            bool writeoffPending,
            List<OpenInvoiceAct> acts,
            List<OpenInvoiceAct> tonal,
          })
        >[
          (
            name: 'open, no move named: match is the tonal one',
            entry: _entry(),
            primary: null,
            writeoffPending: false,
            acts: const [
              OpenInvoiceAct.voidInvoice,
              OpenInvoiceAct.proforma,
              OpenInvoiceAct.remind,
              OpenInvoiceAct.match,
            ],
            tonal: const [OpenInvoiceAct.match],
          ),
          (
            name: 'a reminder is the move: it leaves the icons',
            entry: _entry(),
            primary: OpenInvoiceAct.remind,
            writeoffPending: false,
            acts: const [
              OpenInvoiceAct.voidInvoice,
              OpenInvoiceAct.proforma,
              OpenInvoiceAct.match,
            ],
            tonal: const [],
          ),
          (
            name: 'matching is the move: it leaves the icons',
            entry: _entry(),
            primary: OpenInvoiceAct.match,
            writeoffPending: false,
            acts: const [
              OpenInvoiceAct.voidInvoice,
              OpenInvoiceAct.proforma,
              OpenInvoiceAct.remind,
            ],
            tonal: const [],
          ),
          (
            name: 'credit note, refunding is the move',
            entry: _entry(totalCents: -4000),
            primary: OpenInvoiceAct.refund,
            writeoffPending: false,
            acts: const [OpenInvoiceAct.voidInvoice],
            tonal: const [],
          ),
          (
            name: 'credit note, another move: refund stays, tonal',
            entry: _entry(totalCents: -4000),
            primary: null,
            writeoffPending: false,
            acts: const [OpenInvoiceAct.voidInvoice, OpenInvoiceAct.refund],
            tonal: const [OpenInvoiceAct.refund],
          ),
          (
            name: 'standing partial: remind, match, write off',
            entry: _entry(match: _match()),
            primary: null,
            writeoffPending: false,
            acts: const [
              OpenInvoiceAct.remind,
              OpenInvoiceAct.match,
              OpenInvoiceAct.writeoff,
            ],
            tonal: const [OpenInvoiceAct.match],
          ),
          (
            name: 'standing partial with a filed write-off: the chip',
            entry: _entry(match: _match()),
            primary: null,
            writeoffPending: true,
            acts: const [
              OpenInvoiceAct.remind,
              OpenInvoiceAct.match,
              OpenInvoiceAct.writeoffPending,
            ],
            tonal: const [OpenInvoiceAct.match],
          ),
          (
            name: 'a pending match: the chip only',
            entry: _entry(match: _match(status: 'pending')),
            primary: OpenInvoiceAct.confirmInEvents,
            writeoffPending: false,
            acts: const [OpenInvoiceAct.matchPending],
            tonal: const [],
          ),
        ];
    for (final c in cases) {
      test(c.name, () {
        final acts = OpenInvoiceRows.journeyActs(
          c.entry,
          primary: c.primary,
          writeoffPending: c.writeoffPending,
        );
        expect(_acts(acts), c.acts);
        expect(_tonal(acts), c.tonal);
      });
    }
  });
}
