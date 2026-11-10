// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3285 -- one rule for "due" and "overdue": the due date frozen on the invoice
// wins, an invoice from before it was frozen keeps issue date + term, the due
// day itself is overdue (the server's rule), days are calendar days, and the
// register, the journey and Me's list say the same thing about the same
// document. A changed current term never rewrites an issued obligation.
import 'package:deskilo/features/money/domain/dunning.dart';
import 'package:deskilo/features/money/domain/finance_overview.dart';
import 'package:deskilo/features/money/domain/invoice_due.dart';
import 'package:deskilo/features/money/presentation/invoice_journey.dart';
import 'package:deskilo/features/money/presentation/widgets/invoice_overview.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Invoice _invoice({DateTime? issuedAt, DateTime? dueOn}) => Invoice(
  id: 'inv-1',
  workspaceId: 'ws-1',
  memberId: 'member-1',
  number: 'U-2026-04-02',
  issuedAt: issuedAt ?? DateTime(2026, 4, 2),
  dueOn: dueOn,
  period: '2026-04',
  title: '2026-04',
  lines: const [],
  totalCents: 25000,
  currency: 'EUR',
  memberName: 'Ada',
  memberAddress: '',
  workspaceName: 'Space',
  workspaceAddress: '',
  issuerName: 'Owner',
  signature: 'sig',
);

InvoiceJourney _journey(Invoice i, DateTime now, DunningRules rules) =>
    InvoiceJourney.of(
      invoice: i,
      rules: rules,
      now: now,
      match: null,
      reminder: null,
      facts: journeyFactsOf(i, null, const []),
    );

InvoiceExposure _exposure(Invoice i, DateTime now, DunningRules rules) =>
    InvoiceExposure.of(
      invoices: [i],
      matches: const {},
      rules: rules,
      now: now,
      fallbackCurrency: 'EUR',
    );

