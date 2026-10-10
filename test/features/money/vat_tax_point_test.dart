// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2355 — WHEN the VAT on a supply falls due, per country, and for how
// much. The engine dates every part of an invoice on the workspace's
// calendar: France taxes services when paid, Germany and Spain in the
// month the service is performed (an earlier payment when received), the
// United Kingdom, Italy and Canada at the invoice or the payment,
// whichever comes first, Switzerland at the invoice. An invoice paid in
// instalments splits across periods and the parts add up to the
// document; a credit note is due on its own date and never re-opens the
// period of the invoice it corrects.
import 'package:deskilo/core/time/workspace_time.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/invoice_legal.dart';
import 'package:deskilo/features/money/domain/vat_tax_point.dart';
import 'package:flutter_test/flutter_test.dart';

Invoice _invoice(
  String id, {
  required DateTime issuedAt,
  String? period,
  List<InvoiceLine> lines = const [
    InvoiceLine(label: 'Desk', amountCents: 12000, vatPercent: 20),
  ],
}) => Invoice(
  id: id,
  workspaceId: 'ws-1',
  memberId: 'm-1',
  number: 'INV-$id',
  issuedAt: issuedAt,
  period: period,
  title: 'Invoice $id',
  lines: lines,
  totalCents: lines.fold(0, (sum, l) => sum + l.amountCents),
  currency: 'EUR',
  memberName: 'Ada',
  memberAddress: '',
  workspaceName: 'Space',
  workspaceAddress: '',
  issuerName: '',
  signature: '',
);

/// Noon on the workspace's calendar, as the UTC instant the server stores.
DateTime _on(int year, int month, int day) =>
    WorkspaceTime.at(year, month, day, 12).toUtc();

TaxPointPayment _paid(DateTime on, int cents) => TaxPointPayment(on, cents);

/// The amounts that fall in [year]-[month].
List<VatTaxPointAmount> _inMonth(
  List<VatTaxPointAmount> amounts,
  int year,
  int month,
) => [
  for (final a in amounts)
    if (a.within(DateTime(year, month), DateTime(year, month + 1, 0))) a,
];

int _gross(Iterable<VatTaxPointAmount> a) =>
    a.fold(0, (sum, x) => sum + x.grossCents);
int _vat(Iterable<VatTaxPointAmount> a) =>
    a.fold(0, (sum, x) => sum + x.vatCents);

