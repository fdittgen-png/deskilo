// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1913 — the app reads the due date the server froze at issue and the
// amount that is still owed, so the journey, the printed document and the
// reminder never disagree with `invoice_dunning_state`.
import 'package:deskilo/features/money/domain/dunning.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/presentation/invoice_journey.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _row(Map<String, dynamic> extra) => {
  'id': 'i1',
  'workspace_id': 'ws-1',
  'member_id': 'm1',
  'number': 'INV-2026-0001',
  'issued_at': '2026-09-01T08:00:00Z',
  'title': '2026-09',
  'lines': const <dynamic>[],
  'total_cents': 12000,
  'currency': 'EUR',
  'member_name': 'Flo',
  'workspace_name': 'Space',
  'issuer_name': 'Owner',
  'signature': 'abc',
  ...extra,
};

void main() {
  group('the frozen maturity travels with the invoice', () {
    test('an embedded object gives the due date and its basis', () {
      final invoice = Invoice.fromRow(
        _row({
          'invoice_maturities': {
            'due_on': '2026-10-01',
            'basis': 'document_term',
          },
        }),
      );
      expect(invoice.dueOn, DateTime(2026, 10, 1));
      expect(invoice.maturityBasis, 'document_term');
    });

    test('a list-shaped embed reads the same', () {
      final invoice = Invoice.fromRow(
        _row({
          'invoice_maturities': [
            {'due_on': '2026-03-02', 'basis': 'default_term'},
          ],
        }),
      );
      expect(invoice.dueOn, DateTime(2026, 3, 2));
      expect(invoice.maturityBasis, 'default_term');
    });

    test('an invoice from before the migration has no invented date', () {
      final unknown = Invoice.fromRow(
        _row({
          'invoice_maturities': {'due_on': null, 'basis': 'unknown'},
        }),
      );
      expect(unknown.dueOn, isNull);
      expect(unknown.maturityBasis, 'unknown');
      expect(Invoice.fromRow(_row(const {})).dueOn, isNull);
    });
  });

  group('dueReminderLevel follows the frozen due date', () {
    const rules = DunningRules(firstAfterDays: 3);
    int? level(DateTime now, {DateTime? dueOn}) => dueReminderLevel(
      issuedAt: DateTime(2026, 9, 1, 10),
      reminderCount: 0,
      lastReminderAt: null,
      rules: rules,
      now: now,
      dueOn: dueOn,
    );

    test('issued 1 September, due 1 October: 20 September is not overdue', () {
      expect(
        level(DateTime(2026, 9, 20, 12), dueOn: DateTime(2026, 10, 1)),
        isNull,
      );
      expect(
        level(DateTime(2026, 10, 1, 0, 30), dueOn: DateTime(2026, 10, 1)),
        1,
      );
    });

    test('the current rules no longer move an issued invoice', () {
      // Three days after issue the CURRENT rule says "due"; the frozen
      // date says not yet.
      expect(level(DateTime(2026, 9, 5)), 1);
      expect(level(DateTime(2026, 9, 5), dueOn: DateTime(2026, 10, 1)), isNull);
    });
  });

  group('what is still owed', () {
    final invoice = Invoice.fromRow(_row(const {}));
    InvoiceMatch match(String status, int paid, String resolution) =>
        InvoiceMatch(
          invoiceId: 'i1',
          paidCents: paid,
          resolution: resolution,
          status: status,
          matchedAt: DateTime(2026, 9, 10),
        );

    test('120 with 60 confirmed is 60, not 120 and not 0', () {
      expect(
        invoiceRemainingCents(
          invoice,
          match('confirmed', 6000, 'under_accepted'),
        ),
        6000,
      );
    });

    test('a pending payment does not make the balance disappear', () {
      expect(
        invoiceRemainingCents(invoice, match('pending', 12000, 'exact')),
        12000,
      );
    });

    test('paid is nothing owed', () {
      expect(
        invoiceRemainingCents(invoice, match('confirmed', 12000, 'exact')),
        0,
      );
      expect(invoiceRemainingCents(invoice, null), 12000);
    });
  });
}