void main() {
  group('the rule', () {
    test('the frozen due date wins over the current term', () {
      // Issued 2 April with the 14-day term it was issued under; the
      // workspace's CURRENT term is 30 days: nothing moves.
      final i = _invoice(dueOn: DateTime(2026, 4, 16));
      final now = DateTime(2026, 5, 13);
      for (final term in [14, 30, 60]) {
        final due = invoiceDue(
          dueOn: i.dueOn,
          issuedAt: i.issuedAt,
          termDays: term,
          now: now,
        );
        expect(due.dueOn, DateTime(2026, 4, 16), reason: 'term $term');
        expect(due.daysToTerm, -27, reason: 'term $term');
        expect(due.overdue, isTrue);
      }
    });

    test('an invoice with no frozen date keeps issue date + term', () {
      final due = invoiceDue(
        dueOn: null,
        issuedAt: DateTime(2026, 4, 2),
        termDays: 14,
        now: DateTime(2026, 4, 10),
      );
      expect(due.dueOn, DateTime(2026, 4, 16));
      expect(due.daysToTerm, 6);
      expect(due.overdue, isFalse);
    });

    test('the due day is overdue; the day before is not', () {
      final due = DateTime(2026, 5, 8);
      expect(isOverdueOn(due, DateTime(2026, 5, 7, 23, 59)), isFalse);
      expect(isOverdueOn(due, DateTime(2026, 5, 8)), isTrue);
      expect(isOverdueOn(due, DateTime(2026, 5, 8, 23, 59)), isTrue);
      expect(isOverdueOn(due, DateTime(2026, 5, 9)), isTrue);
    });

    test('a clock change moves no day (2026-03-29 and 2026-10-25)', () {
      for (final (from, due) in [
        (DateTime(2026, 3, 28, 12), DateTime(2026, 3, 30)),
        (DateTime(2026, 10, 24, 12), DateTime(2026, 10, 26)),
      ]) {
        final r = invoiceDue(
          dueOn: due,
          issuedAt: DateTime(2026),
          termDays: 14,
          now: from,
        );
        expect(r.daysToTerm, 2, reason: '$from');
        expect(r.overdue, isFalse);
      }
    });
  });

  group('the register, the journey and Me agree on one document', () {
    final now = DateTime(2026, 5, 13, 10);
    const rules = DunningRules();

    test('the observed defect: due May 8, today May 13', () {
      // Frozen 14-day term from 24 April; the exposure used to count from the
      // issue date with the CURRENT term and say 1 day, the journey said 5.
      final i = _invoice(
        issuedAt: DateTime(2026, 4, 24),
        dueOn: DateTime(2026, 5, 8),
      );
      final journey = _journey(i, now, rules);
      final exposure = _exposure(i, now, rules);
      expect(journey.daysToTerm, -5);
      expect(exposure.daysToTerm(i, now), -5);
      expect(journey.overdue, isTrue);
      expect(exposure.overdue, [i]);
      final finance = FinanceInvoice(
        id: i.id,
        workspaceId: i.workspaceId,
        workspaceName: 'Space',
        number: i.number,
        issuedAt: i.issuedAt,
        dueOn: i.dueOn,
        totalCents: i.totalCents,
        paidCents: 0,
        currency: 'EUR',
        state: FinanceState.open,
      );
      expect(finance.overdueAt(now), isTrue, reason: 'Me says the same');
    });

    test('changing the current term never rewrites an issued obligation', () {
      final i = _invoice(
        issuedAt: DateTime(2026, 4, 24),
        dueOn: DateTime(2026, 5, 8),
      );
      for (final term in [7, 14, 30, 90]) {
        final r = DunningRules(firstAfterDays: term);
        expect(_journey(i, now, r).dueOn, DateTime(2026, 5, 8));
        expect(_exposure(i, now, r).daysToTerm(i, now), -5);
      }
    });

    test('the due day is overdue in all three places', () {
      final i = _invoice(dueOn: DateTime(2026, 5, 13));
      expect(_journey(i, now, rules).overdue, isTrue);
      expect(_exposure(i, now, rules).overdue, [i]);
      final finance = FinanceInvoice(
        id: i.id,
        workspaceId: i.workspaceId,
        workspaceName: 'Space',
        number: i.number,
        issuedAt: i.issuedAt,
        dueOn: i.dueOn,
        totalCents: i.totalCents,
        paidCents: 0,
        currency: 'EUR',
        state: FinanceState.open,
      );
      expect(finance.overdueAt(now), isTrue);
    });

    test('a legacy invoice with no frozen date agrees too', () {
      final i = _invoice(issuedAt: DateTime(2026, 4, 20));
      final journey = _journey(i, now, rules);
      final exposure = _exposure(i, now, rules);
      expect(journey.daysToTerm, exposure.daysToTerm(i, now));
      expect(journey.overdue, exposure.overdue.isNotEmpty);
    });
  });

  group('the words', () {
    test('overdue and due-in read right at 0, 1 and 5 days, in every language', () {
      for (final locale in AppLocalizations.supportedLocales) {
        final words = lookupAppLocalizations(locale);
        final lang = locale.languageCode;
        expect(words.moneyOverdueBy(1), isNot(words.moneyOverdueBy(5)), reason: lang);
        expect(words.moneyOverdueBy(0), isNot(words.moneyOverdueBy(1)), reason: lang);
        expect(words.moneyDueIn(1), isNot(words.moneyDueIn(5)), reason: lang);
        expect(words.moneyOverdueBy(5), contains('5'), reason: lang);
        expect(words.moneyOverdueBy(1), isNot(contains('1 days')), reason: lang);
      }
      final en = lookupAppLocalizations(const Locale('en'));
      expect(en.moneyOverdueBy(1), 'Overdue by 1 day');
      expect(en.moneyOverdueBy(5), 'Overdue by 5 days');
      expect(en.moneyDueIn(1), 'Due in 1 day');
    });
  });
}