void main() {
  setUp(() => WorkspaceTime.install('Europe/Paris'));
  tearDown(WorkspaceTime.reset);

  group('the country decides the default', () {
    test('per-country legal rules and the options each allows', () {
      final fr = vatTaxPointPolicy('fr');
      expect(fr.standard, VatTaxPointRule.receipt);
      expect(fr.options, [
        VatTaxPointOption.standard,
        VatTaxPointOption.invoice,
      ]);
      expect(vatTaxPointPolicy('DE').standard, VatTaxPointRule.servicePeriod);
      expect(vatTaxPointPolicy('ES').standard, VatTaxPointRule.servicePeriod);
      expect(vatTaxPointPolicy('IT').standard, VatTaxPointRule.earlierOf);
      expect(vatTaxPointPolicy('GB').standard, VatTaxPointRule.earlierOf);
      expect(vatTaxPointPolicy('CH').standard, VatTaxPointRule.invoiceDate);
      final ca = vatTaxPointPolicy('CA');
      expect(ca.standard, VatTaxPointRule.earlierOf);
      expect(ca.options, [
        VatTaxPointOption.standard,
      ], reason: 'Canada has no cash option');
      expect(vatTaxPointPolicy('NO').standard, VatTaxPointRule.invoiceDate);
    });

    test('a workspace that never chose is on its country\'s default — '
        'receipts in France, the service month in Germany, earlier-of in '
        'the United Kingdom', () {
      const never = InvoiceLegal();
      expect(never.vatTaxPoint, isNull);
      expect(never.taxPointBasis('FR').rule, VatTaxPointRule.receipt);
      expect(never.taxPointBasis('DE').rule, VatTaxPointRule.servicePeriod);
      expect(never.taxPointBasis('GB').rule, VatTaxPointRule.earlierOf);
      expect(
        InvoiceLegal.fromJson(const {}).vatTaxPoint,
        isNull,
        reason: 'an absent key is what "never chose" means',
      );
    });

    test('the two-value #896 key still reads: invoice → the invoice date '
        'where the law allows it, payment → cash where it exists', () {
      final invoice = InvoiceLegal.fromJson(const {
        'vat_exigibility': 'invoice',
      });
      final payment = InvoiceLegal.fromJson(const {
        'vat_exigibility': 'payment',
      });
      expect(
        invoice.taxPointBasis('FR').rule,
        VatTaxPointRule.invoiceDate,
        reason: 'France: the option for the debits',
      );
      expect(
        invoice.taxPointBasis('DE').rule,
        VatTaxPointRule.servicePeriod,
        reason: 'Germany: Soll is the service month',
      );
      expect(payment.taxPointBasis('DE').rule, VatTaxPointRule.receipt);
      expect(payment.taxPointBasis('FR').rule, VatTaxPointRule.receipt);
      expect(
        payment.taxPointBasis('CA').rule,
        VatTaxPointRule.earlierOf,
        reason: 'Canada allows no cash scheme',
      );
      expect(
        payment.taxPointBasis('ES').backstop,
        VatCashBackstop.endOfFollowingYear,
      );
    });

    test('the choice round-trips, with the legacy key the snapshot reads '
        'written only beside a non-default choice', () {
      const cash = InvoiceLegal(vatTaxPoint: VatTaxPointOption.cash);
      expect(cash.toJson()['vat_tax_point'], 'cash');
      expect(cash.toJson()['vat_exigibility'], 'payment');
      expect(InvoiceLegal.fromJson(cash.toJson()), cash);
      const standard = InvoiceLegal(vatTaxPoint: VatTaxPointOption.standard);
      expect(standard.toJson()['vat_tax_point'], 'standard');
      expect(
        standard.toJson().containsKey('vat_exigibility'),
        isFalse,
        reason: 'the server derives the default from the country (0401)',
      );
      expect(
        const InvoiceLegal().toJson().containsKey('vat_tax_point'),
        isFalse,
      );
      expect(standard.exigibilityIn('FR'), 'payment');
      expect(standard.exigibilityIn('DE'), 'invoice');
    });
  });

  group('Germany — the service month, an earlier payment when received', () {
    final september = _invoice(
      'de',
      issuedAt: _on(2026, 8, 25),
      period: '2026-09',
      lines: const [
        InvoiceLine(label: 'Desk', amountCents: 12000, vatPercent: 19),
      ],
    );
    const basis = VatTaxPointBasis(VatTaxPointRule.servicePeriod);

    test('invoiced 25 August for September and paid 2 September: '
        'September, not August', () {
      final amounts = taxPointsOf(september, [
        _paid(_on(2026, 9, 2), 12000),
      ], basis: basis);
      expect(_inMonth(amounts, 2026, 8), isEmpty);
      expect(_gross(_inMonth(amounts, 2026, 9)), 12000);
      expect(_vat(_inMonth(amounts, 2026, 9)), 1916);
    });

    test('paid 20 August, before the service: August (Mindest-Ist)', () {
      final amounts = taxPointsOf(september, [
        _paid(_on(2026, 8, 20), 12000),
      ], basis: basis);
      expect(_gross(_inMonth(amounts, 2026, 8)), 12000);
      expect(_inMonth(amounts, 2026, 9), isEmpty);
    });

    test('unpaid, the tax arises at the end of the service month', () {
      final amounts = taxPointsOf(september, const [], basis: basis);
      expect(amounts.single.on, DateTime(2026, 9, 30));
    });

    test('a usage invoice issued after its month is due in that month', () {
      final usage = _invoice(
        'u',
        issuedAt: _on(2026, 10, 3),
        period: '2026-09',
      );
      expect(
        taxPointsOf(usage, const [], basis: basis).single.on,
        DateTime(2026, 9, 30),
      );
    });

    test('the Ist option dates each payment', () {
      final amounts = taxPointOf(
        september,
        [_paid(_on(2026, 10, 9), 12000)],
        country: 'DE',
        option: VatTaxPointOption.cash,
      );
      expect(amounts.single.on, DateTime(2026, 10, 9));
    });
  });

  group('France — receipts, instalments split across periods', () {
    final august = _invoice(
      'fr',
      issuedAt: _on(2026, 8, 10),
      period: '2026-08',
    );

    test('issued in August, paid half in September and half in October: '
        'half in each month', () {
      final amounts = taxPointOf(august, [
        _paid(_on(2026, 9, 5), 6000),
        _paid(_on(2026, 10, 7), 6000),
      ], country: 'FR');
      expect(_inMonth(amounts, 2026, 8), isEmpty);
      expect(_gross(_inMonth(amounts, 2026, 9)), 6000);
      expect(_gross(_inMonth(amounts, 2026, 10)), 6000);
      expect(
        _vat(_inMonth(amounts, 2026, 9)) + _vat(_inMonth(amounts, 2026, 10)),
        2000,
      );
      final lines = vatDeclarationLinesOf(
        amounts,
        DateTime(2026, 9),
        DateTime(2026, 9, 30),
      );
      expect(lines.single.vatCents, 1000);
      expect(lines.single.invoiceCount, 1);
    });

    test('an unpaid invoice is not due yet', () {
      expect(taxPointOf(august, const [], country: 'FR'), isEmpty);
    });

    test('the option for the debits dates it on the invoice', () {
      final amounts = taxPointOf(
        august,
        [_paid(_on(2026, 9, 5), 12000)],
        country: 'FR',
        option: VatTaxPointOption.invoice,
      );
      expect(amounts.single.on, DateTime(2026, 8, 10));
    });

    test('the payment day is read on the workspace clock: 22:30 UTC on '
        '31 August is 1 September in Paris', () {
      final amounts = taxPointOf(august, [
        _paid(DateTime.utc(2026, 8, 31, 22, 30), 12000),
      ], country: 'FR');
      expect(amounts.single.on, DateTime(2026, 9, 1));
    });

    test('three instalments of a two-rate invoice add up to its per-line '
        'arithmetic to the cent', () {
      final mixed = _invoice(
        'mx',
        issuedAt: _on(2026, 8, 10),
        lines: const [
          InvoiceLine(label: 'Room', amountCents: 6001, vatPercent: 20),
          InvoiceLine(label: 'Coffee', amountCents: 3999, vatPercent: 10),
        ],
      );
      final amounts = taxPointOf(mixed, [
        _paid(_on(2026, 8, 11), 3333),
        _paid(_on(2026, 9, 11), 3333),
        _paid(_on(2026, 10, 11), 3334),
      ], country: 'FR');
      final whole = vatDeclarationLinesOf(
        vatTaxPointLedger([mixed]),
        DateTime(2026, 8),
        DateTime(2026, 8, 31),
      );
      for (final line in whole) {
        final parts = amounts.where((a) => a.percent == line.percent);
        expect(_gross(parts), line.grossCents);
        expect(_vat(parts), line.vatCents);
      }
      for (final month in [8, 9, 10]) {
        final part = _inMonth(amounts, 2026, month);
        expect(
          _gross(part),
          month == 10 ? 3334 : 3333,
          reason: 'each payment is apportioned whole across the rates',
        );
      }
    });
  });

  group('the United Kingdom — the invoice or the payment, whichever first', () {
    final invoice = _invoice('uk', issuedAt: _on(2026, 9, 15));

    test('a deposit before the invoice is due when paid, the rest on the '
        'invoice', () {
      final amounts = taxPointOf(invoice, [
        _paid(_on(2026, 8, 28), 3000),
        _paid(_on(2026, 10, 2), 9000),
      ], country: 'GB');
      expect(_gross(_inMonth(amounts, 2026, 8)), 3000);
      expect(_gross(_inMonth(amounts, 2026, 9)), 9000);
      expect(
        _inMonth(amounts, 2026, 10),
        isEmpty,
        reason: 'a payment after the invoice changes nothing',
      );
    });

    test('cash accounting waits for the money', () {
      final amounts = taxPointOf(
        invoice,
        [_paid(_on(2026, 10, 2), 12000)],
        country: 'GB',
        option: VatTaxPointOption.cash,
      );
      expect(amounts.single.on, DateTime(2026, 10, 2));
    });
  });

  test('Switzerland and Canada date it on the invoice', () {
    final invoice = _invoice('ch', issuedAt: _on(2026, 9, 15));
    expect(
      taxPointOf(invoice, [
        _paid(_on(2026, 11, 1), 12000),
      ], country: 'CH').single.on,
      DateTime(2026, 9, 15),
    );
    expect(
      taxPointOf(invoice, [
        _paid(_on(2026, 11, 1), 12000),
      ], country: 'CA').single.on,
      DateTime(2026, 9, 15),
    );
  });

  group('cash schemes with a backstop', () {
    final invoice = _invoice(
      'bs',
      issuedAt: _on(2026, 3, 10),
      period: '2026-03',
    );

    test('Spain\'s criterio de caja: an unpaid part is due on 31 December '
        'of the following year', () {
      final amounts = taxPointOf(
        invoice,
        [_paid(_on(2026, 4, 1), 2000)],
        country: 'ES',
        option: VatTaxPointOption.cash,
      );
      expect(amounts.map((a) => a.on), [
        DateTime(2026, 4, 1),
        DateTime(2027, 12, 31),
      ]);
      expect(_gross(amounts), 12000);
    });

    test('Italy\'s IVA per cassa: one year after the operation', () {
      final amounts = taxPointOf(
        invoice,
        const [],
        country: 'IT',
        option: VatTaxPointOption.cash,
      );
      expect(amounts.single.on, DateTime(2027, 3, 10));
    });
  });

  group('a credit note follows its own tax point', () {
    final original = _invoice(
      'o',
      issuedAt: _on(2026, 8, 3),
      period: '2026-08',
    );
    final credit = _invoice(
      'c',
      issuedAt: _on(2026, 10, 6),
      period: '2026-08',
      lines: const [
        InvoiceLine(label: 'Refund', amountCents: -12000, vatPercent: 20),
      ],
    );

    test('on an accrual rule it is due when issued, never in the original\'s '
        'period', () {
      final amounts = vatTaxPointLedger([
        original,
        credit,
      ], basis: const VatTaxPointBasis(VatTaxPointRule.servicePeriod));
      expect(
        _vat(_inMonth(amounts, 2026, 8)),
        2000,
        reason: 'August keeps what it declared',
      );
      expect(_vat(_inMonth(amounts, 2026, 10)), -2000);
    });

    test('on receipts it is due when refunded', () {
      final amounts = taxPointsOf(credit, [
        _paid(_on(2026, 11, 12), 12000),
      ], basis: VatTaxPointBasis.receipt);
      expect(amounts.single.on, DateTime(2026, 11, 12));
      expect(amounts.single.grossCents, -12000);
      expect(amounts.single.vatCents, -2000);
    });
  });

  group('the payments behind an invoice', () {
    InvoiceMatch match(int cents, {String status = 'confirmed'}) =>
        InvoiceMatch(
          invoiceId: 'x',
          paidCents: cents,
          resolution: 'exact',
          status: status,
          matchedAt: _on(2026, 9, 1),
        );

    test('a match awaiting validation pays nothing yet', () {
      expect(paymentsOf(match(12000, status: 'pending'), const []), isEmpty);
    });

    test('without instalments the aggregate is one payment', () {
      final payments = paymentsOf(match(12000), const []);
      expect(payments.single.cents, 12000);
    });

    test('instalments never count beyond the confirmed aggregate', () {
      final payments = paymentsOf(match(9000), [
        _paid(_on(2026, 10, 1), 6000),
        _paid(_on(2026, 9, 1), 6000),
      ]);
      expect(payments.map((p) => p.cents), [6000, 3000]);
      expect(payments.first.on, _on(2026, 9, 1));
    });
  });

  test('voided documents and settlements declare nothing', () {
    final invoice = _invoice('v', issuedAt: _on(2026, 9, 1));
    expect(
      taxPointsOf(
        invoice.copyWith(voidedAt: _on(2026, 9, 2)),
        const [],
        basis: VatTaxPointBasis.invoiceDate,
      ),
      isEmpty,
    );
  });
}
